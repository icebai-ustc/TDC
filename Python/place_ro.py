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

def location_str(xpos, ypos, n):
    template_str = 'set_location_assignment LABCELL_X{0}_Y{1}_N{2} -to \"RO:ro_arr[{3}]|{4}\"\n'
    retstr = ''
    # Placing inv's
    for i in range(20):
        retstr = retstr + template_str.format(str(xpos),str(ypos),str(3*i),str(n),str('inv[' + str(i) + ']'))
    return retstr


# Parse verilog file for number of ring oscillators to place
vlogfile = open('RORead.v','r')

for i in vlogfile:
    if (i.find('parameter N') != -1):
        paramstring = i

for i in range(len(paramstring)):
    if paramstring[i] == ';':
        endpos = i
        break

vlogfile.close()

num_ro = int(paramstring[14:i])

# Estimate spacing TODO

space = 2
startx = 1
starty = 1

location_assign = []

# Coords go from x:1-89,y:1,80

xc = startx
yc = starty

num_ro = 512
while (len(location_assign) < num_ro):
    while yc < starty + 80:
        xc = startx
        while xc < startx + 89:
            if (_5CSEBA6U23I7[(xc,yc)]['TYPE'] == 'LAB' and len(location_assign) < num_ro):
                location_assign.append(location_str(xc,yc,len(location_assign)))
                xc = xc + space
            xc = xc + 1

        yc = yc + space


# TODO: Read qsf, remove old location assignments, input new ones

qsf = open('RORead.qsf','r')
qsf_lines = qsf.readlines()

qsf.close()

new_qsf_lines = []

for i in qsf_lines:
    if (i.find('LABCELL') == -1):
        new_qsf_lines.append(i)

new_qsf_lines.append('\n')
for i in location_assign:
    new_qsf_lines.append(i)

new_qsf = open('RORead.qsf','w')
#new_qsf = open('qsftest.txt','w')

for i in new_qsf_lines:
    new_qsf.write(i)

new_qsf.close()
