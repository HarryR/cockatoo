#!/usr/bin/env python
from __future__ import print_function
import errno
import os
import sys
import argparse
import requests
import subprocess
import json
from datetime import datetime, date, timedelta
from contextlib import closing
from hashlib import sha1


def mkdir_p(path):
    try:
        os.makedirs(path)
    except OSError as exc:  # Python >2.5
        if exc.errno == errno.EEXIST and os.path.isdir(path):
            pass
        else:
            raise


def hash_str(thestr):
    hasher = sha1()
    hasher.update(thestr)
    return hasher.hexdigest()


def setup_args(args):
    parser = argparse.ArgumentParser()
    parser.add_argument("-a", "--archive", default="/archive/cuckoo",
                        help="Archive directory", metavar="PATH")
    parser.add_argument("-d", "--days", type=float, default="4",
                        help="Delete Cuckoo tasks after N days", metavar="N")
    parser.add_argument("-c", "--cuckoo", default="http://192.168.56.1:8090",
                        help="Cuckoo API base URL", metavar="URL")
    return parser.parse_args(args)


def find_finished(opts):
    req = requests.get(opts.cuckoo + "/tasks/list")
    return req.json()


def split_dir(opts, task_guid):
    return os.path.join(opts.archive, task_guid[0], task_guid[1])


def task_download(opts, task):
    task_id = str(task['id'])
    if not task.get('sample', None):
        task_guid = hash_str(task['target'])
    else:
        task_guid = task['sample']['sha1']
    year_month = datetime.now().strftime('%Y-%m')
    output_dir = os.path.join(opts.archive, year_month, task_guid[0], task_guid[1])
    output_file = os.path.join(output_dir, task_guid + '.tar.bz2')
    output_task = os.path.join(output_dir, task_guid + '.task')
    output_report = os.path.join(output_dir, task_guid + '.report')
    if os.path.exists(output_file):
        print(" [-] Skipped, file already exists", task_id)
        return
    if not os.path.isdir(output_dir):
        mkdir_p(output_dir)

    print(" [*] %s" % (output_file,))
    command = 'docker exec -u cuckoo cuckoo tar cjhf - -C /.cuckoo/storage/analyses/' + str(task_id) + '/ . > ' + output_file
    subprocess.check_call(command, shell=True)

    with open(output_task, 'wb') as handle:
        handle.write(json.dumps(task))

    with closing(requests.get(opts.cuckoo + '/tasks/report/' + task_id, params=dict(report_format='json'), stream=True)) as resp:
        with open(output_report, 'wb') as handle:
            for chunk in resp.iter_content(chunk_size=1024 * 512):
                handle.write(chunk)

    completed_on = datetime.strptime(task['completed_on'], '%Y-%m-%d %H:%M:%S')
    time_threshold = datetime.today() - timedelta(opts.days)
    if completed_on < time_threshold:
        print(" [-] Deleted")
        requests.get(opts.cuckoo + "/tasks/delete/" + task_id)


def main(args=None):
    if args is None:
        args = sys.argv[1:]
    opts = setup_args(args)
    print("Cuckoo:", opts.cuckoo)
    print("Data:", opts.archive)
    print()
    for task in find_finished(opts)['tasks']:
        task_download(opts, task)
        print()


if __name__ == "__main__":
    sys.exit(main())
