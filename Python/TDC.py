from devices import _5CSEBA6U23I7


class TDC():
    def __init__(self):
        self.name={
            'IN':'CarryChain:MyCarry|primitive_carry_in:mycarry_in|mycarryin',
            'CARRY':'CarryChain:MyCarry|primitive_carry:gen[{i}].mycarry|mycarry',
            'REG':'CarryChain:MyCarry|primitive_carry:gen[{i}].mycarry|mycarry'
        }
        self.chip=_5CSEBA6U23I7
        self.txt=''

    @staticmethod
    def sla(name,x,y,z,t):
        return 'set_location_assignment {3}_X{0}_Y{1}_N{2} -to "'.format(x,y,z,t)+name+'"\n'

    def Place_Carry_Chain(self,N=16,x=7,y=1):
        txt=''''''
        assert self.chip[(x,y)]['TYPE'] == 'LAB', "Require LAB coordinate."
        txt+=sla(self.name['IN'],x,y,0,'LABCELL')
        txt+=sla(self.name['CARRY'].format(i=1),x,y,3,'LABCELL')
        txt+=sla(self.name['REG'].format(i=1),x,y,4,'FF')
        for i in range(2,N+1):
            z=3*i
            txt+=sla(cell_gen.format(i=i),x,y,z,'LABCELL')
            txt+=sla(ff_gen.format(i=i),x,y,z+1,'FF')
        self.txt+=txt

    def Write_QSF(self):
        with open('qsf_source.qsf','w') as file:
            file.writelines(self.txt)
