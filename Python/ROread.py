from QuartusMemory import QuartusMemory
import numpy as np
import matplotlib.pyplot as plt
import statistics as st
from scipy.optimize import minimize


quartus = QuartusMemory()

inst = quartus.find_instance('RAM1')

data = quartus.read_mem(inst,True)

has_data = []
data_num = []
num = 0
strng = ''

# Determines which addresses have values
for i in data:
    for k in i:
        num = num + k
    if num == 0:
        has_data.append(False)
    else:
        has_data.append(True)
    #print(num)
    num = 0

# Takes addresses with data and get int value
for i in range(len(data)):
    if has_data[i]:
        for k in data[i]:
            strng = str(k) + strng
        data_num.append(int('0b' + strng,2))
        #print(strng)
        strng = ''

for i in range(len(data_num)):
    if data_num[i] > 700:
        print(i)

# Generate Histogram
az = plt.subplot()

num_bins = 100
plottingdata = data_num
stdevn = st.stdev(plottingdata)
meann = np.mean(plottingdata)

#print(len(data_num))

n, bins, patches = plt.hist(plottingdata, num_bins, facecolor='blue', alpha=0.5)
textbox = '\n'.join(('$\mu=%.7f$' % (meann, ),'$\sigma=%.7f$' % (stdevn, ),'$\sigma/\mu=%.7f$' % (stdevn/meann, )))
props = dict(boxstyle='round', facecolor='wheat', alpha=0.5)
az.text(0.15, 0.95, textbox, transform=az.transAxes, fontsize=14, verticalalignment='top', bbox=props)
plt.title(r'Frequency of ' + str(len(data_num)) + r' N=19 Ring Oscillators')
plt.ylabel('Number of values in bin') 
plt.xlabel(r'Frequency in MHz')
# plt.ylim(0,240)
# plt.xlim(meann - 0.0008*meann,meann + 0.0008*meann)
plt.savefig('ROdata.pdf')
