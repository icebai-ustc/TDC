from QuartusMemory import QuartusMemory
import matplotlib.pyplot as plt

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
# CODE FOR CREATING DICTIONARY OF RING OSCILLATORS WITH THEIR COORDINATES

#Array parameters, should match the ones used in the location assignment script
ybegin = 1
ystep = 3
nysteps = 26

xbegin = 1
xstep = 3
nxsteps = 28


xend= xbegin + nxsteps*xstep
yend= ybegin + nysteps*ystep

t = 0
r = 0
c = 0
#Dictionary that will hold the index of each RO with it's correpsonding location on the FPGA
loc_dict = {}
for j in range(xbegin, xend+1, xstep):
	for i in range(ybegin, yend+1, ystep):
		if x[(j,i)]["TYPE"] == "LAB":
			loc_dict[t] = [j, i]
			t += 1
		r+=1	
	r=0
	c+=1

# ----------------------------------------------------

# CODE FOR READING DATA 

q = QuartusMemory()

#Declare number of data points and size of each piece of binary data
NUM = 413              	  #Number of ring oscillators
word_len = 16        	  #Length of the words in the RAM instance
slow_clk_freq = 1    	  #Frequency of slow clock in MHz
nstages = 19			  #Number of stages in each RO

# Find index of instance named RAM1
inst = q.find_instance('RAM1')

# Read memory from device
binary_data = q.read_mem(inst,True)


#Convert all the binary data into a string and then into a decimal integer and put in the 
# freq_cnts list
freq_cnts = []
for j in range(0, NUM):
	bin_str = ''
	for i in range(0, word_len):
		bin_str = bin_str + str(binary_data[j][word_len - 1 - i])
	freq_cnts.append(int(bin_str, 2))

#Convert the frequency counts into actual frequencies
freq_data = freq_cnts * slow_clk_freq

##Calculate the delay per RO stage given by each frequency (in picoseconds)
# delay_per_stage = []
# for j in range(0, NUM):
	# delay_per_stage.append(10**6/(freq_data[j]*2*nstages))

# print(freq_data)
#print(delay_per_stage)

#Plots

#histogram
plt.hist(freq_data, bins = 30, range = (220, 260), density = True)
plt.xlabel('Frequency')
plt.ylabel('Counts')
plt.show()

#3D scatter
x_val = []
y_val = []
z_val = []
dx = []
dy = []
dz = []

for i in range(0, NUM):
	#if (freq_data[i] < 500):
		x_val.append(loc_dict[i][0])
		y_val.append(loc_dict[i][1])
		z_val.append(freq_data[i])


fig = plt.figure()
ax = plt.axes(projection = "3d")
ax.scatter(x_val, y_val, z_val)
ax.set_xlabel('X')
ax.set_ylabel('Y')
ax.set_zlabel('Frequency (MHz)')

plt.show()


# Write data to a csv file
with open('FreqData.csv', 'w') as f:
	for i in range(0, NUM):
		f.write(str((loc_dict[i][0])) + ', ' + str((loc_dict[i][1])) + ", " + str((freq_data[i])) + '\n')


