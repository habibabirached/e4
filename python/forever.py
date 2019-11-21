#!/usr/bin/python
from subprocess import Popen
import sys

prog_name = ""
arg_val = ""
if len(sys.argv) == 1:
    print("No script to run was specified. Exiting.")
    exit()

if len(sys.argv) > 1:
    prog_name = sys.argv[1]

if len(sys.argv) > 2:
    arg_val = sys.argv[2]

while True:
    execute_str = prog_name + " " + arg_val
    print("\nStarting " + execute_str)
    p = Popen("python " + execute_str, shell=True)
    p.wait()
