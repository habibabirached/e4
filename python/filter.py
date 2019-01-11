import sys
import numpy as np
from scipy import signal
from bokeh.io import show, output_file
from bokeh.plotting import figure, ColumnDataSource, curdoc
from bokeh.layouts import column
from bokeh.models import HoverTool

def make_plots(disp, filt_disp):
    ''' make bokeh plots for before & after filtering '''
    print('@make_plots')
    tools_to_show = 'hover, box_zoom, pan, save, reset, wheel_zoom'

    index = range(len(disp))

    source = ColumnDataSource(data=dict(index=index,
                                        disp=disp,
                                        filt_disp=filt_disp))
    # Plot displacement
    disp_fig = figure(title='Capacitance Sensor Displacement', \
                      width=500, height=500, tools=tools_to_show)
    disp_fig.xaxis.axis_label = 'Index'
    disp_fig.yaxis.axis_label = 'Displacement (mm)'
    disp_fig.line('index', 'disp', source=source, line_width=3, \
                  line_alpha=0.6, line_color='blue')
    hover1 = disp_fig.select(dict(type=HoverTool))
    hover1.tooltips = [('Index', '@index'),('Displacement', '@disp')]
    hover1.mode = 'mouse'
    
    # Plot filtered displacement
    fdisp_fig = figure(title='Filtered Displacement', \
                       width=500, height=500, \
                       x_range=disp_fig.x_range, \
                       y_range=disp_fig.y_range, \
                       tools=tools_to_show)
    fdisp_fig.xaxis.axis_label = 'Index'
    fdisp_fig.yaxis.axis_label = 'Filtered Displacement (mm)'
    fdisp_fig.line('index', 'filt_disp', source=source, line_width=3, \
                   line_alpha=0.6, line_color='blue')
    hover2 = fdisp_fig.select(dict(type=HoverTool))
    hover2.tooltips = [('Index', '@index'),('Displacement', '@filt_disp')]
    hover2.mode = 'mouse'

    layout = column(disp_fig, fdisp_fig)
    output_file('filter.html', title='MTI Sensor Data')
    show(layout)    
    
def filter_data(args, data):
    ''' filter the data '''
    print('@filter_data')
    freq_cutoff = float(args[1])
    n_order = 1
    samp_freq = 20000
    print('n_order: {}; freq_cutoff: {}; fs: {}'.format(n_order, freq_cutoff, samp_freq))
    sos = signal.butter(n_order, freq_cutoff, 'lowpass', fs=samp_freq, output='sos')
    filtered = signal.sosfilt(sos, data)
    return filtered

if __name__ == "__main__":
    ''' read data from CSV file and apply a digital LPF. '''
    args = sys.argv[1:]
    data = np.genfromtxt(args[0], skip_header=1, delimiter=',')
    disp = data[:,4]
    #print('Disp:\n{}'.format(disp))
    filt_disp = filter_data(args, disp)
    make_plots(disp, filt_disp)
