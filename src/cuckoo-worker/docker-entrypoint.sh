#!/bin/bash
set -e

if [ "${1:0:1}" = '-' ]; then
	set -- supervisord "$@"
fi

# Virtualbox machinery requires import of VMs from vmcloak
if [[ "$CUCKOO_MACHINERY" = "virtualbox" ]]; then
	SUBNET=172.28.128
	VM_N=0
	VM_IMG_DIR=/root/.vmcloak/image/
	VMS_TO_REGISTER=`ls -1 $VM_IMG_DIR`
	if [[ ! -z "$VMS_TO_REGISTER" ]]; then
		for FILE in $VMS_TO_REGISTER
		do
			if [[ ! -f "$VM_IMG_DIR/$FILE" ]]; then
				echo "Skipping $VM_IMG_DIR/$FILE"
				continue
			fi
			vmname=`basename $FILE | cut -f 1 -d .`
			if [[ ! -f "$VM_IMG_DIR/$vmname.ip" ]]; then
				echo "Skipping $VM_IMG_DIR/$FILE - no .ip file"
				continue
			fi
			if [[ ! -z "$VM_MAX_N" ]]; then
				if [[ $VM_N -ge $VM_MAX_N ]]; then
					echo "Not spawning any more, reached MAX $VM_MAX_N"
					break
				fi
			fi
			vmip=`cat $vmname.ip`
			# First purge, then register it again
			echo "Importing VM: $vmname - IP: $vmip"
			#/cuckoo/utils/machine.py --delete $vmname || true
			vmcloak snapshot --debug $vmname vm-$vmname $vmip
			echo "Registering VM"
			vmcloak register vm-$vmname /cuckoo
			VM_N=$((VM_N + 1))
		done
	else
		echo "WARNING: no VMs to register... Cuckoo will fail hard."
	fi
# Whereas qemu machinery just needs our custom config files
# added to the end of the qemu.conf file
elif [[ "$CUCKOO_MACHINERY" == "qemu" ]]; then
	QEMU_MACHINES=""
	VMS_TO_REGISTER=`ls -1 /root/.vmcloak/image/`
	# Add all .ini files in /root/qemu to my qemu.conf
	# Then replace 'machines=' line
	for INIFILE in $VMS_TO_REGISTER
	do
		vmname=`basename $INIFILE | cut -f 1 -d .`
		echo "\[$vmname\]" >> /cuckoo/conf/qemu.conf
		cat $INIFILE >> /cuckoo/conf/qemu.conf
		if [[ -z $QEMU_MACHINES ]]; then
			QEMU_MACHINES=$vmname
		else
			QEMU_MACHINES="$QEMU_MACHINES,$vmname"
		fi
	done
	sed -i -e "s/machines=/machines=$QEMU_MACHINES/" /cuckoo/conf/qemu.conf
else
	echo "Unknown machinery $CUCKOO_MACHINERY"
fi

exec "$@"
