#
# GE CONFIDENTIAL
#
import socket
import select
import random
import time
from struct import *
from time import sleep
from pymodbus.client.sync import ModbusTcpClient as ModbusClient

# Reads the Modbus registers in the MTI Capacitance sensor
# and opens a TCP link to forward the data
# duplicating connection 'protocol' of IWDC

# TCPModbus_MTI_1: this version of the server was modified
# from Fergus Ross' TCPUDP_Optimet5.py script.
# 

host = '192.168.7.77'  # address of ethernet adapter
#host_h = '192.168.240.1' # address assigned by wireless network (YUN)
host_h = '192.168.1.66' # address assigned by wireless network
addr_sensor = '192.168.7.75'
sensor_port = 502             # port for Modbus
addr_h = (host_h, sensor_port) # tcp
addr_u = (host, 10000)     # udp
bufsize = 8192
backlog = 5
inputs = []
notify = []
startxx = 0
sendName = 'SendDeviceName'
sendData = 'SendData'
deviceName = 'DeviceName:Modbus tool'
num_sensor_reads = 200 # desired number of measurements
sensor_reads = 0
seq_ID_out = 1
tcp_setup = 0


def read_tcp(s,c):
    global startxx
    global seq_ID_out

    #print 'after tcp connection was set up'
    data = s.recv(40)
    if data:
        print 'TCP received: ', data
        if data.find(sendName) >= 0:
            s.sendall(deviceName)
        elif data.find(sendData) >= 0:
	    
	    #Pack up and send the data
            cmd = pack('>HHH', 7, seq_ID_out, 1) # last digit is number of measurements
            seq_ID_out = seq_ID_out + 1

	    # Get data from Sensor
	    read_modbus(c);

	    # Pack the data into a single object for transmission
	    allPts = [None]*num_sensor_reads
	    for i in range(0, num_sensor_reads):
		allPts[i] = (pIDs[i],times[i],displacements[i])

	    # Send the data type
            s.sendall('application/octet-stream')
	    # Send the data
	    s.sendall(allPts)
            startxx = 1
    else:
        print 'no data, client closed connection'
        inputs.remove(s)
        notify.remove(s)
        s.close()


# read_modbus reads 'num_sensor_reads' data points from the Modbus client.
# In the process it discards any duplicate reads.
def read_modbus(client):

    sensor_reads = 0;
    while (sensor_reads < num_sensor_reads):
	rr = client.read_holding_registers(0,18)
	pIDs[sensor_reads] = rr.registers[0] + (rr.registers[1] << 16)
	if (sensor_reads > 0):
	    if (pIDs[sensor_reads] == pIDs[sensor_reads-1]):
		continue
	times[sensor_reads] = rr.registers[2] + (rr.registers[3] << 16) + (rr.registers[4] << 32) + (rr.registers[5] << 48)
	displacement = rr.registers[6] + (rr.registers[7] << 16)
	displacements[sensor_reads] = float(displacement)/10
	sensor_reads = sensor_reads + 1

    # Print the data collected
    #print 'PointID,  Timestamp,  Displacement'
    #for i in range(0, num_sensor_reads):
	#print str(pIDs[i]) + ', ' + str(times[i]) + ', ' + str(displacements[i])
    #print "Done."

def run():
    # create tcp socket
    global inputs
    global notify
    global startxx
    global sensor_reads
    global seq_ID_out
    global tcp_setup
    global client

    # Pre-allocate some arrays
    global pIDs
    global times
    global displacements
    pIDs = [None]*num_sensor_reads
    times = [None]*num_sensor_reads
    displacements = [None]*num_sensor_reads

    #create the Modbus connection
    print "Creating Modbus connection"
    client = ModbusClient(addr_sensor, port=sensor_port)
    connectSuccess = client.connect()
    while connectSuccess == False:
	print "Failed to connect to Modbus sensor. Trying again..."
	connectSuccess = client.connect()
	startxx = 0

    print "Connected to Modbus sensor."

    while True:
	# set up TCP connection
        if tcp_setup == 1:
            inputs.append(tcp)
        sensor_reads = 0
        seq_ID_out = 1
        startxx = 0

        if tcp_setup == 0:
            print "Creating TCP socket"
            tcp = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            tcp.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            tcp.bind(addr_h)
            tcp.listen(backlog)
            inputs.append(tcp)
            tcp_setup = 1

        print 'Waiting for tcp connection'

	#print("Waiting for message/event from TCP connection...")
        inputready, outputready, exceptready = select.select(inputs, [], inputs)

	# process any exceptions first - i.e., closed/aborted connections
	for s in exceptready:
	    print "received exception condition for: ", s.getpeername(), " closing connection"
	    inputs.remove(s)
	    notify.remove(s)
	    s.close()
	    startxx = 0

	# now process any descriptors with input to be processed
	for s in inputready:
	    if s == tcp:
		print 'accept tcp connection'
		client, addr_c = s.accept()
		inputs.append(client)
		notify.append(client)
		startxx = 1
		read_tcp(s,client)
	    else:
		print "unknown socket:", s.getpeername()

        print '** Finished all sensor reads and transmission to iPad **'
        inputs = []
        notify = []

if __name__ == '__main__':
    run()




