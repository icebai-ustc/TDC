from QuartusMemory import QuartusMemory

q = QuartusMemory()

# Find index of instance named RAM1
inst = q.find_instance('RAM1')

# Read memory from device
arr = q.read_mem(inst,True)

# Print contents of address 0x04
print('Arr1:')
for k in arr[4]:
    print(str(k) + ' ',end='')
print()

# Copy the array and change one of the bits in 0x04
arr2 = arr
arr2[4][1] = 1

# Print the new array
print('Arr2:')
for k in arr2[4]:
    print(str(k) + ' ',end='')
print()

# Write the memory to the device
q.write_mem(inst,arr2,True)

# Read memory into a new array
arr3 = q.read_mem(inst,True)

# Print to confirm that memory was changed
print('Arr3:')
for k in arr3[4]:
    print(str(k) + ' ',end='')
print()
