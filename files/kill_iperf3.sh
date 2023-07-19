#!/bin/bash
# Kill iperf after 1 hour
while :; 
do 
	sleep 3600; 
	pkill iperf3; 
done
