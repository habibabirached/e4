import socket
import sys
import binascii
import telnetlib
import struct

#Telnet to the device and make sure its output is set correctly.
#Any other parameters can be set this way too.
tn_host = ('192.168.168.150')
#tn_host = ('169.254.168.150')
tn = telnetlib.Telnet(tn_host)
tn.read_until(bytearray('->','utf-8'))
tn.write(bytearray('ETHERMODE ETHERNET\n','utf-8'))
tn.read_until(bytearray('->','utf-8'))
tn.write(bytearray('OUTPUT ETHERNET\n','utf-8'))
tn.read_until(bytearray('->','utf-8'))
tn.write(bytearray('MEASTRANSFER SERVER/TCP 1024\n','utf-8'))
tn.read_until(bytearray('->','utf-8'))
tn.write(bytearray('OUT_ETH 01INTENSITY 01DIST1 TIMESTAMP\n','utf-8'))
tn.read_until(bytearray('->','utf-8'))
tn.close()

# Create a TCP/IP socket for reading data
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.settimeout(2)

# Connect the socket to the port where the server is listening
server_address = ("192.168.168.150", 1024)
#server_address = ("169.254.168.150", 1024)
print('connecting to port...')
sock.connect(server_address)
print('connected')

try:
    # Look for data
    amount_received = 0
    amount_expected = 1024
    
    while amount_received < amount_expected:
        data = sock.recv(4)
        #print('data: {}'.format(binascii.hexlify(bytearray(data))))
        # Look for 'DATA' preamble
        if data == b'\x44\x41\x54\x41':
            print('Found DATA')
            data = sock.recv(4)
            order_number = int.from_bytes(data, byteorder='little')
            print('Order number: ' + str(order_number))
            data = sock.recv(4)
            serial_number = int.from_bytes(data, byteorder='little')
            print('Serial number: ' + str(serial_number))
            data = sock.recv(4)
            video_number = int.from_bytes(data, byteorder='little')
            print('Video number: ' + str(video_number))
            data = sock.recv(4)
            measurement_number = int.from_bytes(data, byteorder='little')
            print('Measurement number: ' + str(measurement_number))
            data = sock.recv(4)
            frames_number = int.from_bytes(data, byteorder='little')
            print('frames number: ' + str(frames_number))
            data = sock.recv(4)
            counter = int.from_bytes(data, byteorder='little')
            print('counter: ' + str(counter))
            for i in range(0,frames_number):
                data = sock.recv(4)
                data_tuple = struct.unpack('hh',data)
                intensity = (float(data_tuple[0] & 2047)/1024.0)*100.0
                max_peak = data_tuple[1] & 16383
                data = sock.recv(4)
                dval = int.from_bytes(data, byteorder='little')
                dist = 0.0
                if dval > 2147483392:
                    dist = 'Error: '
                    if dval == 2147483396:
                        dist = dist + 'No Peak'
                    if dval == 2147483397:
                        dist = dist + 'Peak in front of MR'
                    if dval == 2147483398:
                        dist = dist + 'Peak in back of MR'
                    if dval == 2147483399:
                        dist = dist + 'Measurement cannot be calculated'
                    if dval == 2147483400:
                        dist = dist + 'Measurement is outside representable area'
                else:
                    dist = float(dval) * 1e-6
                data = sock.recv(4)
                tstamp = int.from_bytes(data, byteorder='little')
                tstamp = float(tstamp) * 1e-6
                print('intensity: ' + str(intensity) + '; timestamp: ' + str(tstamp) + '; distance: ' + str(dist))
                
        #amount_received += len(data)
        amount_received = 0

finally:
    print('closing socket')
    sock.close()
