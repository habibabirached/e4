''' Script to collect data from MTI sensor over ModBus. '''
import sys
import numpy as np
import datetime
import pandas as pd
from bokeh.io import show, output_file
from bokeh.plotting import figure, ColumnDataSource
from bokeh.models import Div, CustomJS, Slider
from bokeh.layouts import gridplot, column, widgetbox
from bokeh.models import Range1d
import bokeh.models.widgets.panels as bkmwp

#---------------------------------------------------------------------------#
# import the various server implementations
#---------------------------------------------------------------------------#
from pymodbus.client.sync import ModbusTcpClient as ModbusClient


def main(args):
    '''This is the main function for acquiring data over ModBus'''
    #---------------------------------------------------------------------------#
    # choose the client
    #---------------------------------------------------------------------------#
    client = ModbusClient('192.168.7.75', port=502)
    client.connect()

    #---------------------------------------------------------------------------#
    # set some options
    #---------------------------------------------------------------------------#

    # Number of data sets to collect
    num_sets = int(args[0])
    # Maximum number of data points possible in a set
    num_pts_max = 48
    # Plotting?
    plotting = True
    # Debug output?
    debug = False
    # Output to file or screen?
    output_dev = 'screen'

    #---------------------------------------------------------------------------#
    # Pre-allocate the data frame so that acquisition speed is not hindered
    # by memory allocation.
    #---------------------------------------------------------------------------#
    current_data_set_id = 0
    previous_data_set_id = 0
    columns = ['dataset_id', 'timestamp', 'displacement']
    point_indices = list(range(num_sets*num_pts_max))
    sensor_df = pd.DataFrame(index=point_indices, columns=columns)
    sensor_df['displacement'] = sensor_df['displacement'].astype(float)
    sensor_df = sensor_df.fillna(0)

    #---------------------------------------------------------------------------#
    # Get the data! Keep this loop as tight as possible so that data sets are
    # not dropped.  Avoid any extra processing.
    #---------------------------------------------------------------------------#
    count = 0
    data_index = 0
    offset = 7
    while count < num_sets:
        read_reg = client.read_holding_registers(64, 103)
        current_data_set_id = read_reg.registers[0] + (read_reg.registers[1] << 16)
        if count > 0:
            # Catch duplicates and don't save them.
            if current_data_set_id == previous_data_set_id:
                continue

        previous_data_set_id = current_data_set_id
        pt_count = read_reg.registers[2]
        for data_set in range(pt_count):
            displacement = read_reg.registers[data_set*2 + offset] + \
                           (read_reg.registers[(data_set*2)+1+offset] << 16)

            time_point = read_reg.registers[3] + \
                         (read_reg.registers[4] << 16) +\
                         (read_reg.registers[5] << 32) + \
                         (read_reg.registers[6] << 48)

            sensor_df.loc[data_index] = pd.Series({'dataset_id':current_data_set_id, \
                                                  'timestamp':time_point, \
                                                  'displacement':float(displacement / 10**9)})

            data_index += 1

        count = count + 1

    # remove any extraneous rows
    sensor_df = sensor_df[sensor_df.dataset_id != 0]

    #---------------------------------------------------------------------------#
    # Output the data
    #---------------------------------------------------------------------------#
    print('sensor_df: {}'.format(sensor_df))
    sensor_df.to_csv('sixPtData.csv', sep=',', index_label='index')
    print('Points collected: {}'.format(str(data_index)))
    print('Done.')

if __name__ == "__main__":
    main(sys.argv[1:])
