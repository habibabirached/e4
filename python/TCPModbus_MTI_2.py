''' GE Confidential '''
#
# GE CONFIDENTIAL
#
import sys
import socket
import select
import random
import time
import numpy as np
import pandas as pd
from struct import *
from time import sleep
from pymodbus.client.sync import ModbusTcpClient as ModbusClient

# Reads the Modbus registers in the MTI Capacitance sensor
# and opens a TCP link to forward the data
# duplicating connection 'protocol' of IWDC

# TCPModbus_MTI_2: this version of the server was modified
# from TCPModbus_MTI_1.py, which has some sensor sample
# rate limitations due to older MTI sensor firmware.
# TCPModbus_MTI_1.py was base on Fergus Ross'
# TCPUDP_Optimet5.py script.
# 

host = '192.168.7.77'  # address of ethernet adapter
#host_h = '192.168.240.1' # address assigned by wireless network (YUN)
host_h = '192.168.1.66' # address assigned by wireless network
addr_sensor = '192.168.7.75'
sensor_port = 502             # port for Modbus
inputs = []
notify = []
iwdc_commands = {'sendName':'SendDeviceName',
                 'sendData':'SendData',}
deviceName = 'DeviceName:Modbus tool'
seq_ID_out = 1
tcp_setup = 0


def read_tcp(strm, client, num_sensor_reads):
    ''' read_tcp '''
    global seq_ID_out

    #print 'after tcp connection was set up'
    data = strm.recv(40)
    if data:
        print 'TCP received: ', data
        if data.find(iwdc_commands['sendName']) >= 0:
            strm.sendall(deviceName)
        elif data.find(iwdc_commands['sendData']) >= 0:
	    
	    #Pack up and send the data
            cmd = pack('>HHH', 7, seq_ID_out, 1) # last digit is number of measurements
            seq_ID_out = seq_ID_out + 1

	    # Get data from Sensor
	    collection_data = read_modbus(client, num_sensor_reads);

	    # Convert the sample data to JSON for transmission
            json_data = collection_data['sensor_data'].to_json(orient='split')

	    # Send the data type
            strm.sendall('application/json')
	    # Send the data
	    strm.sendall(json_data)
    else:
        print 'no data, client closed connection'
        inputs.remove(strm)
        notify.remove(strm)
        strm.close()


# read_modbus reads 'num_sensor_reads' data points from the Modbus client.
# In the process it discards any duplicate reads.
def read_modbus(client, num_sensor_reads):
    ''' read_modbus '''
    # Max number of points in a dataset.
    num_pts_max = 48
    #---------------------------------------------------------------------------#
    # Pre-allocate some memory so that acquisition speed is not hindered
    # by memory allocation.
    #---------------------------------------------------------------------------#
    current_data_set_id = 0
    previous_data_set_id = 0

    # Use Numpy array's for data collection because they populate fast.
    datasetIds = np.zeros(num_sets*num_pts_max)
    times = np.zeros(num_sets*num_pts_max)
    displacements = np.zeros(num_sets*num_pts_max)
    point_counts = np.zeros(num_sets*num_pts_max)

    columns = ['pt_count', 'dataset_id', 'timestamp', 'displacement', 'filtered']
    point_indices = list(range(num_sets*num_pts_max))
    sensor_df = pd.DataFrame(index=point_indices, columns=columns)
    sensor_df['displacement'] = sensor_df['displacement'].astype(float)
    sensor_df = sensor_df.fillna(0)

    #---------------------------------------------------------------------------#
    # Get the data! Keep this loop as tight as possible so that data sets are
    # not dropped.  Avoid any extra processing.
    #---------------------------------------------------------------------------#
    set_count = 0
    data_index = 0
    offset = 7
    while set_count < num_sets:
        read_reg = client.read_holding_registers(64, 103)
        current_data_set_id = read_reg.registers[0] + (read_reg.registers[1] << 16)
        if set_count > 0:
            # Catch duplicates and don't save them.
            if current_data_set_id == previous_data_set_id:
                continue
        previous_data_set_id = current_data_set_id
        pt_count = read_reg.registers[2]
        for data_pt in range(pt_count):
            disp = read_reg.registers[data_pt*2 + offset] + \
                   (read_reg.registers[(data_pt*2)+1+offset] << 16)
            displacements[data_index] = float(disp / 10**9)
            times[data_index] = read_reg.registers[3] + \
                                (read_reg.registers[4] << 16) +\
                                (read_reg.registers[5] << 32) + \
                                (read_reg.registers[6] << 48)
            datasetIds[data_index] = current_data_set_id
            point_counts[data_index] = pt_count
            data_index += 1
        set_count = set_count + 1

    # remove any extraneous rows
    sensor_df['pt_count'] = point_counts
    sensor_df['dataset_id'] = datasetIds
    sensor_df['timestamp'] = times
    sensor_df['displacement'] = displacements
    sensor_df = sensor_df[sensor_df.dataset_id != 0]
    t0 = sensor_df['timestamp'].iloc[0]
    tf = sensor_df['timestamp'].iloc[-1]
    t_total = (tf-t0)/10**6
    total_points = len(sensor_df.index)
    samp_freq = total_points/t_total
    print('Points collected: {}'.format(total_points))
    print('Elapsed Collection time: {}s'.format(t_total))
    print('Average samples/sec: {}'.format(samp_freq))
    if len(args) > 2:
        if args[2] != 'false':
            print('Saving raw data to CSV file: {}'.format(args[2]))
            sensor_df.to_csv(args[2], sep=',')
    return {'samp_freq':samp_freq, 'sensor_data':sensor_df}


def run(num_sensor_reads):
    ''' run loop '''
    # create tcp socket
    global inputs
    global notify
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

    print "Connected to Modbus sensor."

    addr_h = (host_h, sensor_port) # tcp
    backlog = 5
    while True:
	# set up TCP connection
        if tcp_setup == 1:
            inputs.append(tcp)
        seq_ID_out = 1

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
	for strm in exceptready:
	    print "received exception condition for: ", strm.getpeername(), " closing connection"
	    inputs.remove(strm)
	    notify.remove(strm)
	    strm.close()

	# now process any descriptors with input to be processed
	for strm in inputready:
	    if strm == tcp:
		print 'accept tcp connection'
		client, addr_c = strm.accept()
		inputs.append(client)
		notify.append(client)
		read_tcp(strm,client, num_sensor_reads)
	    else:
		print "unknown socket:", s.getpeername()

        print '** Finished all sensor reads and transmission to iPad **'
        inputs = []
        notify = []

if __name__ == '__main__':
    args = sys.argv[1:]
    num_sensor_reads = args[0]
    run(num_sensor_reads)
