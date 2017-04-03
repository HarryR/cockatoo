#!/usr/bin/env bash
ufw --force reset

ufw default deny incoming
ufw default deny routed
ufw default allow outgoing

ufw route allow in on docker0
ufw route allow in on vboxnet0 from 0.0.0.0/0  # Don't let IPv6 escape

# Allow only guests to access reporting server
ufw allow in on vboxnet0 to 192.168.56.1 from 192.168.56.0/24

# Block guests access to local networks
ufw deny in on vboxnet0 to 172.16.0.0/12
ufw deny in on vboxnet0 to 192.168.0.0/16
ufw deny in on vboxnet0 to 10.0.0.0/8
ufw allow in on vboxnet0 from 192.168.56.0/24 to 0.0.0.0/0

ufw allow 22  # To avoid lockout

ufw enable

ufw status verbose
