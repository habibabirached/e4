''' Script to collect data from MTI sensor over ModBus. '''
import sys
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
from datetime import datetime
from asgiref.sync import async_to_sync
import telnetlib
import struct

PARAMS = ["","",""]
THRESHOLD = 3.99
FILTER_ORDER = 1
LAST_SAVED_FILE = ""
SENSOR_HOST = "192.168.168.150"

def is_number(s):
    try:
        float(s)
        return True
    except ValueError:
        return False

async def ws_msg_handler(websocket, path):
    while True:
        rx_msg = await websocket.recv()
        print("rx_msg: {}".format(rx_msg))
        msg = json.loads(rx_msg)
        print("WS: Message received: {}".format(msg))
        msg_text = msg["text"]

        #parse the message
        msg_args = [x.strip() for x in msg_text.split(',')]
        nSecs = 0
        if (len(msg_args) > 1):
            print("msg_args: {}".format(msg_args))
            if is_number(msg_args[1]):
                nSecs = msg_args[1]
                nFrames = (1000.0 * float(nSecs))/100.0 # 1K samp/sec; 100 samp/frame
                PARAMS[0] = int(nFrames)
            else:
                # We didn't get an acquisition time, so bail out.
                return

        if msg_args[0] == 'ping':
            print("Websocket: Got ping, sending pong.")
            data_dict = {'type':'pong'}
            json_data = json.dumps(data_dict)
            await websocket.send(json_data)

        if msg_args[0] == 'send_data':
            print("Data requested for {} seconds ({} dataframes).".format(nSecs,PARAMS[0]))
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

        if msg_args[0] == 'shutdown':
            print("Got shutdown message over websocket.");
            system_shutdown()

        if msg_args[0] == 'get_data_file':
            global LAST_SAVED_FILE
            print("Got filename request. File is {}".format(LAST_SAVED_FILE));
            data_dict = {'type':'filename',
                         'fname':LAST_SAVED_FILE}
            json_data = json.dumps(data_dict)
            await websocket.send(json_data)

        if msg_args[0] == 'do_dark_reference':
            await dark_reference(websocket)

        if msg_args[0] == 'do_mastering':
            await do_mastering(websocket)

async def dark_reference(websocket):
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
    nFrames = (1000.0 * float(nSecs))/100.0 # 1K samp/sec; 100 samp/frame
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
    server_address = ("192.168.168.150", 1024)
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
            print('frames number: ' + str(pt_count))
            data = sock.recv(4)
            counter = int.from_bytes(data, byteorder='little')
            print('counter: ' + str(counter))
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
    sensor_df = sensor_df[sensor_df.dataset_id != 0]
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
    if (False):
        data['sensor_data']['filtered'] = data['sensor_data']['displacement']
    else:
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
    top_peaks, props = signal.find_peaks(data, plateau_size=5000)
    peaks_avg_out = THRESHOLD*(np.ones(len(data)))
    gaps = np.zeros(len(props['right_edges']))
    bottom_peaks = np.zeros(len(gaps))
    for i in range(len(props['left_edges'])-1):
        roi = data[props['right_edges'][i]:props['left_edges'][i+1]]
        roi[roi >= THRESHOLD] = np.nan
        mean = np.nanmean(roi)
        peaks_avg_out[props['right_edges'][i]:props['left_edges'][i+1]] = mean
        gaps[i] = mean
        bottom_peaks[i] = (props['left_edges'][i+1] + props['right_edges'][i])/2.0

    bottom_peaks = bottom_peaks[0:len(bottom_peaks)-1]
    gaps = gaps[0:len(gaps)-1]
    return peaks_avg_out, bottom_peaks, gaps

def save_data(params, data, peak_locs, gaps):
    print('@save_data')
    global LAST_SAVED_FILE
    time_stamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
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
                             'gaps':gaps.tolist()}
                with open(save_file, 'w') as out_file:
                    json.dump(data_dict, out_file)
            is_csv = params[1].find('.csv', 0, len(params[1]))
            if is_csv >= 0:
                print('Saving data as csv')
                save_file1 = "~/data/e4pt_" + time_stamp + ".csv"
                save_file2 = "/var/www/html/e4pt/data/e4pt_" + time_stamp + ".csv"
                LAST_SAVED_FILE = "./data/e4pt_" + time_stamp + ".csv"
                #CSV output
                print('Saving raw data to CSV file: {}'.format(LAST_SAVED_FILE))                
                data.to_csv(save_file2, sep=',')

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
    tn.close()
    
    PARAMS[0] = 100; # Number of sets of data. Assume 100 pts/set for now.
    time_stamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    save_file = ".csv"
    print("Output file will be: {}".format(save_file))
    PARAMS[1] = save_file; # Save data or not ('false' or a file name)
    PARAMS[2] = 10; #Digital filter cutoff freqency. Set to 10 for now.

    # need to wait until we're sure Apache is up and running...
    sess = requests.Session()
    apache_wait = True
    while apache_wait:
        try:
            print('Checking for Apache...')
            req = sess.get('http://localhost/index.html')
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
    start_server = websockets.serve(ws_msg_handler, '192.168.168.41', 3405)

    asyncio.get_event_loop().run_until_complete(start_server)
    asyncio.get_event_loop().run_forever()
    
