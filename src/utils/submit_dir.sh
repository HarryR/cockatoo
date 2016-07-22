#!/bin/bash
if [[ -z "$1" ]]; then
	echo "Usage: `basename $0` <dir> [dir ...]"
	exit 1
fi

for DIR in "${@:1}"
do
	if [[ ! -d "$DIR" ]]; then
		echo "Ignoring $DIR - not a directory"
		continue
	fi
	for FILE in `ls -1 $DIR`
	do
		FULLPATH=$DIR/$FILE
		if [[ -f "$FULLPATH" ]]; then
			curl http://localhost:9003/api/task -F file="@$FULLPATH" -F timeout=60
			rm -f "$FULLPATH"
		fi
	done
done 
