#!/usr/bin/env bash
ufw --force reset

ufw default deny incoming
ufw route allow in on docker0
ufw route allow in on vboxnet0
ufw allow in on vboxnet0 to 192.168.56.1 port 2042 from 192.168.56.0/24
ufw deny in on vboxnet0 to 172.16.0.0/12
ufw deny in on vboxnet0 to 192.168.0.0/16
ufw deny in on vboxnet0 to 10.0.0.0/8

ufw enable

ufw status verbose