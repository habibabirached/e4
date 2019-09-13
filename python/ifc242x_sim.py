''' Script to collect data from ifc242x sensor controller. '''
import sys
import socket
import binascii
import json
import requests
import time
import numpy as np
import pandas as pd
from scipy import signal
from datetime import datetime

TCP_IP = '127.0.0.1'
TCP_PORT = 1024
BUFFER_SIZE = 1024
SAMPLE_RATE = 1000.00 # 1KHz
NUMBER_OF_FRAMES = 100

def make_data_frame(counter):
    t0 = time.time()    
    data = b'DATA'
    data = b''.join([data, b'\x00\x00\x00\x00']) # order number
    data = b''.join([data, b'\x00\x00\x00\x00']) # serial number
    data = b''.join([data, b'\x00\x00\x00\x00']) # length video data
    data = b''.join([data, b'\x00\x00\x00\x00']) # length measurement data
    frm_num_bytes = NUMBER_OF_FRAMES.to_bytes(4, byteorder='little', signed=False)
    data = b''.join([data, frm_num_bytes]) # number of frames per data block
    counter_bytes = counter.to_bytes(4, byteorder='little', signed=False)
    data = b''.join([data, counter_bytes]) # Counter
    for i in range(0,NUMBER_OF_FRAMES):
        # encode two 16-bit values for intensity and max_peak
        data = b''.join([data, b'\xFF\x01\xFF\xFF']) # Append the intensity & peak values
        # encode a 32-bit value for displacement
        i_bytes = i.to_bytes(4, byteorder='little', signed=False)
        data = b''.join([data, i_bytes]) # Append the displacement data bytes
        # encode a 32-bit value for timestamp
        measure_time = (time.time() - t0)  # utc time - yesterday's time
        measure_time = measure_time * 1e6 # get the milliseconds
        measure_time = int(measure_time)    # truncate to integer
        time_bytes = measure_time.to_bytes(4, byteorder='little', signed=False)
        data = b''.join([data, time_bytes]) # Append the time
        time.sleep(1.0/SAMPLE_RATE)
    return data

if __name__ == "__main__":

    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.bind((TCP_IP, TCP_PORT))
    s.listen(1)
    
    conn, addr = s.accept()
    print('Connection address:', addr)
    count = 0
    wait_period = float(SAMPLE_RATE / NUMBER_OF_FRAMES)
    while True:
        df = make_data_frame(count)
        conn.send(df)
        time.sleep(1.0/wait_period)
        count += 1
    conn.close()    
