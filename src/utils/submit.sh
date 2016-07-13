#!/bin/bash
if [[ -z "$1" ]]; then
	echo "Usage: `basename $0` <file>"
	exit 1
fi
if [[ ! -f "$1" ]]; then
	echo "Error: cannot find file '$1'"
	exit 2
fi
curl http://localhost:9003/api/task -F file="@$1" -F timeout=30 -F priority=2
