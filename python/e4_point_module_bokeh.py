''' Script to collect data from MTI sensor over ModBus. '''
import sys
#import datetime
import numpy as np
import pandas as pd
import json
from bokeh.server.server import Server
from bokeh.application import Application
from bokeh.application.handlers.function import FunctionHandler
from bokeh.io import show, output_file
from bokeh.plotting import figure, ColumnDataSource, curdoc
#from bokeh.models import Div, CustomJS, Slider
from bokeh.layouts import column
from bokeh.models import HoverTool
#import bokeh.models.widgets.panels as bkmwp
from pymodbus.client.sync import ModbusTcpClient as ModbusClient
from scipy import signal

DATA = ColumnDataSource({'index':[], 'pt_count':[], 'dataset_id':[], 'displacement':[], 'filtered':[]})
ARGS = sys.argv[1:]
THRESHOLD = 3.99
FILTER_ORDER = 1

def update():
    print('@update')
    new_df = collect_data(ARGS)
    new_data = {'index':new_df.index.values, 'displacement':new_df['displacement']}
    ''' Update the HTML document '''
    DATA.stream(new_data)

def make_document(data, peak_locs, gaps):
    ''' Create the HTML document '''
    print('@make_document')

    #curdoc().add_periodic_callback(update, 8000)
    tools_to_show = 'hover, box_zoom, pan, save, reset, wheel_zoom'

    # Plot displacement
    disp_fig = figure(title='Capacitance Sensor Displacement', \
                 width=500, height=500, tools=tools_to_show)
    disp_fig.xaxis.axis_label = 'Index'
    disp_fig.yaxis.axis_label = 'Displacement (mm)'
    disp_fig.line('index', 'displacement', source=data, line_width=3, \
                  line_alpha=0.6, line_color='blue')
    hover1 = disp_fig.select(dict(type=HoverTool))
    hover1.tooltips = [('Index', '@index'),('Displacement', '@displacement')]
    hover1.mode = 'mouse'
    

    # Plot point counts
    pt_count_fig = figure(title='Set Point Count', \
                          width=500, height=500, \
                          x_range=disp_fig.x_range, tools=tools_to_show)
    pt_count_fig.xaxis.axis_label = 'Index'
    pt_count_fig.yaxis.axis_label = 'Point Count/Dataset'
    pt_count_fig.line('index', 'pt_count', source=data, line_width=3, \
                      line_alpha=0.6, line_color='red')
    hover2 = pt_count_fig.select(dict(type=HoverTool))
    hover2.tooltips = [('Index', '@index'),('Point Count', '@pt_count')]
    hover2.mode = 'mouse'

    # Plot dataset ids
    dataset_id_fig = figure(title='Dataset IDs', \
                            width=500, height=500, \
                            x_range=disp_fig.x_range, tools=tools_to_show)
    dataset_id_fig.xaxis.axis_label = 'Index'
    dataset_id_fig.yaxis.axis_label = 'Dataset ID'
    dataset_id_fig.line('index', 'dataset_id', source=data, line_width=3, \
                        line_alpha=0.6, line_color='green')
    hover3 = dataset_id_fig.select(dict(type=HoverTool))
    hover3.tooltips = [('Index', '@index'),('Dataset ID', '@dataset_id')]
    hover3.mode = 'mouse'

    # Plot filtered data
    source2 = ColumnDataSource(data=dict(locs=peak_locs, gaps=gaps))    
    filtered_fig = figure(title='Filtered Displacement', \
                          width=500, height=500, \
                          x_range=disp_fig.x_range, \
                          y_range=disp_fig.y_range, \
                          tools=tools_to_show)
    filtered_fig.xaxis.axis_label = 'Index'
    filtered_fig.yaxis.axis_label = 'Filtered Displacement'
    filtered_fig.line('index', 'filtered', source=data, line_width=3, \
                         line_alpha=0.6, line_color='red')
    filtered_fig.circle('locs', 'gaps', source=source2, size=10, fill_alpha=0.6)    
    hover4 = filtered_fig.select(dict(type=HoverTool))
    hover4.tooltips = [('Index', '@index'),('Fitlered', '@filtered')]
    hover4.mode = 'mouse'
    
    #curdoc().title = 'e4-Pt Data'
    #curdoc().add_root(disp_fig)

    layout = column(disp_fig,
                    filtered_fig,
                    pt_count_fig,
                    dataset_id_fig)

    output_file('e4Pt.html', title='MTI Sensor Data')
    show(layout)

def collect_data(args):
    '''This is the main function for acquiring data over ModBus'''
    #---------------------------------------------------------------------------#
    # choose the client
    #---------------------------------------------------------------------------#
    #client = ModbusClient('192.168.7.75', port=502)
    client = ModbusClient('192.168.168.247', port=502)
    client.connect()

    #---------------------------------------------------------------------------#
    # set some options
    #---------------------------------------------------------------------------#

    # Number of data sets to collect
    num_sets = int(args[0])
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

def filter_data(args, data):
    print('@filter_data')
    freq_cutoff = float(args[3])
    n_order = FILTER_ORDER
    samp_freq = data['samp_freq']
    print('n_order: {}; freq_cutoff: {}; fs: {}'.format(n_order, freq_cutoff, samp_freq))
    sos = signal.butter(n_order, freq_cutoff, 'lowpass', fs=samp_freq, output='sos')
    filtered = signal.sosfilt(sos, data['sensor_data']['displacement'])
    data['sensor_data']['filtered'] = filtered

def peak_find(args, data_frame):
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

def save_data(args, data, peak_locs, gaps):
    print('@save_data')    
    if len(args) > 2:
        if args[2] != 'false':
            is_json = args[2].find('.json', 0, len(args[2]))
            if is_json >= 0:
                #JSON output
                print('Saving raw data to JSON file: {}'.format(args[2]))
                data_dict = {'data':data['filtered'].tolist(),
                             'locs':peak_locs.tolist(),
                             'gaps':gaps.tolist()}
                with open(args[2], 'w') as out_file:
                    json.dump(data_dict, out_file)
            is_csv = args[2].find('.csv', 0, len(args[2]))
            if is_csv >= 0:
                #CSV output
                print('Saving raw data to CSV file: {}'.format(args[2]))
                data.to_csv(args[2], sep=',')    

if __name__ == "__main__":
    ARGS = sys.argv[1:]
    if len(ARGS) == 0:
        print('Usage: e4_point_module_bokeh num_data_sets produce_plots [csv_filename] [filter_freq]')
        print('    num_data_sets: Number of data sets to collect')
        print('    produce_plots: Produce HTML output of plots')
        print('    output_file: Filename to which to save data file.')
        print('             \'[fname].csv\' creates csv output')
        print('             \'[fname].json\' create json output')
        print('             \'false\' causes no output')
        print('    filter_freq: Cutoff filter for data LPF.')
        exit()

    collection_data = collect_data(ARGS)

    if len(ARGS) > 3:
        # Apply LPF
        filter_data(ARGS, collection_data)

    sensor_data = collection_data['sensor_data']

    peaks_avg_out, peak_locs, gaps = peak_find(ARGS, sensor_data)

    save_data(ARGS, sensor_data, peak_locs, gaps)

    DATA = ColumnDataSource(data=dict(index = sensor_data.index.values, \
                                      pt_count=sensor_data['pt_count'], \
                                      dataset_id=sensor_data['dataset_id'], \
                                      timestamp=sensor_data['timestamp'], \
                                      displacement=sensor_data['displacement'], \
                                      filtered=sensor_data['filtered'], \
                                      peaks_data=peaks_avg_out))


    if ARGS[1] == 'true':
        make_document(DATA, peak_locs, gaps)
