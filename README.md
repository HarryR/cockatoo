	   _____           _         _              
	  / ____|         | |       | |                   )/_
	 | |     ___   ___| | ____ _| |_ ___   ___       <' \
	 | |    / _ \ / __| |/ / _` | __/ _ \ / _ \      /)  )
	 | |___| (_) | (__|   < (_| | || (_) | (_) |  ---/'-""---
	  \_____\___/ \___|_|\_\__,_|\__\___/ \___/ 
	                                            

## Warning: work in progress, stuff may still be broken.

This Docker-ized distribution of Cuckoo, called Cockatoo, contains everything 
you need to start analyzing malware with Cuckoo using a cluster of workers.
Cuckoo is a relatively complex piece of software requiring many tightly
integrated components, so while Cockatoo should get you 90% of the way there, 
a thorough understanding of virtualisation, networking, Docker, Linux, Cuckoo, 
and generally configuring stuff is highly advantageous to get anywhere quickly.

While Docker is used to conveniently package software, vmcloak and the Cuckoo
worker run in privileged mode within the hosts network namespace, this is
presently required for VirtualBox to fully function.

## Getting Started

The setup process goes as follows:

 1. Checkout cockatoo source code
 2. Install prerequesites
 3. Build Docker containers
 4. Copy Windows ISOs into `cockatoo/isos`
 5. Build and customise Base VMs using `vmcloak`
 6. Start docker containers

Checkout the source, install the prerequesites and build the containers with:

	apt-get install make git
	git clone https://github.com/HarryR/cockatoo --recursive
	make -C cockatoo prereq

	# In /etc/default/docker - modify DOCKER_OPTS:
	# DOCKER_OPTS="--storage-driver=devicemapper"
	sudo service docker restart

	# Then make sure your user is a member of the 'docker' and 'vboxusers' group
	# e.g.: gpasswd -a $USERNAME docker
	# e.g.: gpasswd -a $USERNAME vboxusers
	make -C cockatoo build
	vboxmanage hostonlyif create

	# Then setup rules to block LAN access from vboxnet0
	ufw allow in on enp4s0f0 from 192.168.10.0/24 to 192.168.10.0/24 port 22
	ufw default deny incoming
	ufw route allow in on docker0
	ufw allow in on vboxnet0 to 172.28.128.0/24
	ufw deny in on vboxnet0 to 172.16.0.0/12
	ufw deny in on vboxnet0 to 192.168.0.0/16
	ufw deny in on vboxnet0 to 10.0.0.0/8
	#ufw default allow routed


	#ufw default deny incoming
	#ufw deny in on vboxnet0 to 172.16.0.0/12
	#ufw deny in on vboxnet0 to 192.168.0.0/16
	#ufw deny in on vboxnet0 to 10.0.0.0/8

	ufw allow 5432/tcp
	ufw allow 9003/tcp
	ufw allow 8090/tcp
	ufw allow 2042/tcp

	#ufw deny in on vboxnet0 to 172.16.0.0/12
	#ufw deny in on vboxnet0 to 192.168.0.0/16
	#ufw deny in on vboxnet0 to 10.0.0.0/8
	#ufw deny in on vboxnet0 proto ipv6
	#ufw deny out on enp4s0f0 from 172.28.128.0/24

	#ufw route allow in on vboxnet0 from 172.28.128.0/24
	#ufw route allow in on docker0
	#ufw allow 5432/tcp
	#ufw allow 9003/tcp
	#ufw allow 8090/tcp
	#ufw allow 2042/tcp


The full build process will take 10 minutes to an hour+ depending on your
internet, cpu and disk speeds etc. Assuming everything goes well you will have 
everything necessary to build VMS, run Cuckoo and start analysing malware.

Next, lets build a Windows XP base image using the ISO you stole from your
grandma and a serial key found underneath a laptop in a second-hand PC shop ;)

	wget -O isos/winxp.iso http://torrents.example.com/winxp.iso
	make run-vmcloak
	$ /root/makevm.sh winxp32-base winxp winxp.iso XXXXX-XXXXX-XXXXX-...

The `makevm.sh` script is a quick utility to make building base images easier,
its arguments are:

 * vm-name
 * os-version - one of: `winxp`, `win7`, `win7x64`
 * iso-filename - relative to `isos/`
 * serial-key

When the `cuckoo-worker` container is started it will create a snapshot of all 
the VMs you've created with `vmcloak` and register them with Cuckoo. This 
happens every time the container is started as the worker container keeps 
no persistent data, if you have a lot of VMs it may take a while for Cuckoo 
to be ready to start processing malware.

Finally, it's time to start up the behemoth:

	sudo make run

## Architecture & Infrastructure

IP addresses:

 * `vboxnet0` - `172.28.128.1/24`
 * Cuckoo guest VMs - `172.28.128.100+`

Ports:

 * 9003 - Cuckoo Distributed API - allow through firewall
 * 2042 - Cuckoo Worker Reporting Server
 * 8090 - Cuckoo Worker API

## Using the VPN

Ensure that `AUTOSTART="none"` in `/etc/default/openvpn`, otherwise the docker daemon will fail to start.

	make cryptostorm
	systemctl daemon-reload

## Managing Cockatoo

The `Makefile` includes utility targets to provide easy access to container shells, the supervisor processes etc. for easy debugging:

 * `make supervise`
 * `make supervise-worker`
 * `make supervise-dist`
 * `make shell-db`
 * `make shell-worker`

To pause processing, stop the 'dist-scheduler' process

## TODO / Maybe / Ideas etc.

 * Speed up startup of cuckoo worker (specifically the VM import!)
 * More reliable start/stop mechanism
 * Replace supervisor with something that manages dependencies + delays
 * Better logging management, hierarchical?
 * Tighter security + protection
 * All roads point to `systemd` ....

## VM Installation

Despite having bought retail copies of Windows and Office, they aren't appropriate for using within a malware analysis environment and will frequently complain and/or de-activate themselves, because of this it's necessary to force Windows & Office to permanently activate and not do silly things like constantly ping license servers or otherwise attempt to contact the outside world.

vmcloak configures the first ethernet device, don't change this unless you remember to change it back to previous settings. to access the internet add a second NAT adapter in VirtualBox.

Basic gist of it is:

 * Install Microsoft products
 * Stop them complaining and contacting the internet
 * Install misc. crapware
 * Disable unnecessary stuff, reduce memory profile
 * Make it look like a real computer
 * Optimise the VM image
 
The steps are:

 * Download Windows 7 (`en_windows_7_professional_with_sp1_x64_dvd_u_676939.iso`)
 * Download Office 2013 (`en_office_professional_plus_2013_x64_dvd_1123674.iso`)
 * Activate Windows - Daz loader 2.2.2
 * Install MS Toolkit 2.6, convert Office 2013 to Volume License
 * Install ccleaner
 * .NET Framework 4.5 (`NDP451-KB2858728-x86-x64-AllOS-ENU.exe`)
 * Install Office 2013, Acrobat (11.0.0.3), Flash (11.7.700.169), Java (7u17), uTorrent (3.3 29609) - www.oldapps.com / all from 2013 - early 2014
 * Install crap from NiNite (avoiding 'security' products, chrome, firefox, PDF readers etc.)
 * Install nvidia or ATI drivers and associated cruft.
 * Find a cool desktop background
 * Disable java & acrobate update, ccleaner auto-start etc.
 * Turn off non-essential services - http://www.optimizingpc.com/windows7/optimizing_windows_7_services.html / http://www.blackviper.com/service-configurations/black-vipers-windows-7-service-pack-1-service-configurations/
 * Change OEM branding - http://stormpoopersmith.com/software/oem-brander/
 * Disable LLMNR - http://www.computerstepbystep.com/turn-off-multicast-name-resolution.html
 * Disable NCSI - https://technet.microsoft.com/en-us/library/cc766017(v=ws.10).aspx - `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet!EnableActiveProbing=0`
 * Disable system restore & swap/page file.
 * Disable search indexing on `C:\`
 * Run CCleaner and clean *everything*
 * Defragment harddrive
 * Wipe free space with zero bytes (CCleaner)
 * Compact VM image - `vboxmanage modifyhd win7x64.vdi --compact`

Now you should have a minimal noiseless Windows 7 VM that can open Office documents, play flash & java apps, run most applications etc. All of the stuff your grandmother needs to unsafely browse the internet and get infected with all the crapware in the world.

## Useful Links

### Cuckoo / VMCloak

 * http://vmcloak.org/
 * https://www.cuckoosandbox.org/
 * http://deaddrop.threatpool.com/vmcloak-how-to/

### OpenVPN 

 * http://askubuntu.com/questions/763583/correct-way-of-systemd-for-openvpn-client-on-16-04-server
 * http://unix.stackexchange.com/questions/148990/using-openvpn-with-systemd
 * `/lib/systemd/system-generators/openvpn-generator cryptostorm`
