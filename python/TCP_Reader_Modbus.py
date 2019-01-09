#
# GE CONFIDENTIAL
# Contains confidential information under NDA with Newport Corporation
# Do not distribute
#
from socket import *
from thread import *
import random
import time
from time import sleep
from struct import *
import matplotlib.pyplot as plt
from pylab import *

#host = '192.168.240.1' # address of server (other machine) (network was set up by this machine)
host = '192.168.7.75' # address of server (other machine) (network was set up by this machine)
port = 50000         # Epehmeral port range is typicall: 49152 - 65535
addr = (host, port)
bufsize = 4
startcon1 = 'SendData'
closecon1 = 'closeconnection'
cogtest = 'octet-streamblahblah'
prefix = 'application/octet-stream'
devicename = 'DeviceName:100-pt tool'
sendname = 'SendDeviceName'

fdf = []
fdindex = []

cli = socket(AF_INET,SOCK_STREAM)
cli.connect(addr)
#cli.settimeout(5)

time.sleep(0.5)
try:
    print 'requesting device name'
    cli.sendall(sendname)
    #cli.send(sendname)
except:
    print 'sendall error'

#cli.send(sendname)
#time.sleep(0.5)
gotname = 0
while gotname == 0:
    print 'waiting'
    data = cli.recv(40)
    if data:
        print 'reply to name request = ', data
        gotname = 1
        time.sleep(0.1)
        cli.close()
        #cli.shutdown()
    else:
        print 'no data recvd, trying again'

# re-establish connection as per iPad
time.sleep(0.1)
cli2 = socket(AF_INET,SOCK_STREAM)
cli2.connect(addr)
#cli2.settimeout(5)



# send request for sensor data
try:
    print 'requesting sensor data'
    cli2.sendall(startcon1)
    #cli.send(sendname)
except:
    print 'sendall error'

dc=0
t2=0
sample_time = 0.1
while dc<10:
    dc = dc + 1
    recvstr = []
    recvstr = cli2.recv(10)
#print "received:", recvstr
#print 'unpacked', unpack('>4H2fI4H3I',data[0:40])
    if(dc>2):
        if len(recvstr) == 10:
            fd = unpack('<f3H',recvstr)
            print 'unpacked', fd
            fdf.append(fd[0])
            t2=t2+sample_time
            fdindex.append(t2)
            #print fdf[dc-3]

cli2.close()
print 'finished'
print 'num vals =',len(fdf)
print fdf
plt.subplot(2,1,1)
plt.plot(fdindex,fdf,'b',label='label',linewidth=1)
plt.savefig("/users/200005229/Desktop/sixpt.png")
