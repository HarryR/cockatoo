#!/bin/bash
RESULT=0
while [[ $RESULT -eq 0 ]]
do
	make run-maltrieve archive
	RESULT=$?
	if [[ $RESULT -eq 0 ]]; then
		sleep 1h
	fi
done