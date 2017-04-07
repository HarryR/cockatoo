#!/usr/bin/env bash
curl https://www.virtualbox.org/download/oracle_vbox_2016.asc | apt-key add -
sh -c 'echo "deb http://download.virtualbox.org/virtualbox/debian `lsb_release -cs` contrib" >> /etc/apt/sources.list.d/virtualbox.list'
apt-get update
apt-get install -y virtualbox-5.1

# Install Virtualbox Extension Pack
VBOX_VERSION=`dpkg -s virtualbox-5.1 | grep '^Version: ' | sed -e 's/Version: \([0-9\.]*\)\-.*/\1/'` ; \
    wget -q http://download.virtualbox.org/virtualbox/${VBOX_VERSION}/Oracle_VM_VirtualBox_Extension_Pack-${VBOX_VERSION}.vbox-extpack ; \
    VBoxManage extpack install Oracle_VM_VirtualBox_Extension_Pack-${VBOX_VERSION}.vbox-extpack ; \
    rm Oracle_VM_VirtualBox_Extension_Pack-${VBOX_VERSION}.vbox-extpack

if [[ -f /dev/vboxdrv ]]; then
	/sbin/vboxconfig || true
fi