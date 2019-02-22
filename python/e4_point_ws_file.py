''' Script to collect data from MTI sensor over ModBus. '''
import sys
import asyncio
import websockets
import json
#import datetime
import numpy as np
import pandas as pd
from pymodbus.client.sync import ModbusTcpClient as ModbusClient
from scipy import signal

ARGS = sys.argv[1:]
THRESHOLD = 3.99
FILTER_ORDER = 1

async def ws_server(websocket, path):
    rx_msg = await websocket.recv()
    print("rx_msg: {}".format(rx_msg))
    msg = json.loads(rx_msg)
    if msg['text'] == 'send_data':
        raw_data = read_data(ARGS[0])
        data_dict = {'type':'data',
                     'data':raw_data['data'],
                     'locs':raw_data['locs'],
                     'gaps':raw_data['gaps']}
        json_data = json.dumps(data_dict)
        await websocket.send(json_data)

def read_data(file_name):
  print('@read_data({}):'.format(file_name))
  with open(file_name) as f:
    data = json.load(f)
  return data

if __name__ == "__main__":
    ARGS = sys.argv[1:]
    if len(ARGS) == 0:
        print('Usage: e4_point_ws_file file_name')
        print('    file_name: JSON file with compatible data to load and send')
        exit()

    #start_server = websockets.serve(ws_server, '192.168.7.77', 3405)
    start_server = websockets.serve(ws_server, '127.0.0.1', 3405)

    asyncio.get_event_loop().run_until_complete(start_server)
    asyncio.get_event_loop().run_forever()
