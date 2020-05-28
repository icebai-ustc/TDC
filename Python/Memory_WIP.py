import os
import math
import mif
import quartustcl
import copy
import numpy as np

class QuartusMemory():
    def __init__(self,chip_number=0,fpga_number=1):
        self.quartus = quartustcl.QuartusTcl()
        self.hwnames = self.quartus.parse(self.quartus.get_hardware_names())
        self.hwname = self.hwnames[chip_number] #picking first chip
        self.devnames = self.quartus.parse(self.quartus.get_device_names(hardware_name=self.hwname))
        self.devname = self.devnames[fpga_number] #skip SOC, which is index 0
        self.path=''
        self.name='mem{0}.mif'
        self.query()

    #Below finds instance index given a name (string)
    #For this project, instance 0 is RESET (reset bit),
    #1 is CHAL (challenges/initial states),
    #2 is RESP (responses/final states),
    #3 is N1 (carry chain of first bit), 4 is N2 (2nd bit), 5 is N3 (3rd bit)
    def find_instance(self,inst_name,N_levels=2):
        self.memories_raw = self.quartus.get_editable_mem_instances(hardware_name=self.hwname,\
            device_name=self.devname)
        self.memories = self.quartus.parse(self.memories_raw, levels=N_levels)
        found_memid = None
        for memid, depth, width, rw, type, name in memories:
            if name == inst_name:
                found_memid = memid
        if found_memid is None:
            raise RuntimeError('Could not find memory '+inst_name)
        return found_memid

    #Below reads memory from instance and returns as an array
    #Generates intermediary MIF file which is then optionally deleted
    def read_mem(self,inst,delete_mif=False):
        fname=self.path+self.name.format(inst)
        self.quartus.begin_memory_edit(hardware_name=self.hwname,\
            device_name=self.devname)
        self.quartus.save_content_from_memory_to_file(
            instance_index=inst,
            mem_file_path=fname,
            mem_file_type='mif'
        )
        with open(fname, 'r') as f:
            data = mif.load(f)
        self.quartus.end_memory_edit()
        if delete_mif:
            os.remove(fname)
        return data

    #Below writes memory to an instance from an array
    #by writing data to mif file, then to instance
    def write_mem(self,inst,data,delete_mif=False):
        fname=self.path+self.name.format(inst)
        self.quartus.begin_memory_edit(hardware_name=self.hwname,\
            device_name=self.devname)
        try:
            with open(fname, 'w') as f:
                mif.dump(data, f)
            self.quartus.update_content_to_memory_from_file(
                instance_index=inst,
                mem_file_path=fname,
                mem_file_type='mif',
            )
            self.quartus.end_memory_edit()
        except:
            self.quartus.end_memory_edit()
        if delete_mif:
            os.remove(fname)

    #Set challenges to known string
    def set_challenges(self,given_challenges=None):
        if given_challenges is None:
            self.challenges=np.array([\
               [0, 0, 0],\
               [1, 0, 0],\
               [1, 0, 1],\
               [0, 0, 1],\
               [0, 1, 1],\
               [0, 1, 0],\
               [1, 1, 0],\
               [1, 0, 0],\
               [0, 0, 0],\
               [0, 0, 0],\
               [0, 0, 0],\
               [0, 0, 0],\
               [0, 0, 0],\
               [0, 0, 0],\
               [0, 0, 0],\
               [0, 0, 0]])
            self.write_mem(inst=1,data=self.challenges)
        else:
            if type(given_challenges)=='numpy.ndarray'\
                and len(given_challenges<=16):
                self.challenges=given_challenges
                self.write_mem(given_challenges,1)

    def query(self):
        #set challenges
        self.set_challenges()
        #then reset
        #self.write_mem(inst=0,data=np.array([[0]]))
        #now enable
        self.write_mem(inst=0,data=np.array([[1]]))
        #and record responses from each instance
        self.responses=self.read_mem(inst=2).astype(int)
        self.carries=np.zeros((16,16,3))
        carry=np.zeros((16,16,3))
        #now get carry chain bits
        #and store NOT of them
        for n in range(3):
            carry[:,:,n]=self.read_mem(inst=3+n).astype(int)
        for i in range(16): #still need to deal with shift register in hardware offsetting crps
            for t in range(16):
                for n in range(3):
                    if carry[i,t,n]==0:
                        self.carries[i,t,n]=1
                    if carry[i,t,n]==1:
                        self.carries[i,t,n]=0
        #Flip? May be wrong
        self.carries=np.flip(self.carries,axis=1).astype(int)
