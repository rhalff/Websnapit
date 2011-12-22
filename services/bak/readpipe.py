#!/usr/bin/python
import os

# the name of the pipe
pipeName = '/tmp/websnap_queue'

# we will get an error if the pipe exists
# when creating a new one, so try removing it first
try:
        os.unlink(pipeName)
except:
        pass

# create the pipe and open it for reading
os.mkfifo(pipeName)
pipe = open(pipeName,'r')

# read forever and print anything written to the pipe
while True:
        data = pipe.readline()
        if data != '':
                print repr(data)

