from QuartusMemory import QuartusMemory
import numpy as np
import matplotlib.pyplot as plt
import statistics as st
from scipy.optimize import minimize
import math
import time
import quartustcl

# -------------------------------------------
# Noelo's Indexing
# --------------------------------------------
#File indexing type of logic at each location on a DE-10 Nano FPGA grid.



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



#-------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------

def create_lcell_loc_assign(node_name, x, y, n):
	loc_assign = 'set_location_assignment LABCELL_X' + str(x) + '_Y' + str(y) + '_N' + str(n) + ' -to ' + node_name + '\n'
	return(loc_assign)
def create_mlcell_loc_assign(node_name, x, y, n):
	loc_assign = 'set_location_assignment MLABCELL_X' + str(x) + '_Y' + str(y) + '_N' + str(n) + ' -to ' + node_name + '\n'
	return(loc_assign)
def create_reg_loc_assign(node_name, x, y, n):
	loc_assign = 'set_location_assignment FF_X' + str(x) + '_Y' + str(y) + '_N' + str(n) + ' -to ' + node_name + '\n'
	return(loc_assign)

#-------------------------------------------------------------------
# MAIN CODE 
# ------------------------------------------------------------------

# ------ INPUTS ------------ 

#Number of RO's to be placed at one time. MAKE SURE to change this in the verilog file as well
NUM_RO = 30

#Number of times to recompile and measuremen
NUM_RUNS = 20

#Number of inverters per RO (should be ODD and <=19)
nstages = 19

# Spacing Parameters
yspace = 1
xspace = 1

#Length of the words in the RAM instance
word_len = 16  

#Frequency of slow clock in MHz      	  
slow_clk_freq = 1    	  

#Set file names
project_name = 'ROarray_v3'
cdf_file_name = 'ROarray_v3.cdf'
qsf_file_name = 'ROarray_v3.qsf'



# ----  PARAMETERS ---------

# Width and height of the board
max_x = 88
max_y = 80

#number of sweeps needed to cover board
n_sweep = (1+yspace) * (1+xspace)

# Specifies the number of the adder that is the first one used for the counters
first_adder = 3

#Number of logic elements that can contain an RO (LABS or MLABS)
max_RO = 4191

# ---- Instantiate Quartus Tcl instance and Quartus Memory object
q_tcl = quartustcl.QuartusTcl()
q_mem = QuartusMemory()

# ---------- Variables to keep track of RO placement

#Variable that keeps track on which sweep of the board currently on
sweep = 0

#Variables to keep track of location of ROs
xstep = xspace + 1
ystep = yspace + 1

startx = 1
starty = 1
x = startx
y = starty

#List that will hold counts from board
freq_cnts = []

#Dictionary that will hold the index of each RO with it's correpsonding location on the FPGA
loc_dict = {}

# ------ MAIN LOOP ---------------
stop = 0
run = 0
while run < NUM_RUNS:
	print('RUN ' + str(run))

	# ---------- LOCATION ASSIGNMENTS ---------------- 

	# Create location assignments list
	location_assign = []

	# t tracks the number of RO's placed for current compilation
	t = 0
	while t < NUM_RO:

		type = rsrc_type[(x,y)]["TYPE"]
		if (type == "LAB" or type == "MLAB"):
			#Create location assignments
			
			#Assignments for the ring oscillator
			for k in range(0,nstages):
				node = '"RO:generate_RO[' + str(t) + '].ro_inst|inv[' + str(k+1) + ']"'
				if type == "LAB":
					location_assign.append(create_lcell_loc_assign(node, x, y, k*3))
				if type == "MLAB":
					location_assign.append(create_mlcell_loc_assign(node, x, y, k*3))
				loc_dict[t + NUM_RO * run] = [x, y]
			
			#assignments for the counter registers
			for k in range(0,16):
				node = 'counter[' + str(t) + '][' + str(k) + ']'
				location_assign.append(create_reg_loc_assign(node,x, y+1, k*3+1))
			
			#assignments for the counter adders
			for k in range(0,15):
				node = 'Add' + str(first_adder+t) + '~' + str(k*4 + 1)
				if type == "LAB":
					location_assign.append(create_lcell_loc_assign(node, x, y+1, k*3))
				if type == "MLAB":
					location_assign.append(create_mlcell_loc_assign(node, x, y+1, k*3))
			t += 1
			
		#Increment coordinates
		if (x + xstep <= max_x):
			x = x + xstep
		elif (y + ystep <= max_y):
			y = y + ystep
			x = startx
		else:
			sweep = sweep + 1
			if sweep < n_sweep:
				startx = 1 + sweep%(1+xspace)
				starty = 1 + math.floor((sweep)/(xspace + 1))
				x = startx
				y = starty
			else:
				stop = 1
				print('End of board reached')
				break
	if stop:
		break

	# Open qsf file and read all lines
	qsf = open(qsf_file_name)
	qsf_lines = qsf.readlines()
	qsf.close()

	#Make new qsf file
	new_qsf_lines = []

	for i in qsf_lines:
		if (i.find('LABCELL') == -1 and i.find('set_location_assignment FF') == -1):
			new_qsf_lines.append(i)

	new_qsf_lines.append('\n')
	for i in location_assign:
		new_qsf_lines.append(i)

	new_qsf = open(qsf_file_name,'w')

	for i in new_qsf_lines:
		new_qsf.write(i)

	new_qsf.close()


	# ------ COMPILE and PROGRAM -----------

	q_tcl.qexec('quartus_map ' + project_name)
	q_tcl.qexec('quartus_fit ' + project_name)
	q_tcl.qexec('quartus_asm ' + project_name)
	q_tcl.qexec('quartus_sta ' + project_name)
	q_tcl.qexec('quartus_pgm ' + cdf_file_name)

	print('Compile and Program done')

	#Wait for a few seconds while the program runs on the board (board waits one second before beginning measurement)
	time.sleep(5)

	#--------------------------

	#--------- GET DATA -------

	# Find index of instance named RAM1
	inst = q_mem.find_instance('RAM1')

	# Read memory from device
	binary_data = q_mem.read_mem(inst,True)


	#Convert all the binary data into a string and then into a decimal integer and put in the 
	# freq_cnts list

	for j in range(0, NUM_RO):
		bin_str = ''
		for i in range(0, word_len):
			bin_str = bin_str + str(binary_data[j][word_len - 1 - i])
		freq_cnts.append(int(bin_str, 2))
	
	#Check for outliers
	for i in range(0, NUM_RO):
		if freq_cnts[i + NUM_RO * run] > 290:
			print('(' + str(loc_dict[i + NUM_RO * run][0]) + ', ' + str(loc_dict[i + NUM_RO * run][1]) + '): ' + str(freq_cnts[i + NUM_RO * run])) 
	
	run += 1


#Convert the frequency counts into actual frequencies
freq_data = freq_cnts * slow_clk_freq

# Write data to a csv file
with open('FreqData.csv', 'w') as f:
	for i in range(0, NUM_RO):
		f.write(str((loc_dict[i][0])) + ', ' + str((loc_dict[i][1])) + ", " + str((freq_data[i])) + '\n')


#Plots

#histogram
plt.hist(freq_data, bins = 30)
plt.xlabel('Frequency')
plt.ylabel('Counts')
plt.show()

print(loc_dict)





