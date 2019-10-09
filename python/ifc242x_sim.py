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
BLADES_PER_STAGE = 80   #
ROTOR_RPM = 5           #
ROTOR_DIAMETER = 2.0    # Rotor Diameter in m
BLADE_THICKNESS = 0.003 # Blade thicknes in m
DATA_PTR = 0

def make_rotor_data():
    rotor_circ = (ROTOR_DIAMETER * math.pi)         # rotor circumference
    tangent_speed = rotor_circ * ROTOR_RPM / 60.0   # linear speed at blade tips in m/s
    samples_per_meter = SAMPLE_RATE / tangent_speed
    samples_per_rotor = samples_per_meter * rotor_circ
    samples_per_blade = int(samples_per_meter * BLADE_THICKNESS)
    noise = random.sample(range(-50, 50), BLADES_PER_STAGE)
    noise = [noise[i]/100 for i in range(0,len(noise))]
    data = [15.0] * int(samples_per_rotor+0.5)      # data list initialized with max sensor value.
    blade_dist = [1.0] * BLADES_PER_STAGE           # distance to each blade tip
    blade_dist = [blade_dist[i] + noise[i] for i in range(0,len(blade_dist))]
    # A 'section' of the rotor here means a section containing a blade
    # and the gap until the next blade.
    samples_per_section = int(samples_per_rotor / BLADES_PER_STAGE)
    idx = 0
    for i in range(0,BLADES_PER_STAGE):
        idx = (i * samples_per_section)
        start_pt = idx + int(samples_per_section/2.0)
        for j in range( start_pt, start_pt + samples_per_blade):
            data[j] = blade_dist[i]
    if False:
        with open('sim_data.csv', mode='w') as csv_file:
            writer = csv.writer(csv_file, delimiter=',', quotechar='"', quoting=csv.QUOTE_MINIMAL, lineterminator='\n')
            for i in range(0,len(data)):
                writer.writerow([i,data[i]])

    # Average & print ten blade distances for comparison purposes.
    blade_avg = 0.0
    #npts = 10
    npts = len(blade_dist)
    for i in range(npts-1):
        blade_avg = blade_avg + blade_dist[i]
    blade_avg = blade_avg / float(npts)
    print("Blade average distance: ", blade_avg)
    
    return data

def make_data_frame(counter, rotor_data):
    global DATA_PTR
    t_idx = counter * NUMBER_OF_FRAMES
    data = b'DATA'
    data = b''.join([data, b'\x00\x00\x00\x00']) # order number
    data = b''.join([data, b'\x00\x00\x00\x00']) # serial number
    data = b''.join([data, b'\x00\x00\x00\x00']) # length video data
    data = b''.join([data, b'\x00\x00\x00\x00']) # length measurement data
    frm_num_bytes = NUMBER_OF_FRAMES.to_bytes(4, byteorder='little', signed=False)
    data = b''.join([data, frm_num_bytes]) # number of frames per data block
    counter_bytes = counter.to_bytes(4, byteorder='little', signed=False)
    data = b''.join([data, counter_bytes]) # Counter
    t_sample = (1.0/SAMPLE_RATE) * 1000 # sampling period in milliseconds
    for i in range(0,NUMBER_OF_FRAMES):

        # encode two 16-bit values for intensity and max_peak
        data = b''.join([data, b'\xFF\x01\xFF\xFF']) # Append the intensity & peak values

        # encode a 32-bit value for displacement
        disp = int(rotor_data[DATA_PTR] * 1e6)

        disp_bytes = disp.to_bytes(4, byteorder='little', signed=False)
        data = b''.join([data, disp_bytes]) # Append the displacement data bytes
        DATA_PTR = (DATA_PTR+1) % len(rotor_data)

        # encode a 32-bit value for timestamp
        measure_time = t_idx + i            # pseudo-timestamp (initial time + 1ms)
        time_bytes = int(measure_time).to_bytes(4, byteorder='little', signed=False)
        data = b''.join([data, time_bytes]) # Append the time

    return data

def find_patterns(data):
    df = pd.DataFrame(data, columns=['data'])
    ac = np.zeros(len(df['data']))
    for i in range(0,len(df)-1):
        ac[i] = df['data'].autocorr(lag=i)

    with open('pattern_data.csv', mode='w') as csv_file:
        writer = csv.writer(csv_file, delimiter=',', quotechar='"', quoting=csv.QUOTE_MINIMAL, lineterminator='\n')
        for i in range(0,len(ac)):
            writer.writerow([i,ac[i]])


if __name__ == "__main__":

    DATA_PTR = 0
    rotor_data = make_rotor_data() # construct one cycle of data around the turbine
    #find_patterns(rotor_data)
    count = 0
    
    if True:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.bind((TCP_IP, TCP_PORT))
        s.listen(1)
    
        conn, addr = s.accept()
        print('Connection address:', addr)

        wait_period = float(SAMPLE_RATE / NUMBER_OF_FRAMES)
        while True:
            #rotor_data = make_rotor_data() # make new data with each iteration.
            df = make_data_frame(count, rotor_data)
            conn.send(df)
            time.sleep(1.0/wait_period)
            count += 1
        conn.close()
    else:
        for i in range(0,2):
            rotor_data = make_rotor_data() # make new data with each iteration.
            df = make_data_frame(count, rotor_data)
            count += 1
