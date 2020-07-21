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
       
    if v in NONEs:
        x[v].update({"TYPE":"NONE"})
		
    elif v in MLABs:
        x[v].update({"TYPE":"MLAB"})
        x[v].update({k:{} for k in range(Z)})
        for l in range(Z):
            if l%6==0 or l%6==3:
                x[v][l]["TYPE"]="MLABCELL"
            else:
                x[v][l]["TYPE"]="FF"

    elif v in RAMs:
        x[v].update({"TYPE":"RAM"})

    else: #LABs
        x[v].update({"TYPE":"LAB"})
        x[v].update({k:{} for k in range(Z)})
        for l in range(Z):
            if l%6==0 or l%6==3:
                x[v][l]["TYPE"]="LABCELL"
            else:
                x[v][l]["TYPE"]="FF"

rsrc_type =x #restore label
