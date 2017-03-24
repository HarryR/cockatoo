FROM ubuntu:16.04
MAINTAINER Harry <docker-virtualbox5@midnight-labs.org>

ENV DEBIAN_FRONTEND noninteractive

# The virtualbox driver device must be mounted from host
VOLUME /dev/vboxdrv

RUN apt-get update
RUN apt-get -y install curl wget

# Install VirtualBox
RUN curl https://www.virtualbox.org/download/oracle_vbox_2016.asc | apt-key add -
RUN sh -c 'echo "deb http://download.virtualbox.org/virtualbox/debian xenial contrib" >> /etc/apt/sources.list.d/virtualbox.list'
RUN apt-get update
RUN apt-get install -y virtualbox-5.1

# Install Virtualbox Extension Pack
RUN VBOX_VERSION=`dpkg -s virtualbox-5.1 | grep '^Version: ' | sed -e 's/Version: \([0-9\.]*\)\-.*/\1/'` ; \
    wget -q http://download.virtualbox.org/virtualbox/${VBOX_VERSION}/Oracle_VM_VirtualBox_Extension_Pack-${VBOX_VERSION}.vbox-extpack ; \
    VBoxManage extpack install Oracle_VM_VirtualBox_Extension_Pack-${VBOX_VERSION}.vbox-extpack ; \
    rm Oracle_VM_VirtualBox_Extension_Pack-${VBOX_VERSION}.vbox-extpack

RUN apt-get clean 
