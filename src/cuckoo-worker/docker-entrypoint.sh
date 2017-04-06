#!/bin/bash
set -e

if [ "${1:0:1}" = '-' ]; then
	set -- supervisord "$@"
fi

mkdir -p /.config/ /.cuckoo/log /.cuckoo/db /.cuckoo/yara /.cuckoo/storage/analyses /.cuckoo/storage/binaries /.cuckoo/storage/baseline /.vmcloak/image/ || true
touch /.cuckoo/.cwd /.cuckoo/yara/index_memory.yar /.cuckoo/yara/index_urls.yar /.cuckoo/yara/index_binaries.yar
chown -fR cuckoo: /.config/ /.cuckoo/ /.vmcloak/ || true
chown -f root:cuckoo /cuckoo/data/yara/ || true
chmod -f g+w /cuckoo/data/yara/ /.cuckoo/conf/virtualbox.conf || true
chown -f cuckoo: /.vmcloak/ /.vmcloak/vms/ /cuckoo/conf/virtualbox.conf || true

cp -R /cuckoo/analyzer/* /.cuckoo/analyzer/

export HOME=/

ifconfig vboxnet0 192.168.56.1/24

# Virtualbox machinery requires import of VMs from vmcloak
if [[ "$CUCKOO_MACHINERY" = "virtualbox" ]]; then
	SUBNET=192.168.56
	BASEIP=127
	VM_N=0
	IMGDIR=/.vmcloak/image
	VMS_TO_REGISTER=`ls -1 $IMGDIR/*.vdi | xargs -n 1 basename`
	if [[ ! -z "$VMS_TO_REGISTER" ]]; then
		for FILE in $VMS_TO_REGISTER
		do
			vmname=`basename $FILE | cut -f 1 -d .`

			if [[ ! -f "$IMGDIR/$FILE" ]]; then
				echo "Skipping $IMGDIR/$FILE"
				continue
			fi
			if [[ ! -z "$VM_MAX_N" ]]; then
				if [[ $VM_N -ge $VM_MAX_N ]]; then
					echo "Not spawning any more, reached MAX $VM_MAX_N"
					break
				fi
			fi
			vmip=$SUBNET.$BASEIP
			BASEIP=$((BASEIP + 1))

			OPTFILE="$IMGDIR/$vmname.opt"
			if [[ -f $OPTFILE ]]; then
				OPTS=$(eval echo $(cat $OPTFILE))
				vmcloak add $OPTS $vmname
				chown cuckoo: /.vmcloak/*.db
			fi

			# First purge, then register it again
			echo "Importing VM: $vmname - IP: $vmip"
			#/cuckoo/utils/machine.py --delete $vmname || true
			VMCLOAK_ARGS=
			if [[ $CUCKOO_VIRTUALBOX_MODE = 'gui' ]]; then
				VMCLOAK_ARGS=--vm-visible
			fi
			vmcloak -u cuckoo snapshot $VMCLOAK_ARGS --debug $vmname vm-$vmname $vmip
			echo "Registering VM"
			vmcloak -u cuckoo register vm-$vmname /.cuckoo
			VM_N=$((VM_N + 1))
		done
	else
		echo "WARNING: no VMs to register... Cuckoo will fail hard."
	fi
# Whereas qemu machinery just needs our custom config files
# added to the end of the qemu.conf file
elif [[ "$CUCKOO_MACHINERY" = "qemu" ]]; then
	QEMU_MACHINES=""
	VMS_TO_REGISTER=`ls -1 /.vmcloak/image/*.ini`
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
