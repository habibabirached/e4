#
# GE CONFIDENTIAL
# Contains confidential information under NDA with Newport Corporation
# Do not distribute
#
import socket
import select
import random
import time
from struct import *

# creates a UDP link to the Optimet sensor
# and TCP link to forward the data
# duplicating connection 'protocol' of IWDC

# TCPUDP_Optimet2: this version of the server was modified to
# allow the client to reconnect as many times as desired
# not thoroughly tested

# v3: account for case when probe is plugged in after this script has started
# also remove delays to speed up data transfer

# v4 send distance reading in little endian format

# v5 5/2/2016 also snr, total, and bitset
# from Optimet rep:
# Bitset should be 0 (Zero)
# SNR  should be above 750 or about 75%
# ttl (Total) should be above 2000 and less than 18000

# note the divisor of SNR is actually 1024 (see Optimet Ethernet Probe Manual)


host = '192.168.7.77'  # address of ethernet adapter
#host_h = '192.168.105.33' # address assigned by wireless network
host_h = '192.168.240.1' # address assigned by wireless network
addr_sensor = ('192.168.7.1',10000)
port = 50000            # Epehmeral port range is typicall: 49152 - 65535
addr_h = (host_h, port) # tcp
addr_u = (host, 10000)     # udp
bufsize = 8192
backlog = 5
inputs = []
notify = []
startxx = 0
sendName = 'SendDeviceName'
sendData = 'SendData'
deviceName = 'DeviceName:6-pt tool'
num_sensor_reads = 10 # desired number of measurements
sensor_reads = 0
seq_ID_out = 1
tcp_setup = 0


def read_tcp(s,u):
    global startxx
    global seq_ID_out
    #print("Got TCP event")
    #if len(notify) > 0:
    #    s.reject()
    #else:

    #print 'after tcp connection was set up'
    data = s.recv(40)
    if data:
        print 'TCP received: ', data
        if data.find(sendName) >= 0:
            s.sendall(deviceName)
        elif data.find(sendData) >= 0:
            cmd = pack('>HHH', 7, seq_ID_out, 1) # last digit is number of measurements
            seq_ID_out = seq_ID_out + 1
            u.sendto(cmd, addr_sensor) # ask sensor to send data (via udp)
            s.sendall('application/octet-stream')
            startxx = 1
    else:
        print 'no data, client closed connection'
        inputs.remove(s)
        notify.remove(s)
        s.close()


def read_udp(s):
    global startxx
    global sensor_reads
    global seq_ID_out
    #ds = bytearray([0,0,0,0])
    ds = bytearray([0,0,0,0,0,0,0,0,0,0])
    #print "Got UDP event"
    data,addr_c = s.recvfrom(bufsize)
    # data parsing/conversion
    #print data
    firststring = data[4:10]
    #print 'firststring = ', firststring
    if firststring == 'tag,VT':
        print 'duplicate data format response, ignore'
    else:
        if startxx == 1:
            #print 'acknowledgement:', unpack('>H', data[0:2])
            startxx = 2
        else:
            #print 'data length',len(data)
            #print 'unpacked data', unpack('>4H2fI4H3I', data[0:40])
            xx = unpack('>4H2fI4H3I', data[0:40])
            print 'dist, ttl, snr, bst:', xx[4],xx[7],xx[8],xx[10]
            if len(notify) > 0:
                loopnotify=0
                sensor_reads = sensor_reads + 1
                for c in notify:
                    loopnotify = loopnotify +1
                    #c.sendall(data[8:12])
                    # Optimet records in big endian, change to little endian for iPad
                    ds[0] = data[11]  #  distance
                    ds[1] = data[10]
                    ds[2] = data[9]
                    ds[3] = data[8]  # distance
                    ds[4] = data[21] # ttl
                    ds[5] = data[20] #ttl
                    ds[6] = data[23] # SNR
                    ds[7] = data[22] # SNR
                    ds[8] = data[27] # bst
                    ds[9] = data[26] # bst
                    c.sendall(ds) #swap endian for ipad
                    if sensor_reads == num_sensor_reads:
                        c.close()

                    #c.sendall(str(xx[4]))
                #print 'loopnotify = ',loopnotify
                #time.sleep(0.1)
                if sensor_reads < num_sensor_reads:
                    # if speed is an issue, more data can be sent per call
                    # but this probably increases chance of data tx error (UDP)
                    cmd = pack('>HHH', 7, seq_ID_out, 1)  # last digit is number of measurements
                    seq_ID_out = seq_ID_out + 1
                    s.sendto(cmd, addr_sensor)  # ask sensor to send data (via udp)
                    startxx = 1


def run():
    # create tcp socket
    global inputs
    global notify
    global startxx
    global sensor_reads
    global seq_ID_out
    global tcp_setup

    #inputs.append(tcp)

    # create udp socket
    print "Creating UDP socket"
    udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    udp.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    udp.bind(addr_u)

    #inputs.append(udp)
    #command to sensor to send data
    # the probe may be in auto send mode, stop this

    while True:
        if tcp_setup == 1:
            inputs.append(tcp)
        inputs.append(udp)
        sensor_reads = 0
        seq_ID_out = 1
        startxx = 0
        print 'stopping probe output from previous settings'
        p_ack = 0
        while p_ack != 3:  # 3 is Optimet ACK
            cmd = pack('>H',5)
            udp.sendto(cmd, addr_sensor)
            udp.settimeout(2.0)
            try:
                data, addr = udp.recvfrom(1024)
                probe_ack = unpack('>H', data[0:2])
                p_ack = probe_ack[0]
                #print p_ack
            #except udp.settimeout:
            #    print 'no reply'
            except: # udp.error as msg:
                print 'no acknowledgement from sensor, sensor may be unplugged'
            #udp.settimeout(None)


        print 'ask for probe data format'
        probe_ready = 0
        while probe_ready == 0:
            cmd = pack('>H', 1)
            udp.sendto(cmd, addr_sensor)
            #time.sleep(0.5)
            data, addr = udp.recvfrom(1024)
            print 'data received: '
            print data
            firststring = data[4:10]
            print 'firststring = ',firststring
            if firststring == 'tag,VT':
                probe_ready = 1

        print 'probe now ready to send measurements'
        if tcp_setup == 0:
            print "Creating TCP socket"
            tcp = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            tcp.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            tcp.bind(addr_h)
            tcp.listen(backlog)
            inputs.append(tcp)
            tcp_setup = 1

        print 'waiting for tcp connection'



        #for ii in range(1,150):
        while sensor_reads < num_sensor_reads:
            #print("Waiting for message/event from anyone...")
            inputready, outputready, exceptready = select.select(inputs, [], inputs)

            #print "Received event"

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
                elif s != udp:
                    read_tcp(s,udp)
                elif s == udp:
                    read_udp(s)
                else:
                    print "unknown socket:", s.getpeername()

        print '** Finished all sensor reads and transmission to iPad **'
        inputs = []
        notify = []

if __name__ == '__main__':
    run()




