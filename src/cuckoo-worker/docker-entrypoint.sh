#!/bin/bash
set -e

if [ "${1:0:1}" = '-' ]; then
	set -- supervisord "$@"
fi

SUBNET=172.28.128
BASEIP=100
VM_N=0
VMS_TO_REGISTER=`ls -1 /root/.vmcloak/image/`
if [[ ! -z "$VMS_TO_REGISTER" ]]; then
	for FILE in $VMS_TO_REGISTER
	do
		if [[ ! -z "$VM_MAX_N" ]]; then
			if [[ $VM_N -ge $VM_MAX_N ]]; then
				echo "Not spawning any more, reached MAX $VM_MAX_N"
				break
			fi
		fi
		vmname=`basename $FILE | cut -f 1 -d .`
		vmip=$SUBNET.$((BASEIP+VM_N))
		# First purge, then register it again
		echo "Importing VM: $vmname - IP: $vmip"
		#/cuckoo/utils/machine.py --delete $vmname || true
		vmcloak-snapshot $vmname vm-$vmname $vmip
		vmcloak-register vm-$vmname /cuckoo
		VM_N=$((VM_N + 1))
	done
else
	echo "WARNING: no VMs to register... Cuckoo will fail hard."
fi

exec "$@"
