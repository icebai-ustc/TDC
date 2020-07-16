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
#File indexing type of logic at each location on a DE-10 Nano FPGA grid. Am removing everything



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

#Number of times to recompile and measureme
NUM_RUNS = 10

# Spacing Parameters
yspace = 3
xspace = 3

# --- inputs below need to match those for the quartus project 
#Number of RO's to be placed at one time. MAKE SURE to change this in the verilog file as well
NUM_RO = 100

#Number of inverters per RO (should be ODD and <=19). Specified in the .v file
nstages = 19

#Frequency of slow clock in MHz. Specified in mega function wizard for the pll
slow_clk_freq = 0.001  

#How many counts the board waits after programming before beginning measurement. In the .v file
wait_cnts = 10000	  

#Set file names
project_name = 'ROarray_v3'
cdf_file_name = 'ROarray_v3.cdf'
qsf_file_name = 'ROarray_v3.qsf' 

# ----  PARAMETERS ---------

#Length of the words in the RAM instance. Specified in mega function wizard for the RAM
word_len = 20 

# Width and height of the board
max_x = 88
max_y = 80

#Threshold frequency to consider a frequency an outlier
thres = 200

#number of sweeps needed to cover board
n_sweep = (1+yspace) * (1+xspace)

# Specifies the number of the adder that is the first one used for the counters
first_adder = 3

#Number of logic elements that can contain an RO (LABS or MLABS)
max_RO = 4191

#Total number of RO placed. May change with outliers
tot_RO = NUM_RUNS * NUM_RO

# Measurment time for each measurement in micro seconds
msmt_time = (1/slow_clk_freq)

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

# #use this code to start on a different sweep if desired
# startx = 1 + sweep%(1+xspace)
# starty = 1 + math.floor((sweep)/(xspace + 1))
# x = startx
# y = starty

#List that will hold counts from board
freq_data = []

#List that holds the outliers
outlier_num_list = []
n_outliers = 0

#Dictionary that will hold the index of each RO with it's correpsonding location on the FPGA
loc_dict = {}

# ------ MAIN LOOP ---------------
stop = 0
run = 0
y_shift = 0
while run < NUM_RUNS:
	print('RUN ' + str(run))

	# ---------- LOCATION ASSIGNMENTS ---------------- 

	# Create location assignments list
	location_assign = []

	# t tracks the number of RO's placed for current compilation
	t = 0
	while t < NUM_RO:

		type = rsrc_type[(x,y)]["TYPE"]
		type_up = rsrc_type[(x,y+1)]["TYPE"]
		type_down = rsrc_type[(x,y-1)]["TYPE"]
		if (type == "LAB" or type == "MLAB"  and ((y+1 <= max_y and (type_up == "LAB" or type_up == "MLAB")) or (y-1>=1 and (type_down == "LAB" or type_down == "MLAB")) ) ):
			#Create location assignments
			
			if (y+1 <= max_y and (type_up == "LAB" or type_up == "MLAB")): 
				type2 = type_up
				y_shift = 1
			elif (y-1>=1 and (type_down == "LAB" or type_down == "MLAB")):
				type2 = type_down
				y_shift = -1
			
			#Assignments for the ring oscillator
			for k in range(0,nstages):
				node = '"RO:generate_RO[' + str(t) + '].ro_inst|inv[' + str(k+1) + ']"'
				if type == "LAB":
					location_assign.append(create_lcell_loc_assign(node, x, y, k*3))
				if type == "MLAB":
					location_assign.append(create_mlcell_loc_assign(node, x, y, k*3))
				loc_dict[t + NUM_RO * run] = [x, y]
			
			#assignments for the counter registers
			for k in range(0,20):
				node = 'counter[' + str(t) + '][' + str(k) + ']'
				location_assign.append(create_reg_loc_assign(node,x, y+y_shift, k*3+1))
			
			#assignments for the counter adders
			for k in range(0,19):
				node = 'Add' + str(first_adder+t) + '~' + str(k*4 + 1)
				if type2 == "LAB":
					location_assign.append(create_lcell_loc_assign(node, x, y+y_shift, k*3))
				if type2 == "MLAB":
					location_assign.append(create_mlcell_loc_assign(node, x, y+y_shift, k*3))
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
	wait_time = wait_cnts/(slow_clk_freq*10**6)
	time.sleep(wait_time + 3)

	#--------------------------

	#--------- GET DATA -------

	# Find index of instance named RAM1
	inst = q_mem.find_instance('RAM1')

	# Read memory from device
	binary_data = q_mem.read_mem(inst,True)


	#Convert all the binary data into a string and then into a decimal integer and then a frequency and add to freq_data if it is not an outlier

	for j in range(0, NUM_RO):
		bin_str = ''
		for i in range(0, word_len):
			bin_str = bin_str + str(binary_data[j][word_len - 1 - i])
		freq = float(int(bin_str, 2)) * slow_clk_freq
		freq_data.append(freq)
		if (freq > thres):
			RO_num = j + NUM_RO * run
			print('(' + str(loc_dict[RO_num][0]) + ', ' + str(loc_dict[RO_num][1]) + '): ' + str(freq_data[RO_num])) 
			n_outliers = n_outliers + 1
			outlier_num_list.append(RO_num)
	run += 1


# ------------- Place all outliers on board and reprogram until we get first harmonic values for all locations ----------
o_run = 0
done_outliers = []
outlier_attempts = []
outlier_freq = []
for i in range(0, n_outliers):
	done_outliers.append(0)
	outlier_attempts.append(0)
	outlier_freq.append([])

if (n_outliers != 0):
	while (min(done_outliers) == 0):
		
		print('Outlier attempt ' + str(o_run))
		
		#Increment the number of attempts needed for each outlier
		for i in range(0, n_outliers):
			if (done_outliers[i] == 0):
				outlier_attempts[i] += 1
		
		# On the first run, create location assignments
		if (o_run == 0):
			# Create location assignments list
			location_assign = []
			
			#Create location assignments for each outlier. We won't lock down the location of the other RO's placed on the board for now
			for n in range(0, n_outliers):
				x = loc_dict[outlier_num_list[n]][0]
				y = loc_dict[outlier_num_list[n]][1]
				
				type = rsrc_type[(x,y)]["TYPE"]
				type_up = rsrc_type[(x,y+1)]["TYPE"]
				type_down = rsrc_type[(x,y-1)]["TYPE"]
				
				if (y+1 <= max_y and (type_up == "LAB" or type_up == "MLAB")): 
					type2 = type_up
					y_shift = 1
				elif (y-1>=1 and (type_down == "LAB" or type_down == "MLAB")):
					type2 = type_down
					y_shift = -1
				
				#Assignments for the ring oscillator
				for k in range(0,nstages):
					node = '"RO:generate_RO[' + str(n) + '].ro_inst|inv[' + str(k+1) + ']"'
					if type == "LAB":
						location_assign.append(create_lcell_loc_assign(node, x, y, k*3))
					if type == "MLAB":
						location_assign.append(create_mlcell_loc_assign(node, x, y, k*3))
				
				#assignments for the counter registers
				for k in range(0,20):
					node = 'counter[' + str(n) + '][' + str(k) + ']'
					location_assign.append(create_reg_loc_assign(node,x, y+y_shift, k*3+1))
				
				#assignments for the counter adders
				for k in range(0,19):
					node = 'Add' + str(first_adder+n) + '~' + str(k*4 + 1)
					if type2 == "LAB":
						location_assign.append(create_lcell_loc_assign(node, x, y+y_shift, k*3))
					if type2 == "MLAB":
						location_assign.append(create_mlcell_loc_assign(node, x, y+y_shift, k*3))
			
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
		if (o_run == 0):
			q_tcl.qexec('quartus_map ' + project_name)
			q_tcl.qexec('quartus_fit ' + project_name)
			q_tcl.qexec('quartus_asm ' + project_name)
			q_tcl.qexec('quartus_sta ' + project_name)
			q_tcl.qexec('quartus_pgm ' + cdf_file_name)
			print('Compile and Program done')
		else:
			q_tcl.qexec('quartus_pgm ' + cdf_file_name)

		#Wait for a few seconds while the program runs on the board (board waits one second before beginning measurement)
		wait_time = wait_cnts/(slow_clk_freq*10**6)
		time.sleep(wait_time + 3)

		#--------- GET DATA -------

		# Find index of instance named RAM1
		inst = q_mem.find_instance('RAM1')

		# Read memory from device
		binary_data = q_mem.read_mem(inst,True)

		#Convert all the binary data for the outliers into a string and then into a decimal integer and then a frequency and modify freq_data if it is no longer an outlier

		for j in range(0, n_outliers):
			bin_str = ''
			for i in range(0, word_len):
				bin_str = bin_str + str(binary_data[j][word_len - 1 - i])
			freq = float(int(bin_str, 2)) * slow_clk_freq
			outlier_freq[j].append(freq)
			num = outlier_num_list[j]
			if (freq < thres and done_outliers[j] == 0):
				freq_data[num] = freq
				done_outliers[j] = 1
				print('(' + str(loc_dict[num][0]) + ', ' + str(loc_dict[num][1]) + '): ' + str(freq_data[num])) 

		o_run = o_run + 1


#Calculate periods
periods = []

for i in range(0, tot_RO):
	period = (1/freq_data[i])*10**3
	periods.append(period)

#Generate separate lists for LAB/MLAB periods
LAB_periods= []
MLAB_periods = []
for i in range(0, tot_RO):
	type = rsrc_type[(loc_dict[i][0],loc_dict[i][1])]["TYPE"]
	if type == "LAB":
		LAB_periods.append(periods[i])
	if type == "MLAB":
		MLAB_periods.append(periods[i])


# Write data to a csv file
with open('FreqData.csv', 'w') as f:
	for i in range(0, tot_RO):
		f.write(str((loc_dict[i][0])) + ', ' + str((loc_dict[i][1])) + ", " + str((freq_data[i])) + '\n')
	f.write('\n \n x, y, Attempts \n')
	for i in range(0, n_outliers):
		num = outlier_num_list[i]
		f.write(str(loc_dict[num][0]) + ', ' + str(loc_dict[num][1]) + ', ' + str(outlier_attempts[i]) + '\n')
	f.write('\n \n Attempt Frequencies \n')
	for i in range(0, n_outliers):
		num = outlier_num_list[i]
		f.write('\n \n' + str(loc_dict[num][0]) + ', ' + str(loc_dict[num][1]) + '\n')
		f.write('Attempt Num, Frequency \n')
		for j in range(0, o_run):
			f.write( str(j) + ', ' + str(outlier_freq[i][j]) + '\n')
	
	f.write('\n LAB frequencies \n')
	for i in range(0, tot_RO):
		type = rsrc_type[(loc_dict[i][0],loc_dict[i][1])]["TYPE"]
		if type == "LAB":
			f.write(str((loc_dict[i][0])) + ', ' + str((loc_dict[i][1])) + ", " + str((freq_data[i])) + '\n')
	f.write('\n \n MLAB frequencies \n')
	for i in range(0, tot_RO):
		type = rsrc_type[(loc_dict[i][0],loc_dict[i][1])]["TYPE"]
		if type == "MLAB":
			f.write(str((loc_dict[i][0])) + ', ' + str((loc_dict[i][1])) + ", " + str((freq_data[i])) + '\n')


#Plots
title = str(NUM_RO) + ' RO per Run, ' + str(NUM_RUNS) + ' Runs, ' + str(msmt_time) + '\u03bcs Measure time'

# Generate Histogram
az = plt.subplot()

num_bins = 100
plottingdata = freq_data
stdevn = st.stdev(plottingdata)
meann = np.mean(plottingdata)


n, bins, patches = plt.hist(plottingdata, num_bins, facecolor='blue', alpha=0.5, histtype = 'barstacked')
textbox = '\n'.join(('$\mu=%.7f$' % (meann, ),'$\sigma=%.7f$' % (stdevn, ),'$\sigma/\mu=%.7f$' % (stdevn/meann, )))
props = dict(boxstyle='round', facecolor='wheat', alpha=0.5)
az.text(0.15, 0.95, textbox, transform=az.transAxes, fontsize=14, verticalalignment='top', bbox=props)
plt.title(r'Frequency Histogram, ' + title)
plt.ylabel('Number of values in bin') 
plt.xlabel(r'Frequency in MHz')
plt.savefig('ROfreq.pdf')
plt.close()
		


# Generate Histogram
az = plt.subplot()

num_bins = 100
plottingdata = periods
stdevn = st.stdev(plottingdata)
meann = np.mean(plottingdata)


n, bins, patches = plt.hist([LAB_periods, MLAB_periods], num_bins, alpha=0.5, histtype = "barstacked")
textbox = '\n'.join(('$\mu=%.7f$' % (meann, ),'$\sigma=%.7f$' % (stdevn, ),'$\sigma/\mu=%.7f$' % (stdevn/meann, )))
props = dict(boxstyle='round', facecolor='wheat', alpha=0.5)
az.text(0.15, 0.95, textbox, transform=az.transAxes, fontsize=14, verticalalignment='top', bbox=props)
plt.title(r'Period Histogram, ' + title)
plt.ylabel('Number of values in bin') 
plt.xlabel(r'Period (ns)')
plt.savefig('ROperiods.pdf')
plt.show()
plt.close()



#3D represenation




