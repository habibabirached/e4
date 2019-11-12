''' script to quickyly analyze e4Pt tool data in a csv file '''
import sys
import numpy as np
import pandas as pd
from bokeh.server.server import Server
from bokeh.application import Application
from bokeh.application.handlers.function import FunctionHandler
from bokeh.io import show, output_file
from bokeh.plotting import figure, ColumnDataSource, curdoc
from bokeh.layouts import column
from bokeh.models import HoverTool
from scipy import signal
from scipy import fftpack

DATA = ColumnDataSource({'index':[], 'pt_count':[], 'dataset_id':[], 'displacement':[], 'filtered':[]})
PLOT_H = 500
PLOT_W = 1000

def make_document(data, peaks, peak_params, args):
    ''' Create the HTML document '''
    print('@make_document')

    #curdoc().add_periodic_callback(update, 8000)
    tools_to_show = 'hover, box_zoom, pan, save, reset, wheel_zoom'

    # Plot displacement
    disp_fig = figure(title='Chromatic Confocal Sensor - Measured Displacement', \
                 width=PLOT_W, height=PLOT_H, tools=tools_to_show, active_drag='box_zoom')
    disp_fig.xaxis.axis_label = 'Index'
    disp_fig.yaxis.axis_label = 'Displacement (mm)'
    disp_fig.line('index', 'filtered', source=data, line_width=3, \
                  line_alpha=0.6, line_color='blue')
    hover1 = disp_fig.select(dict(type=HoverTool))
    hover1.tooltips = [('Index', '@index'),('Displacement', '@filtered')]
    hover1.mode = 'mouse'
    plot_peaks(disp_fig, data, peaks, peak_params)

    # Plot intensity data
    intensity_fig = figure(title='Signal Intensity', \
                          width=PLOT_W, height=PLOT_H, \
                          x_range=disp_fig.x_range, \
                          tools=tools_to_show, active_drag='box_zoom')
    intensity_fig.xaxis.axis_label = 'Index'
    intensity_fig.yaxis.axis_label = 'Intensity Signal'
    intensity_fig.line('index', 'intensity', source=data, line_width=3, \
                         line_alpha=0.6, line_color='red')
    hover5 = intensity_fig.select(dict(type=HoverTool))
    hover5.tooltips = [('Index', '@index'),('Intensity', '@intensity')]
    hover5.mode = 'mouse'
    
    layout = column(disp_fig,
                    intensity_fig)    

    csv_file = args[0]
    outfile_name = csv_file.replace(".csv",".html")
    output_file(outfile_name, title='Optical Sensor Data')
    show(layout)

def plot_peaks(fig, data, peaks, peak_params):
    # Plot the peaks
    for p in peaks:
        fig.circle(p,data.data['filtered'][p], size=7, color='red', alpha=0.5)
    # Compute and plot the peak 'average' line.
    peak_maxs = []
    peak_mins = []    
    peak_avgs = []
    peak_stds = []
    peak_counts = []
    print('peak_location, peak_npts, peak_min, peak_max, peak_avg, peak_stdev')    
    for i in range(0,len(peak_params['left_bases'])):
        lh = peak_params['left_bases'][i]
        rh = peak_params['right_bases'][i]
        peak_npts = rh - lh + 1
        peak_counts.append(peak_npts)
        peak_avg = np.mean(data.data['filtered'][lh+1:rh-1])
        peak_avgs.append(peak_avg)
        peak_max = np.max(data.data['filtered'][lh+1:rh-1])
        peak_maxs.append(peak_max)
        peak_min = np.min(data.data['filtered'][lh+1:rh-1])
        peak_mins.append(peak_min)
        peak_std = np.std(data.data['filtered'][lh+1:rh-1])
        peak_stds.append(peak_std)
        print('{}, {}, {}, {}, {}, {}'.format(peaks[i], peak_npts, peak_min, peak_max, peak_avg, peak_std))
        fig.line([lh+1, rh-1],[peak_avg, peak_avg], line_width=3, color='green')
    #print('Peak averages:')
    #print(peak_avgs)

def analyze(args):
    csv_file = args[0]
    tool_df = pd.read_csv(csv_file)
    avg = np.mean(tool_df['filtered'])
    print('avg: ' + str(avg))
    peaks, peak_params = signal.find_peaks(-tool_df['filtered'], prominence=2)
    print('Found ' + str(len(peaks)) + ' peaks.')
    print('Peaks:')
    print(peaks)
    #print('peak parameters:')
    #print(peak_params)
    #print('peak_heights:')
    #print(peak_params['peak_heights'])
    return tool_df, peaks, peak_params

if __name__ == "__main__":

    args = sys.argv[1:]
    if len(args) < 1:
        print('Usage: analyze [filename]')
    else:
        print('Analyzing {}'.format(args[0]))
        tool_df, peaks, peak_params = analyze(args)

    DATA = ColumnDataSource(data=dict(index = tool_df.index.values, \
                                      pt_count=tool_df['pt_count'], \
                                      dataset_id=tool_df['dataset_id'], \
                                      timestamp=tool_df['timestamp'], \
                                      displacement=tool_df['displacement'], \
                                      filtered=tool_df['filtered'], \
                                      intensity=tool_df['intensity']))
    make_document(DATA, peaks, peak_params, args)
