#!/bin/bash

logfile=$1
if [ -z "$logfile" ]; then
	echo "Specify a filename"
	exit 1
fi

sed -i -r '/(error|ignoring|checkpvs|Invalid|Some entity is stuck|deprecated|packetlog overflow)/ d' "$logfile"
