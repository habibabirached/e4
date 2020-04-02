''' Script to collect data from Micro Epsilon sensor over TCP/IP. '''
import sys
import os.path
import socket
import binascii
import asyncio
import websockets
import json
import requests
import time
import numpy as np
import pandas as pd
from scipy import signal
from datetime import datetime, timezone
from asgiref.sync import async_to_sync
import telnetlib
import struct
import csv
import math
import sqlite3
import pickle

SIMULATOR = False

#PARAMS: [0]=nFrames,
#        [1]=Save data or not ('false' or a file name),
#        [2]=Digital Filter Cutoff Freq.(if used),
#        [3]=Casing Thickness,
#        [4]=Spacer Thickness
PARAMS = ["","","","",""]
THRESHOLD = 10.0
FILTER_ORDER = 1
LAST_SAVED_FILE = ""
MEASUREMENT_RATE = 1.000 # units are kHz
SENSOR_HOST = "192.168.168.150"
SENSOR_WEBSOCKET =  "192.168.168.41"
if SIMULATOR == True:
    SENSOR_HOST = "127.0.0.1"
    SENSOR_WEBSOCKET = "127.0.0.1"
    #SENSOR_WEBSOCKET = "192.168.1.8"
WEBSOCKET_PORT = 3405
DB_CONN = None

SCAN_META_DATA = {"frame":"",
                  "serial_number":"",
                  "customer":"",
                  "site":"",
                  "operator":"",
                  "units":"",
                  "state":""}

# Start of sensor measurement range in mm
SMR = 11.0
# Sensor length in mm
SENSOR_LENGTH = 8.93 * 25.4

def is_number(s):
    try:
        float(s)
        return True
    except ValueError:
        return False

async def ws_msg_handler(websocket, path):
    global SCAN_META_DATA
    global MEASUREMENT_RATE
    while True:
        rx_msg = await websocket.recv()
        msg = json.loads(rx_msg)
        print("WS: Message received: {}".format(msg))
        msg_dict = json.loads(msg["text"])
        msg_args = msg_dict["args"]
        for i in range(0,len(msg_args)):
            if isinstance(msg_args[i], str):
                msg_args[i] = msg_args[i].strip()

        nSecs = 0
        meas_rate = 0
        if (len(msg_args) > 1):
            print("msg_args: {}".format(msg_args))
            if is_number(msg_args[1]):
                if msg_args[0] == 'send_data':
                    nSecs = msg_args[1]
                    nFrames = ((MEASUREMENT_RATE * 1000.0) * float(nSecs))/100.0 # N Ksamp/sec; 100 samp/frame
                    PARAMS[0] = int(nFrames)
                if msg_args[0] == 'set_measuring_rate':
                    meas_rate = msg_args[1]; # meas_rate should be in kHz.
        if msg_args[0] == 'ping':
            print("Websocket: Got ping, sending pong.")
            data_dict = {'type':'pong'}
            json_data = json.dumps(data_dict)
            await websocket.send(json_data)

        if msg_args[0] == 'send_data':
            print("Data requested for {} seconds ({} dataframes).".format(nSecs,PARAMS[0]))
            frame = ""
            sn = ""
            stage = ""
            position = ""
            casing_thickness = 0.0
            spacer_thickness = 0.0
            if len(msg_args) > 2:
                frame = msg_args[2]
                sn = msg_args[3]
                stage = msg_args[4]
                position = msg_args[5]
                if is_number(msg_args[6]):
                    casing_thickness = float(msg_args[6])
                    spacer_thickness = float(msg_args[7])
                    PARAMS[3] = casing_thickness
                    PARAMS[4] = spacer_thickness
            raw_data = await collect_data(PARAMS, websocket)
            if len(PARAMS) > 2:
                # Apply LPF
                filter_data(PARAMS, raw_data)

            sensor_data = raw_data['sensor_data']
            peaks_avg_out, peak_locs, gaps = peak_find(PARAMS, sensor_data)
            clearance = compute_clearance(peaks_avg_out, peak_locs, gaps, sensor_data, casing_thickness, spacer_thickness)
            save_data(PARAMS, sensor_data, peak_locs, gaps, frame=frame, sn=sn, stage=stage, position=position, \
                      casing_thickness=casing_thickness, spacer_thickness=spacer_thickness)
            #find_patterns(PARAMS, sensor_data['displacement'])

            #decimate the data we send over the web interface
            factor = int(1)
            plot_df = sensor_data['filtered'].iloc[::factor]
            int_df = sensor_data['intensity'].iloc[::factor]
            peak_locs = peak_locs / factor
            data_dict = {'type':'data',
                         'data':plot_df.tolist(),
                         'intensity':int_df.tolist(),
                         'locs':peak_locs.tolist(),
                         'gaps':gaps.tolist(),
                         'clearance':clearance,
                         'casing_thickness':casing_thickness,
                         'spacer_thickness':spacer_thickness}
            json_data = json.dumps(data_dict)
            await websocket.send(json_data)
        if msg_args[0] == 'scan_meta_data':
            print("Saving scan meta data...")
            SCAN_META_DATA['frame'] = msg_args[1]
            SCAN_META_DATA['serial_number'] = msg_args[2]
            SCAN_META_DATA['customer'] = msg_args[3]
            SCAN_META_DATA['site'] = msg_args[4]
            SCAN_META_DATA['operator'] = msg_args[5]
            SCAN_META_DATA['units'] = msg_args[6]
            SCAN_META_DATA['state'] = msg_args[7]
        if msg_args[0] == 'shutdown':
            print("Got shutdown message over websocket.")
            system_shutdown()

        if msg_args[0] == 'get_data_file':
            global LAST_SAVED_FILE
            print("Got filename request. File is {}".format(LAST_SAVED_FILE));
            dl_file = LAST_SAVED_FILE
            if SIMULATOR == True:
                dl_file = LAST_SAVED_FILE.replace("app/www/","")
            data_dict = {'type':'filename',
                         'fname':dl_file}
            json_data = json.dumps(data_dict)
            await websocket.send(json_data)

        if msg_args[0] == 'do_dark_reference':
            await dark_reference(websocket)

        if msg_args[0] == 'do_mastering':
            await do_mastering(websocket)

        if msg_args[0] == 'set_measuring_rate':
            # meas_rate should be in kHz.
            await set_measuring_rate(meas_rate)

async def dark_reference(websocket):
    global MEASUREMENT_RATE
    print('@dark_reference()')
    # send dark reference command
    tn_host = (SENSOR_HOST)
    tn = telnetlib.Telnet(tn_host)
    tn.read_until(bytearray('->','utf-8'))
    print("Sending dark correction command")
    send_cmd('DARKCORR',tn)
    tn.close()    
    print("Dark correction complete")
    #next do data collection and show results
    nSecs = 10
    nFrames = ((MEASUREMENT_RATE * 1000.0) * float(nSecs))/100.0 # 1K samp/sec; 100 samp/frame
    PARAMS[0] = int(nFrames)
    print("Acquiring Data")          
    raw_data = await collect_data(PARAMS, websocket)
    if len(PARAMS) > 2:
        # Apply LPF
        filter_data(PARAMS, raw_data)
        
    sensor_data = raw_data['sensor_data']
    peaks_avg_out, peak_locs, gaps = peak_find(PARAMS, sensor_data)
    save_data(PARAMS, sensor_data, peak_locs, gaps)

    #decimate the data we send over the web interface
    factor = int(20)
    plot_df = sensor_data['filtered'].iloc[::factor]
    peak_locs = peak_locs / factor
    data_dict = {'type':'data',
                 'data':plot_df.tolist(),
                 'locs':peak_locs.tolist(),
                 'gaps':gaps.tolist()}
    json_data = json.dumps(data_dict)
    await websocket.send(json_data)

async def do_mastering(websocket):
    print('@do_mastering()')
    if SIMULATOR == False:
        # send mastering command
        tn_host = (SENSOR_HOST)
        tn = telnetlib.Telnet(tn_host)
        tn.read_until(bytearray('->','utf-8'))
        print("Sending mastering command(s)")
        # Clear previous mastering values
        send_cmd('MASTERSIGNAL 01DIST1 NONE',tn)
        # Set mastering value to 5mm.
        send_cmd('MASTERSIGNAL 01DIST1 5.0',tn)
        # Activate master value
        tn.write(bytearray('MASTER 01DIST1 SET\n','utf-8'))
        response = tn.read_until(bytearray('->','utf-8'))
        response = response.decode('utf8')
        tn.close()    
        if response.find('out of range') == -1:
            await send_status_message(websocket, "done_mastering")
        else:
            await send_status_message(websocket, "failed_mastering")
            print("Mastering complete")
    else:
        time.sleep(3)
        await send_status_message(websocket, "done_mastering")
        
def system_shutdown():
    if sys.platform == 'win32':
        print("If this were Linux, the machine would be shutting down now.")
        return
    else:
        print("Linux system detected. Attempting to shut down now.")
        import os
        print("Shutting down now.")
        os.system('sudo shutdown now')
        # end of the line

async def send_status_message(websocket, status_msg):
    # Send status message
    print("Sending status message: {}".format(status_msg))
    data_dict = {'type':'status','status':status_msg}
    json_data = json.dumps(data_dict)
    await websocket.send(json_data)

async def collect_data(params, websocket):
    '''This is the main function for acquiring data over ModBus'''
    #---------------------------------------------------------------------------#
    # Create a TCP/IP socket
    #---------------------------------------------------------------------------#
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    # Connect the socket to the port where the server is listening
    server_address = (SENSOR_HOST, 1024)
    print('connecting to port...')
    sock.connect(server_address)
    print('connected')
    
    #---------------------------------------------------------------------------#
    # set some options
    #---------------------------------------------------------------------------#

    # Send configuration commands to controller (TBD)
    
    # Number of data sets to collect
    num_sets = int(params[0])
    print('@collect_data with num_sets = {}'.format(num_sets))

    casing_thickness = params[3]

    # Number of data points in a set
    num_pts_max = 110

    #---------------------------------------------------------------------------#
    # Pre-allocate some memory so that acquisition speed is not hindered
    # by memory allocation.
    #---------------------------------------------------------------------------#
    current_data_set_id = 0
    previous_data_set_id = 0

    # Use Numpy array's for data collection because they populate fast.
    datasetIds = np.zeros(num_sets*num_pts_max)
    datasetIds.fill(-1) # fill so we can eventually tell what rows were written.
    times = np.zeros(num_sets*num_pts_max)
    displacements = np.zeros(num_sets*num_pts_max)
    point_counts = np.zeros(num_sets*num_pts_max)
    intensities = np.zeros(num_sets*num_pts_max)

    columns = ['pt_count', 'dataset_id', 'timestamp', 'displacement', 'filtered', 'intensity']
    point_indices = list(range(num_sets*num_pts_max))
    sensor_df = pd.DataFrame(index=point_indices, columns=columns)
    sensor_df['displacement'] = sensor_df['displacement'].astype(float)
    sensor_df['intensity'] = sensor_df['intensity'].astype(float)
    sensor_df = sensor_df.fillna(0)

    #---------------------------------------------------------------------------#
    # Get the data! Keep this loop as tight as possible so that data sets are
    # not dropped.  Avoid any extra processing.
    #---------------------------------------------------------------------------#
    set_count = 0
    data_index = 0
    print('Starting collection loop...')
    sys.stdout.flush()
    await send_status_message(websocket, 'acquiring')
    
    while set_count < num_sets:
        data = sock.recv(4)
        # Look for 'DATA' preamble
        if data == b'\x44\x41\x54\x41':
            #print('Found DATA')
            data = sock.recv(4)
            order_number = int.from_bytes(data, byteorder='little')
            #print('Order number: ' + str(order_number))
            data = sock.recv(4)
            serial_number = int.from_bytes(data, byteorder='little')
            #print('Serial number: ' + str(serial_number))
            data = sock.recv(4)
            video_number = int.from_bytes(data, byteorder='little')
            #print('Video number: ' + str(video_number))
            data = sock.recv(4)
            measurement_number = int.from_bytes(data, byteorder='little')
            #print('Measurement number: ' + str(measurement_number))
            data = sock.recv(4)
            pt_count = int.from_bytes(data, byteorder='little')
            data = sock.recv(4)
            counter = int.from_bytes(data, byteorder='little')
            print('frames number: {}; counter: {}'.format(str(pt_count),str(counter)))
            for i in range(0,pt_count):
            #for i in range(0,100):
                data = sock.recv(4)
                data_tuple = struct.unpack('hh',data)
                intensity = (float(data_tuple[0] & 2047)/1024.0)*100.0
                max_peak = data_tuple[1] & 16383
                data = sock.recv(4)
                dval = int.from_bytes(data, byteorder='little')
                error_msg = ''
                disp = 0.0
                if dval > 2147483392:
                    error_msg = 'Error: '
                    if dval == 2147483396:
                        error_msg = error_msg + 'No Peak'
                    if dval == 2147483397:
                        error_msg = error_msg + 'Peak in front of MR'
                    if dval == 2147483398:
                        error_msg = error_msg + 'Peak in back of MR'
                    if dval == 2147483399:
                        error_msg = error_msg + 'Measurement cannot be calculated'
                    if dval == 2147483400:
                        error_msg = error_msg + 'Measurement is outside representable area'
                    disp = 15.0
                else:
                    disp = float(dval) * 1e-6
                data = sock.recv(4)
                tstamp = int.from_bytes(data, byteorder='little')
                displacements[data_index] = disp
                datasetIds[data_index] = current_data_set_id
                point_counts[data_index] = pt_count
                times[data_index] = tstamp
                intensities[data_index] = intensity
                data_index += 1

            current_data_set_id += 1
            set_count = set_count + 1

    # close so we can reconnect later
    sock.close()

    # Notify that acquisition is complete
    await send_status_message(websocket, 'processing')

    # Clean the data a bit. The sensor is not capable of measuring
    # greater than Nmm, so we clamp the data there.
    displacements = np.where(displacements > 25.0, 25.0, displacements)

    # remove any extraneous rows
    sensor_df['pt_count'] = point_counts
    sensor_df['dataset_id'] = datasetIds
    sensor_df['timestamp'] = times
    sensor_df['displacement'] = displacements
    sensor_df['intensity'] = intensities
    sensor_df['casing_thickness'] = casing_thickness
    sensor_df = sensor_df[sensor_df.dataset_id != -1]
    t0 = sensor_df['timestamp'].iloc[0]
    tf = sensor_df['timestamp'].iloc[-1]
    print('t0: ' + str(t0) + '; tf: ' + str(tf))
    t_total = (tf-t0)/10**6
    total_points = len(sensor_df.index)
    samp_freq = total_points/t_total
    print('Points collected: {}'.format(total_points))
    print('Elapsed Collection time: {}s'.format(t_total))
    print('Average samples/sec: {}'.format(samp_freq))

    return {'samp_freq':samp_freq, 'sensor_data':sensor_df}

def filter_data(params, data):
    print('@filter_data')
    if (True):
        print('  no filtering')
        data['sensor_data']['filtered'] = data['sensor_data']['displacement'] # No filtering
    else:
        print('  filtering')
        freq_cutoff = float(params[2])
        n_order = FILTER_ORDER
        samp_freq = data['samp_freq']
        print('n_order: {}; freq_cutoff: {}; fs: {}'.format(n_order, freq_cutoff, samp_freq))
        sos = signal.butter(n_order, freq_cutoff, 'lowpass', fs=samp_freq, output='sos')
        filtered = signal.sosfilt(sos, data['sensor_data']['displacement'])
        data['sensor_data']['filtered'] = filtered

def peak_find(params, data_frame):
    ''' find peaks in the data '''
    print('@peak_find')
    data = data_frame['displacement'].values
    top_peaks, props = signal.find_peaks(-data, prominence=2) # look for negative 'peaks'
    peaks_avg_out = THRESHOLD*(np.ones(len(data)))
    gaps = np.zeros(len(props['right_bases']))
    bottom_peaks = np.zeros(len(gaps))
    for i in range(len(props['left_bases'])-1):
        roi = data[props['left_bases'][i]+1:props['right_bases'][i]]
        roi[roi >= THRESHOLD] = np.nan
        mean = np.nanmean(roi)
        peaks_avg_out[props['left_bases'][i]+1:props['right_bases'][i]] = mean
        if math.isnan(mean):
            gaps[i] = 0
        else:
            gaps[i] = mean
        l_idx = props['left_bases'][i] + 1
        r_idx = props['right_bases'][i]
        bottom_peaks[i] = (l_idx + r_idx)/2.0

    bottom_peaks = bottom_peaks[0:len(bottom_peaks)-1]
    gaps = gaps[0:len(gaps)-1]
    print('peaks_avg_out: ', peaks_avg_out)
    print('gaps: ', gaps)

    return peaks_avg_out, bottom_peaks, gaps

def compute_clearance(peaks_avg_out, peak_locs, gaps, sensor_data, casing_thickness, spacer_thickness):
    global SCAN_META_DATA
    global SMR
    global SENSOR_LENGTH
    print('@compute_clearance')
    print('len(peaks_avg_out): ', len(peaks_avg_out))
    print('peak_locs: ', len(peak_locs))
    print('gaps: ', gaps)

    #ALL CALCULATIONS ARE DONE IN METRIC UNITS - I.E. MILLIMETERS.

    # check for no gaps found
    if (len(gaps) == 0):
        print("gaps() has zero length")
        return -9.997 # Defined value for 'cannot compute'

    # check for all nan values
    nan_count = 0
    for i in range(len(gaps)-1):
        if math.isnan(gaps[i]):
            nan_count += 1
    if (nan_count == len(gaps)):
        print("gaps() contains all nan entries")
        return -9.998

    avg_displacement = 0.0
    for i in range(len(gaps)-1):
        if math.isnan(gaps[i]) == True:
            avg_displacement = avg_displacement + 0.0
        else:
            avg_displacement = avg_displacement + gaps[i]

    divisor = len(gaps) - nan_count
    avg_displacement = avg_displacement / divisor

    print('  avg_displacement: {} ({} inches) '.format(avg_displacement, avg_displacement/25.4))
    if math.isnan(avg_displacement) == True:
        print("avg_displacement computed to nan.")
        return -9.999

    if SCAN_META_DATA['units'] == 'In':
        casing_thickness = casing_thickness * 25.4
        spacer_thickness = spacer_thickness * 25.4

    clearance = avg_displacement - SMR - SENSOR_LENGTH + spacer_thickness + casing_thickness

    print('MM: SMR: {}; SL: {}; Spacer: {}; Casing: {}; Clearance: {}'.format(SMR, SENSOR_LENGTH, spacer_thickness, casing_thickness, clearance))

    if SCAN_META_DATA['units'] == 'In':
        clearance = clearance/25.4
        print('In: SMR: {}; SL: {}; Spacer: {}; Casing: {}; Clearance: {}'.format(SMR/25.4, SENSOR_LENGTH/25.4, spacer_thickness/25.4, casing_thickness/25.4, clearance))

    return clearance

def find_patterns(params, data_frame):

    acor = np.zeros(len(data_frame['sensor_data']['displacement']))

    with open('pattern_data.csv', mode='w') as csv_file:
        writer = csv.writer(csv_file, delimiter=',', quotechar='"', quoting=csv.QUOTE_MINIMAL, lineterminator='\n')
        for i in range(0,len(ft_mag)):
            writer.writerow([i,ft_mag[i]])

def save_data(params, data, peak_locs, gaps, *args, **kwargs):
    print('@save_data: len(kwargs): ', len(kwargs))    
    global LAST_SAVED_FILE
    global DB_CONN
    now = datetime.now(timezone.utc)
    unix_timestamp = int(now.timestamp())
    time_stamp = now.strftime("%Y-%m-%d_%H-%M-%S")
    frame = ""
    sn = ""
    stage = ""
    position = ""
    casing_thickness = ""
    spacer_thickness = ""
    if len(kwargs) > 0:
        frame = kwargs.get('frame',None)
        sn = kwargs.get('sn',None)
        stage = kwargs.get('stage',None)
        position = kwargs.get('position',None)
        casing_thickness = kwargs.get('casing_thickness',None)
        spacer_thickness = kwargs.get('spacer_thickness',None)
    if len(params) > 1:
        if params[1] != 'false':
            is_json = params[1].find('.json', 0, len(params[1]))
            if is_json >= 0:
                print('Saving data as json')
                save_file = "~/data/e4pt_" + time_stamp + ".json"
                LAST_SAVED_FILE = save_file
                #JSON output
                print('Saving raw data to JSON file: {}'.format(save_file))
                data_dict = {'data':data['filtered'].tolist(),
                             'locs':peak_locs.tolist(),
                             'gaps':gaps.tolist(),
                             'frame':frame,
                             'sn':sn,
                             'stage':stage,
                             'position':position,
                             'casing_thickness':casing_thickness,
                             'spacer_thickness':spacer_thickness
                             }
                with open(save_file, 'w') as out_file:
                    json.dump(data_dict, out_file)
            is_csv = params[1].find('.csv', 0, len(params[1]))
            if is_csv >= 0:
                print('Saving data as csv')
                meta_data = ""
                if len(frame) > 0:
                    meta_data = frame + "_" + sn + "_" + stage + "_" + position + "_"
                save_file1 = "~/data/e4pt_" + meta_data + time_stamp + ".csv"
                save_file2 = "/var/www/html/e4pt/data/e4pt_" + meta_data + time_stamp + ".csv"
                LAST_SAVED_FILE = "./data/e4pt_" + meta_data + time_stamp + ".csv"
                if SIMULATOR == True:
                    save_file2 = "../app/www/data/e4pt_" + meta_data + time_stamp + ".csv"
                    LAST_SAVED_FILE = save_file2
                #CSV output
                print('Saving raw data to CSV file: {}'.format(LAST_SAVED_FILE))
                data.to_csv(save_file2, sep=',', index_label='index')
                if len(frame) > 0:
                    if DB_CONN != None:
                        save_dataframe_to_db(DB_CONN, unix_timestamp, time_stamp, frame, sn, stage, position, save_file2, data)

def create_or_open_db(db_file):
    print('Creating or opening', db_file)
    db_is_new = not os.path.exists(db_file)
    conn = sqlite3.connect(db_file)
    if db_is_new:
        print ('Creating schema')
        sql = '''create table if not exists SENSOR_DATA(
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        UNIXTIME INT,
        TIMESTAMP TEXT,
        CUSTOMER TEXT,
        SITE TEXT,
        OPERATOR TEXT,
        UNITS TEXT,
        SERIAL_NUM TEXT,
        FRAME,
        STAGE TEXT,
        POSITION TEXT,
        FILE_NAME TEXT,
        DATA BLOB
        );'''
        conn.execute(sql) # shortcut for conn.cursor().execute(sql)
    else:
        print('Schema exists\n')
    return conn

def save_dataframe_to_db(conn, unixtime, timestamp, ser_num, frame, stage, pos, f_name, dataframe):
    # convert dataframe to python pickle object
    pickled_df = pickle.dumps(dataframe)
    sql = '''INSERT INTO SENSOR_DATA
        (UNIXTIME, TIMESTAMP, CUSTOMER, SITE, OPERATOR, UNITS, FRAME, SERIAL_NUM, STAGE, POSITION, FILE_NAME, DATA)
        VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);'''
    conn.execute(sql, [unixtime, timestamp, SCAN_META_DATA['customer'], SCAN_META_DATA['site'], \
                       SCAN_META_DATA['operator'], SCAN_META_DATA['units'], SCAN_META_DATA['frame'], \
                       SCAN_META_DATA['serial_number'], stage, pos, f_name, sqlite3.Binary(pickled_df)]) 
    conn.commit()

def get_data_from_db_with_sn(conn, ser_num):
    sql = "SELECT * FROM SENSOR_DATA WHERE SERIAL_NUM = \"" + ser_num + "\""
    print('Sending SQL command to retrieve data:')
    print('  ',sql)
    cur = conn.cursor()
    cur.execute(sql) 
    rows = cur.fetchall()
    print('Retrieved ', len(rows), ' row(s) from database.')
    frames = []
    for row in rows:
        df = pickle.loads(row[1])
        frames.append(df)
    if len(frames) > 0:
        return frames
    else:
        return []

# set_measuring_rate(mr) sets the measurement rate of the sensor. The argument,
# mr, is specified in kHz.
async def set_measuring_rate(mr):
    global MEASUREMENT_RATE
    if SIMULATOR == False:
        tn_host = (SENSOR_HOST)
        tn = telnetlib.Telnet(tn_host)
        tn.read_until(bytearray('->','utf-8'))
        send_cmd('MEASRATE',mr)
        MEASUREMENT_RATE = mr
    else:
        print("This is where the measurement rate would be set to ", mr)

def check_port(ip,port):
    print("@check_port")
    attempts = 24
    connected = False
    s = []
    while attempts > 0:
        print("Attempting to connect to server/port...")        
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            s.connect((ip, int(port)))
            connected = True
            attempts = 0
        except:
            err_info = sys.exc_info()
            print('Error:\n', err_info)
            print('Error type: ', type(err_info))
            attempts -= 1;
            time.sleep(5)

    if connected:
        s.shutdown(socket.SHUT_RDWR)
        s.close()
        s = None
        print("Port is reachable.")
        return True
    else:
        return False

def send_cmd(cmd,conn):
    cmd = cmd + "\n"
    status = True
    try:
        conn.write(bytearray(cmd, 'utf-8'))
    except ConnectionResetError:
        status = True
    except:
        err_info = sys.exc_info()
        print('Error:\n', err_info)
        status = False
    try:
        conn.read_until(bytearray('->','utf-8'))
    except ConnectionResetError:
        status = True
    except:
        err_info = sys.exc_info()
        print('Error:\n', err_info)
        status = False
    return status

if __name__ == "__main__":

    #global DB_CONN # Database connection
    db_file = ""
    if SIMULATOR == False:
        # Check for sensor connectivity on port 1024 (the measurement port).
        # Checking on port 23 (Telnet port) fouls up the telnet connectivity.
        sensor_reachable = check_port(SENSOR_HOST, 1024)
        if not sensor_reachable:
            print("Connection to sensor ultimately failed.")
            exit()

        #Telnet to the device and make sure its output is set correctly.
        #Any other parameters can be set this way too.
        status = True
        tn_host = (SENSOR_HOST)
        tn = telnetlib.Telnet(tn_host)
        tn.read_until(bytearray('->','utf-8'))
        send_cmd('ETHERMODE ETHERNET',tn)
        send_cmd('OUTPUT ETHERNET',tn)
        send_cmd('MEASTRANSFER SERVER/TCP 1024',tn)
        send_cmd('OUT_ETH 01INTENSITY 01DIST1 TIMESTAMP',tn)
        send_cmd('MEASRATE', 1000)
        tn.close()
        db_file = "~/data/e4pt.s3db"
    else:
        db_file = "e4pt.s3db"

    #DB_CONN = create_or_open_db(db_file)
    
    PARAMS[0] = 100; # Number of sets of data. Assume 100 pts/set for now.
    time_stamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    save_file = ".csv"
    print("Output file will be: {}".format(save_file))
    PARAMS[1] = save_file; # Save data or not ('false' or a file name)
    PARAMS[2] = 10; #Digital filter cutoff freqency. Set to 10 for now.
    PARAMS[3] = 0; #Casing thickness - this will get filled in later

    # need to wait until we're sure Apache is up and running...
    sess = requests.Session()
    apache_wait = False
    while apache_wait:
        try:
            print('Checking for Apache...')
            address = 'http://localhost/index.html'
            req = sess.get(address)
            if 'server' in req.headers:
                if "Apache" in req.headers['server']:
                    #Apache is running
                    print('Found Apache!')
                    sess.close()
                    apache_wait = False
            else:
                print("(else) Waiting for Apache...")
                time.sleep(1)
        except:
            print("(except) Waiting for Apache...")
            time.sleep(1)

    print('Connecting web socket...')
    start_server = websockets.serve(ws_msg_handler, SENSOR_WEBSOCKET, WEBSOCKET_PORT)

    asyncio.get_event_loop().run_until_complete(start_server)
    asyncio.get_event_loop().run_forever()
    
