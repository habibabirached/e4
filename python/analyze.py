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
    disp_fig.line('index', 'displacement', source=data, line_width=3, \
                  line_alpha=0.6, line_color='blue')
    hover1 = disp_fig.select(dict(type=HoverTool))
    hover1.tooltips = [('Index', '@index'),('Displacement', '@displacement')]
    hover1.mode = 'mouse'
    plot_peaks(disp_fig, data, peaks, peak_params, args)

    # Plot point counts
    #pt_count_fig = figure(title='Set Point Count', \
    #                      width=PLOT_W, height=PLOT_H, \
    #                      x_range=disp_fig.x_range, tools=tools_to_show, active_drag='box_zoom')
    #pt_count_fig.xaxis.axis_label = 'Index'
    #pt_count_fig.yaxis.axis_label = 'Point Count/Dataset'
    #pt_count_fig.line('index', 'pt_count', source=data, line_width=3, \
    #                  line_alpha=0.6, line_color='red')
    #hover2 = pt_count_fig.select(dict(type=HoverTool))
    #hover2.tooltips = [('Index', '@index'),('Point Count', '@pt_count')]
    #hover2.mode = 'mouse'

    # Plot dataset ids
    #dataset_id_fig = figure(title='Dataset IDs', \
    #                        width=PLOT_W, height=PLOT_H, \
    #                        x_range=disp_fig.x_range, tools=tools_to_show, active_drag='box_zoom')
    #dataset_id_fig.xaxis.axis_label = 'Index'
    #dataset_id_fig.yaxis.axis_label = 'Dataset ID'
    #dataset_id_fig.line('index', 'dataset_id', source=data, line_width=3, \
    #                    line_alpha=0.6, line_color='green')
    #hover3 = dataset_id_fig.select(dict(type=HoverTool))
    #hover3.tooltips = [('Index', '@index'),('Dataset ID', '@dataset_id')]
    #hover3.mode = 'mouse'

    # Plot filtered data
    #filtered_fig = figure(title='Filtered Displacement', \
    #                      width=PLOT_W, height=PLOT_H, \
    #                      x_range=disp_fig.x_range, \
    #                      y_range=disp_fig.y_range, \
    #                      tools=tools_to_show, active_drag='box_zoom')
    #filtered_fig.xaxis.axis_label = 'Index'
    #filtered_fig.yaxis.axis_label = 'Filtered Displacement'
    #filtered_fig.line('index', 'filtered', source=data, line_width=3, \
    #                     line_alpha=0.6, line_color='red')
    #hover4 = filtered_fig.select(dict(type=HoverTool))
    #hover4.tooltips = [('Index', '@index'),('Fitlered', '@filtered')]
    #hover4.mode = 'mouse'

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
    

    
    #curdoc().title = 'e4-Pt Data'
    #curdoc().add_root(disp_fig)

    layout = column(disp_fig,
                    intensity_fig)    
    #                filtered_fig)
    #                pt_count_fig,
    #                dataset_id_fig)

    csv_file = args[0]
    outfile_name = csv_file.replace(".csv",".html")
    output_file(outfile_name, title='Optical Sensor Data')
    show(layout)

def plot_peaks(fig, data, peaks, peak_params, args):
    # Plot the peaks
    for p in peaks:
        fig.circle(p,data.data['displacement'][p], size=7, color='red', alpha=0.5)
    # Compute and plot the peak 'average' line.
    peak_avgs = []
    for i in range(0,len(peak_params['left_bases'])):
        lh = peak_params['left_bases'][i]
        rh = peak_params['right_bases'][i]
        peak_avg = np.mean(data.data['displacement'][lh+1:rh-1])
        peak_avgs.append(peak_avg)
        fig.line([lh+1, rh-1],[peak_avg, peak_avg], line_width=3, color='green')
    print('Peak averages:')
    print(peak_avgs)
    peak_df = pd.DataFrame(list(zip(peak_params['left_bases'],peak_params['right_bases'],peak_avgs)),columns=['right','left','avg'])
    csv_file = args[0]
    csv_file = csv_file.replace(".csv","_peaks.csv")
    peak_df.to_csv(csv_file)

def filter_data(data):
    print('@filter_data')
    if True:
        #b, a = signal.bessel(10, 0.10, 'low', analog=False, norm='mag') # 20 rpm
        #b, a = signal.bessel(10, 0.20, 'low', analog=False, norm='phase') # 30 rpm
        #b, a = signal.bessel(10, 0.32, 'low', analog=False, norm='phase') # 60 rpm
        #b, a = signal.bessel(12, 0.45, 'low', analog=False, norm='phase') # 100 rpm
        #b, a = signal.bessel(12, 0.36, 'low', analog=False, norm='phase') # 150 rpm
        b, a = signal.bessel(12, 0.40, 'low', analog=False, norm='phase') # 200 rpm
        filtered = signal.filtfilt(b, a, data['displacement'])
    else:
        z = fftpack.fft(data['displacement'])
        filtered = np.absolute(z)
    data['filtered'] = filtered
    #data['filtered'] = data['displacement']

def analyze(args):
    csv_file = args[0]
    tool_df = pd.read_csv(csv_file)
    #filter_data(tool_df)
    avg = np.mean(tool_df['displacement'])
    print('avg: ' + str(avg))
    peaks, peak_params = signal.find_peaks(-tool_df['displacement'], prominence=2)
    print('Found ' + str(len(peaks)) + ' peaks.')
    print('Peaks:')
    print(peaks)
    print('peak parameters:')
    print(peak_params)
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
    #tool_df.to_csv('debug.csv')
