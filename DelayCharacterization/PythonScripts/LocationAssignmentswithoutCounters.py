#   Made on: 5/27/2020
#   Made by: Peter Menart
#   Creates location assignments for an array of ring oscillators on Quartus. 


# -------------------------------------------
# Noelo's Indexing

#File indexing type of logic at each location on a DE-10 Nano FPGA grid.

import numpy as np

_5CSEBA6U23I7 = {} #indexed by location, having type of logic and associated instance
x = _5CSEBA6U23I7 #shorthand
X,Y,Z=(90,82,60)
x = {} #key by (x,y) w/ type of logic at that location

# The 5CSEBA6U23I7 doesn't have LABS on edges.
NONEs=[(i,j) for i,j in np.ndindex(X,Y) if i==0 or j==0]

# The 5CSEBA6U23I7 has occasional vertical strips for memory and DSP.
RAM_Xs=[5,14,20,26,32,38,41,44,49,54,58,69,76,86,89]
RAMs=[(i,j) for i,j in np.ndindex(X,Y) if i in RAM_Xs]

# The 5CSEBA6U23I7 also has strips of MLABCELLs.
MLAB_Xs=[3,6,8,15,21,25,28,34,39,47,52,59,65,72,78,82,84,87]
MLABs=[(i,j) for i,j in np.ndindex(X,Y) if i in MLAB_Xs]

# The 5CSEBA6U23I7 has two blank sections on the left of the chip.
NONE_Xs=[i for i in range(1,10)]
NONE_Ys=[i for i in range(15,32)]+[i for i in range(56,73)]
NONEs.extend([(i,j) for i,j in np.ndindex(X,Y) if i in NONE_Xs and j in NONE_Ys])

# The 5CSEBA6U23I7 has a HPS on the right side of the chip.
NONE_Xs=[i for i in range(51,89)]
NONE_Ys=[i for i in range(37,81)]
NONEs.extend([(i,j) for i,j in np.ndindex(X,Y) if i in NONE_Xs and j in NONE_Ys])

# The 5CSEBA6U23I7 has a horizontal strip connecting to the HPS.
NONE_Xs=[i for i in range(45,51)]
NONE_Ys=[i for i in range(37,38)]
NONEs.extend([(i,j) for i,j in np.ndindex(X,Y) if i in NONE_Xs and j in NONE_Ys])

for i,j in np.ndindex(X,Y): #thread over given values
    v=(i,j)
    x[v]={}
    if v in MLABs:
        x[v].update({"TYPE":"MLAB"})
        x[v].update({k:{} for k in range(Z)})
        for l in range(Z):
            if l%6==0 or l%6==3:
                x[v][l]["TYPE"]="MLABCELL"
            else:
                x[v][l]["TYPE"]="FF"

    elif v in RAMs:
        x[v].update({"TYPE":"RAM"})

    elif v in NONEs:
        x[v].update({"TYPE":"NONE"})

    else: #LABs
        x[v].update({"TYPE":"LAB"})
        x[v].update({k:{} for k in range(Z)})
        for l in range(Z):
            if l%6==0 or l%6==3:
                x[v][l]["TYPE"]="LABCELL"
            else:
                x[v][l]["TYPE"]="FF"

_5CSEBA6U23I7=x #restore label


#-------------------------------------------------------------------


#Array parameters
ybegin = 1
ystep = 3
nysteps = 26

xbegin = 1
xstep = 3
nxsteps = 28


xend= xbegin + nxsteps*xstep
yend= ybegin + nysteps*ystep

nstages = 19


t = 0
x_shift = 0
y_shift = 0
#Create location assignments for ring oscillator inverters, as well as counter registers
with open('LocationAssignments.txt', 'w') as f:
	for j in range(xbegin, xend+1, xstep):
		for i in range(ybegin, yend+1, ystep):
			if x[(j,i)]["TYPE"] == "LAB":
				for k in range(0,nstages):
					str1 = 'set_location_assignment LABCELL_X' + str(j) + '_Y' + str(i) + '_N' + str(k*3)
					str2 =' -to "RO:ro_' + str(j) + '_' + str(i) + '|inv[' + str(k+1) + ']"'
					f.write(str1 + str2 + '\n')
					

#create code to for instantiating all the ring oscillators

t = 0
r = 0
c = 0
with open('ROInstances.txt', 'w') as f2:
	for j in range(xbegin, xend+1, xstep):
		for i in range(ybegin, yend+1, ystep):
			if x[(j,i)]["TYPE"] == "LAB":
				str3 = 'RO #(.N(' + str(nstages) + ')) ro_' + str(j) + '_' + str(i) + ' (out[' + str(t)+  ']);'
				f2.write(str3 + '\n')
				t += 1
			r+=1	
		r=0
		c+=1	

				


							
				
				