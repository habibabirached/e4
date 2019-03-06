''' Script to collect data from MTI sensor over ModBus. '''
import sys
import asyncio
import time
import json
from datetime import datetime
import websockets
import requests
#import datetime
import numpy as np
import pandas as pd
from pymodbus.client.sync import ModbusTcpClient as ModbusClient
from scipy import signal

PARAMS = ["", "", ""]
THRESHOLD = 3.99
FILTER_ORDER = 1
LAST_SAVED_FILE = ""

def is_number(num):
    ''' True or false depending on if the argument can be interpreted as a number.'''
    try:
        float(num)
        return True
    except ValueError:
        return False

async def ws_msg_handler(websocket, path):
    ''' Handles messages from the websocket. '''
    while True:
        rx_msg = await websocket.recv()
        print("rx_msg: {}".format(rx_msg))
        msg = json.loads(rx_msg)
        print("WS: Message received: {}".format(msg))
        msg_text = msg["text"]

        #parse the message
        msg_args = [x.strip() for x in msg_text.split(',')]
        num_secs = 0
        if len(msg_args) > 1:
            print("msg_args: {}".format(msg_args))
            if is_number(msg_args[1]):
                num_secs = msg_args[1]
                num_frames = (20000.0 * float(num_secs))/16.0
                PARAMS[0] = int(num_frames)
            else:
                # We didn't get an acquisition time, so bail out.
                return

        if msg_args[0] == 'ping':
            print("Websocket: Got ping, sending pong.")
            data_dict = {'type':'pong'}
            json_data = json.dumps(data_dict)
            await websocket.send(json_data)

        if msg_args[0] == 'send_data':
            print("Data requested for {} seconds ({} dataframes).".format(num_secs, PARAMS[0]))
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
            print("Got shutdown message over websocket.")
            system_shutdown()

        if msg_args[0] == 'get_data_file':
            global LAST_SAVED_FILE
            print("Got filename request. File is {}".format(LAST_SAVED_FILE))
            data_dict = {'type':'filename',
                         'fname':LAST_SAVED_FILE}
            json_data = json.dumps(data_dict)
            await websocket.send(json_data)

def system_shutdown():
    ''' Shuts down the computer. '''
    if sys.platform == 'win32':
        print("If this were Linux, the machine would be shutting down now.")
        return
    else:
        print("Linux system detected. Attempting to shut down now.")
        import os
        print("Shutting down now.")
        #os.system('systemctl poweroff')
        os.system('sudo shutdown now')
        # end of the line

async def send_status_message(websocket, status_msg):
    ''' Sends status messages over the websocket. '''
    # Send status message
    print("Sending status message: {}".format(status_msg))
    data_dict = {'type':'status', 'status':status_msg}
    json_data = json.dumps(data_dict)
    await websocket.send(json_data)

async def collect_data(params, websocket):
    '''This is the main function for acquiring data over ModBus'''
    #---------------------------------------------------------------------------#
    # choose the client
    #---------------------------------------------------------------------------#
    #client = ModbusClient('192.168.7.75', port=502) # Laptop testing
    client = ModbusClient('192.168.168.247', port=502)  # E4PT System testing
    client.connect()

    #---------------------------------------------------------------------------#
    # set some options
    #---------------------------------------------------------------------------#

    # Number of data sets to collect
    num_sets = int(params[0])
    print('@collect_data with num_sets = {}'.format(num_sets))
    # Maximum number of data points possible in a set
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
    print('Starting collection loop...')
    sys.stdout.flush()
    await send_status_message(websocket, 'acquiring')
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
            displacements[data_index] = float(disp / 10**7)
            times[data_index] = read_reg.registers[3] + \
                                (read_reg.registers[4] << 16) +\
                                (read_reg.registers[5] << 32) + \
                                (read_reg.registers[6] << 48)
            datasetIds[data_index] = current_data_set_id
            point_counts[data_index] = pt_count
            data_index += 1
        set_count = set_count + 1

    # close so we can reconnect later
    client.close()

    # Clean the data a bit. The sensor is not capable of measuring
    # greater than 4mm, so we clamp the data there.
    displacements = np.where(displacements > 4.0, 4.0, displacements)

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

    return {'samp_freq':samp_freq, 'sensor_data':sensor_df}

def filter_data(params, data):
    ''' Apply a LPF to the data. '''
    print('@filter_data')
    freq_cutoff = float(params[2])
    n_order = FILTER_ORDER
    samp_freq = data['samp_freq']
    print('n_order: {}; freq_cutoff: {}; fs: {}'.format(n_order, freq_cutoff, samp_freq))
    sos = signal.butter(n_order, freq_cutoff, 'lowpass', fs=samp_freq, output='sos')
    filtered = signal.sosfilt(sos, data['sensor_data']['displacement'])
    data['sensor_data']['filtered'] = filtered

def peak_find(params, data_frame):
    ''' Find peaks in the data '''
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
    ''' Save the data to a CSV or JSON file.'''
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
                #save_file1 = "~/data/e4pt_" + time_stamp + ".csv"
                save_file2 = "/var/www/html/e4pt/data/e4pt_" + time_stamp + ".csv"
                LAST_SAVED_FILE = "./data/e4pt_" + time_stamp + ".csv"
                #CSV output
                #print('Saving raw data to CSV file: {}'.format(save_file1))
                #data.to_csv(save_file1, sep=',')
                print('Saving raw data to CSV file: {}'.format(LAST_SAVED_FILE))
                data.to_csv(save_file2, sep=',')

if __name__ == "__main__":

    #PARAMS = sys.argv[1:]
    PARAMS[0] = 25000 # Number of sets of data. Assume 16 pts/set for now.
    time_stamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    save_file = ".csv"
    print("Output file will be: {}".format(save_file))
    PARAMS[1] = save_file # Save data or not ('false' or a file name)
    PARAMS[2] = 10 #Digital filter cutoff freqency. Set to 10 for now.

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
    #start_server = websockets.serve(ws_msg_handler, '192.168.7.77', 3405)
    start_server = websockets.serve(ws_msg_handler, '192.168.168.41', 3405)
    #start_server = websockets.serve(ws_msg_handler, 'localhost', 3405)

    asyncio.get_event_loop().run_until_complete(start_server)
    asyncio.get_event_loop().run_forever()
