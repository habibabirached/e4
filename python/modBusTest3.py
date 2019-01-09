from time import sleep
from struct import pack
#---------------------------------------------------------------------------#
# import the various server implementations
#---------------------------------------------------------------------------#
from pymodbus.client.sync import ModbusTcpClient as ModbusClient
#---------------------------------------------------------------------------#
# configure the client logging
#---------------------------------------------------------------------------#
#import logging
#logging.basicConfig()
#log = logging.getLogger()
#log.setLevel(logging.DEBUG)
#---------------------------------------------------------------------------#
# choose the client you want
#---------------------------------------------------------------------------#
# make sure to start an implementation to hit against. For this
# you can use an existing device, the reference implementation in the tools
# directory, or start a pymodbus server.
#---------------------------------------------------------------------------#
#client = ModbusClient('192.168.168.247', port=502)
#client = ModbusClient('192.168.7.1', port=502)
client = ModbusClient('192.168.7.75', port=502)
client.connect()

# Number of data sets to collect
nSets = 10

# Maximum number of data points possible in a set
nPtsMax = 48

# Pre-allocate some arrays
dSets = [None]*nSets*nPtsMax
times = [None]*nSets*nPtsMax
displacements = [None]*nSets*nPtsMax

count = 0
dIdx = 0
curr_dSet_num = 0;
prev_dSet_num = -1
while (count < nSets):
  rr = client.read_holding_registers(64,103)
  curr_dSet_num = rr.registers[0] + (rr.registers[1] << 16)
  if (count > 0):
      # Catch duplicates and don't save them.
      if (curr_dSet_num == prev_dSet_num):
          continue
  prev_dSet_num = curr_dSet_num
  ptCount = rr.registers[2]

  #print('Set #: {}; Pt. Count: {}'.format(str(count),str(ptCount)))

  # Data starts at the 7th register
  offset = 7
  for dSet in range(ptCount):
      dSets[dIdx] = curr_dSet_num
      displacement = rr.registers[dSet*2 + offset] + (rr.registers[(dSet*2)+1+offset] << 16)
      displacements[dIdx] = float(displacement) / 10**9
      times[dIdx] = rr.registers[3] + (rr.registers[4] << 16) + \
                    (rr.registers[5] << 32) + (rr.registers[6] << 48)
      dIdx += 1

  count = count + 1
  #sleep(0.5)

# Print the data collected
print('PointID, SetTime, Displacement')
for i in range(dIdx):
    print('{}, {}, {}, {}'.format(str(i), str(dSets[i]), str(times[i]),str(displacements[i])))

print('Points collected: {}'.format(str(dIdx)))
print('Done.')

