#!/bin/bash
for interface in eth0 p5p1 wlan0 enp4s0f0 enp4s0f1 enp5s0f0 enp5s0f1
do
	addr=`ip addr show $interface 2> /dev/null | grep 'inet ' | cut -f 6 -d ' ' | cut -f 1 -d '/'`
	if [[ ! -z "$addr" ]]; then
		echo $addr
		exit
	fi
done