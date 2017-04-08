	   _____           _         _              
	  / ____|         | |       | |                   )/_
	 | |     ___   ___| | ____ _| |_ ___   ___       <' \
	 | |    / _ \ / __| |/ / _` | __/ _ \ / _ \      /)  )
	 | |___| (_) | (__|   < (_| | || (_) | (_) |  ---/'-""---
	  \_____\___/ \___|_|\_\__,_|\__\___/ \___/ 
	                                            

This Docker-ized distribution of Cuckoo 2.0 should make it easy to run Cuckoo and create virtual machines for analysis with `vmcloak`. Tor is used to retrieve malware samples with `maltrieve`, all traffic from the analysis VMs is also routed through Tor.


### Features

 * Cuckoo 2.0
 * vmcloak
 * maltrieve
 * VirtualBox inside Docker
 * X11 pass-through for testing


## Getting Started

On an Ubuntu x86_64 machine: checkout the source, install the prerequesite packages and then build the containers with:

	sudo apt-get install make git
	git clone https://github.com/HarryR/cockatoo --recursive
	make -C cockatoo prereq  # uses sudo

	# In /etc/default/docker - modify DOCKER_OPTS:
	# DOCKER_OPTS="--storage-driver=devicemapper"
	sudo service docker restart

	# Then make sure your user is a member of the 'docker' and 'vboxusers' group
	# e.g.: gpasswd -a $USERNAME docker
	# e.g.: gpasswd -a $USERNAME vboxusers

	make -C cockatoo build run-cuckoo

The full build process will take 10 minutes to an hour+ depending on your
internet, cpu and disk speeds etc. Assuming everything goes well you will have everything necessary to build guests, run Cuckoo and start analysing malware.

When running Cuckoo the `VIRTUALBOX_MODE` option can be used to show or hide 
the VirtualBox GUI.

	VIRTUALBOX_MODE=gui make -C cockatoo run-cuckoo


## Useful Links

 * http://vmcloak.org/
 * https://www.cuckoosandbox.org/
 * http://deaddrop.threatpool.com/vmcloak-how-to/
