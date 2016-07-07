#!/usr/bin/env python
from __future__ import print_function
import sys
import os
import os.path
import json

def main(args):
	if not len(args) or not os.path.exists(args[0]):
		print("Usage: scan-reports.py <reports-dir>");
		return
	reports_dir = args[0]
	for subdir in os.listdir(reports_dir):
		reports_json = os.path.join(reports_dir, subdir, 'report.json')
		if not os.path.exists(reports_json):
			continue
		try:
			data = json.loads(open(reports_json, 'r').read())
		except Exception:
			print("Unable to open %s" % (reports_json,))
			continue
		hosts = [X for X in data['network']['hosts'] if X not in ['8.8.8.8', '40.118.103.7']]
		dns = [X['request'] for X in data['network']['dns'] if X['request'] != 'time.windows.com']
		if len(hosts):
			print(hosts)
		if len(dns):
			print(dns)
		

if __name__ == "__main__":
	main(sys.argv[1:])
