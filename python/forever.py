#!/usr/bin/python
from subprocess import Popen
import sys

prog_name = sys.argv[1]
arg_val = sys.argv[2]

while True:
    execute_str = prog_name + " " + arg_val
    print("\nStarting " + execute_str)
    p = Popen("python " + execute_str, shell=True)
    p.wait()
