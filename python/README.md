# e4PtTool - Python code
Python code for development of the e-4Pt tool.

This code was developed in Python for the following reason. The e-4Pt tool is being developed with the intent of using the same hardware that is used for the TRACC Scan tool.  This means the code can run on an x86/x64 platform.  Under Linux or Windows Python is a convenient, free, powerful, easy-to-use language.  Furthermore, if the platform is moved to something smaller, like an Arduino or Raspberry Pi, the environment can still be Linux, meaning the code is portable.

Code in this folder is currently not well organized, but rather thrown together to have a single place to hold it.  Some of the code is very old not not intended for use.

As of this writing (09Jan2019), the scripts that work and are being used are:
* e4_point_module_bokeh.py - This script has the ability to collect data and plot it.  It also has the capability, based on command line arguments to output a CSV file, or run a LPF on the data.
* TCPModbus_MTI_2.py - This script is based on work done by Fergus Ross but has been heavily modified to work with the new MTI firmware which allows higher speed data collection.

