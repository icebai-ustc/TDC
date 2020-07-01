from devices import _5CSEBA6U23I7 as x
import numpy as np
import sys
np.set_printoptions(threshold=sys.maxsize)

#make a grid representing the coordinates on the FPGA
#because you only code using naive algorithms
grid = np.zeros(shape=(88,80))

#we're just gonna go rectangle mode but avoiding the bad bits
#input the starting and ending coordinates of your rectangle
max_x = 20
min_x = 10
max_y = 20
min_y = 1

#what do you want your spacing to be? 
#currently not super friendly to y coordinate
#keep in mind the coordinates start at 1 on the FPGA & proceed with caution
x_step = 2
y_step = 2

#we do be wanting to know how many oscillators
RO_counter = 0

#puts ones where we want the oscillator drip
#liam if you're reading this follow my tiktok handle @kilcup.net
#checks if bottom is a LABCELL and skips row if not
i = min_x-1
while (i < max_x):
	if x[( (i+1),min_y)]["TYPE"] == "LAB":
		for j in range( (min_y-1), max_y, y_step):
			if x[((i+1),(j+1))]["TYPE"] == "LAB":
				grid[(i,j)] = 1
				RO_counter +=1
		i+=x_step	
	else:
		i+=1
print(RO_counter)

#come up with a better naming strategy?

a_out = open('loc_assignment_RO_smol.txt','w')
r_out = open('loc_reference_RO_smol.txt','w')
p_out = open('loc_vec_RO.txt','w')

str_ROcount = 'number of RO = ' + str(RO_counter)
#writes the number of osc to both, but probably can be removed
r_out.write(str_ROcount + '\n\n')
a_out.write(str_ROcount + '\n\n')

#how many elements of delay line to place 
num_place = 20 
index_RO = 0
for i in range (min_x-1, max_x,1):
	for j in range (min_y-1,max_y,1):
		if grid[(i,j)]==1:
			for k in range (0,num_place,1):
				loc_ass = 'set_location_assignment LABCELL_X'+str(i+1) \
							+ '_Y'+str(j+1)+'_N'+str(3*k)+ ' -to "ring_osc:generate_RO['  \
							+ str(index_RO)+'].ROinst|delay['+str(k)+ ']"' + '\n'
				a_out.write(loc_ass)
			a_out.write('\n')
			ref_ass = ('X = '+ str(i+1) +', '+ 'Y = ' + str(j+1)+ ', ' + 'RO = ' + str(index_RO))
			r_out.write(ref_ass+'\n')
			p_out.write(str(index_RO)+'\t'+str(i+1)+'\t'+str(j+1)+'\n')
			index_RO +=1
r_out.close()
a_out.close()
p_out.close()
