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

# Number of points to collect
nPts = 20000

# Pre-allocate some arrays
pIDs = [None]*nPts
times = [None]*nPts;
displacements = [None]*nPts;

count = 0;
while (count < nPts):
  rr = client.read_holding_registers(0,18)
  pIDs[count] = rr.registers[0] + (rr.registers[1] << 16)
  if (count > 0):
      if (pIDs[count] == pIDs[count-1]):
          continue
  times[count] = rr.registers[2] + (rr.registers[3] << 16) + (rr.registers[4] << 32) + (rr.registers[5] << 48)
  displacement = rr.registers[6] + (rr.registers[7] << 16)
  displacements[count] = float(displacement)/10
  count = count + 1
  #sleep(0.5)

# Print the data collected
print 'PointID,  Timestamp,  Displacement'
for i in range(0, nPts):
    print str(pIDs[i]) + ', ' + str(times[i]) + ', ' + str(displacements[i])

print "Done."

