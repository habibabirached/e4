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
import math
import random
import csv

TCP_IP = '127.0.0.1'
TCP_PORT = 1024
SAMPLE_RATE = 1000.00   # 1KHz
NUMBER_OF_FRAMES = 100  # Number of frames in a data set transmission

DATA_PTR = 0

def read_rotor_data(data_file):

    df = pd.read_csv(data_file)
    df.isnull().sum(axis = 0)
    #df.fillna(0.0)  # replace nan values with 0.0
    #data = df['displacement'].tolist()
    #data = df['filtered'].tolist()    
    return df

def make_data_frame(counter, displacements, intensities):
    global DATA_PTR
    global SAMPLE_RATE
    t_idx = counter * NUMBER_OF_FRAMES
    data = b'DATA'
    data = b''.join([data, b'\x00\x00\x00\x00']) # order number
    data = b''.join([data, b'\x00\x00\x00\x00']) # serial number
    data = b''.join([data, b'\x00\x00\x00\x00']) # length video data
    data = b''.join([data, b'\x00\x00\x00\x00']) # length measurement data
    n_frames = int(NUMBER_OF_FRAMES)
    frm_num_bytes = n_frames.to_bytes(4, byteorder='little', signed=False)
    data = b''.join([data, frm_num_bytes]) # number of frames per data block
    cntr = int(counter)
    counter_bytes = counter.to_bytes(4, byteorder='little', signed=False)
    data = b''.join([data, counter_bytes]) # Counter
    samp_rate = int(SAMPLE_RATE)
    t_sample = (1.0/samp_rate) * 1000 # sampling period in milliseconds
    for i in range(0,NUMBER_OF_FRAMES):

        # encode two 16-bit values for intensity and max_peak
        #data = b''.join([data, b'\xFF\x01\xFF\xFF']) # Append the intensity & peak values
        intensity = int((intensities[DATA_PTR]/100.00)*1024)
        intensity_bytes = intensity.to_bytes(2, byteorder='little', signed=False)
        data = b''.join([data, intensity_bytes ]) # Append the intensity
        data = b''.join([data, b'\xFF\xFF']) # Append the peak values
    
        # encode a 32-bit value for displacement
        displacement = int(displacements[DATA_PTR] * 1e6)
        #print("DATA_PTR: {}; disp: {}; int: {}".format(DATA_PTR, displacements[DATA_PTR], intensities[DATA_PTR]))

        displacement_bytes = displacement.to_bytes(4, byteorder='little', signed=False)
        data = b''.join([data, displacement_bytes]) # Append the displacement data bytes
        DATA_PTR = (DATA_PTR+1) % len(displacements)

        # encode a 32-bit value for timestamp
        measure_time = t_idx + i            # pseudo-timestamp (initial time + 1ms)
        time_bytes = int(measure_time).to_bytes(4, byteorder='little', signed=False)
        data = b''.join([data, time_bytes]) # Append the time

    return data

if __name__ == "__main__":

    args = sys.argv[1:]
    data_file = args[0]
    print("Simulating with data from", data_file)
    DATA_PTR = 0
    rotor_data = read_rotor_data(data_file) # read data from file
    displacements = rotor_data['filtered'].tolist()
    intensities = rotor_data['intensity'].tolist()
    print("Done reading CSV file.")
    print(len(rotor_data), "lines of data")
    count = 0
    
    if True:
        print("Connecting socket...")
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.bind((TCP_IP, TCP_PORT))
        s.listen(1)
    
        conn, addr = s.accept()
        print('Connection address:', addr)

        wait_period = float(SAMPLE_RATE / NUMBER_OF_FRAMES)
        while True:
            df = make_data_frame(count, displacements, intensities)
            conn.send(df)
            time.sleep(1.0/wait_period)
            count += 1
        conn.close()
    else:
        for i in range(0,2):
            df = make_data_frame(count, displacements, intensities)
            count += 1
