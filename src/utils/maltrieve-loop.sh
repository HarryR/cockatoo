#!/bin/bash
RESULT=0
while [[ $RESULT -eq 0 ]]
do
	make run-maltrieve
	RESULT=$?
	if [[ $RESULT -eq 0 ]]; then
		sleep 5h
	fi
done