	   _____           _         _              
	  / ____|         | |       | |                   )/_
	 | |     ___   ___| | ____ _| |_ ___   ___       <' \
	 | |    / _ \ / __| |/ / _` | __/ _ \ / _ \      /)  )
	 | |___| (_) | (__|   < (_| | || (_) | (_) |  ---/'-""---
	  \_____\___/ \___|_|\_\__,_|\__\___/ \___/ 
	                                            

## Warning: work in progress, stuff may still be broken.

This Docker-ized distribution of Cuckoo, called `Cockatoo`, it contains
everything you need to start analyzing malware with Cuckoo.

While Docker is used to conveniently package software, vmcloak and the Cuckoo
worker run in privileged mode within the hosts network namespace, this is
presently required for VirtualBox to fully function.


## Getting Started

The setup process goes as follows:

 1. Checkout cockatoo source code
 2. Install prerequesites
 3. Build Docker container
 4. Copy Windows ISOs into `cockatoo/isos`
 5. Build and customise Base VMs using `vmcloak`
 6. Start docker container

Checkout the source, install the prerequesites and build the containers with:

	sudo apt-get install make git
	git clone https://github.com/HarryR/cockatoo --recursive
	make -C cockatoo prereq  # uses sudo

	# In /etc/default/docker - modify DOCKER_OPTS:
	# DOCKER_OPTS="--storage-driver=devicemapper"
	sudo service docker restart

	# Then make sure your user is a member of the 'docker' and 'vboxusers' group
	# e.g.: gpasswd -a $USERNAME docker
	# e.g.: gpasswd -a $USERNAME vboxusers

	make -C build run-cuckoo

The full build process will take 10 minutes to an hour+ depending on your
internet, cpu and disk speeds etc. Assuming everything goes well you will have 
everything necessary to build guests, run Cuckoo and start analysing malware.

When running Cuckoo the `VIRTUALBOX_MODE` option can be used to show or hide 
the VirtualBox GUI.

	VIRTUALBOX_MODE=gui make -C cockatoo run-cuckoo


## VM Installation

### Windows

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
 * Install crap from NiNite
 * Find a cool desktop background
 * Disable java & acrobate update, ccleaner auto-start etc.
 * Change OEM branding - http://stormpoopersmith.com/software/oem-brander/
 * Turn off non-essential services - http://www.optimizingpc.com/windows7/optimizing_windows_7_services.html / http://www.blackviper.com/service-configurations/black-vipers-windows-7-service-pack-1-service-configurations/
 * Disable 'Windows Time service'
 * Disable LLMNR - http://www.computerstepbystep.com/turn-off-multicast-name-resolution.html
 * Disable NCSI - https://technet.microsoft.com/en-us/library/cc766017(v=ws.10).aspx - `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet!EnableActiveProbing=0`
 * Disable system restore & swap/page file.
 * Disable search indexing on `C:\`
 * Run CCleaner and clean *everything*
 * Defragment harddrive
 * Wipe free space with zero bytes (CCleaner)
 * Compact VM image - `vboxmanage modifyhd win7x64.vdi --compact`

Now you should have a Windows 7 VM that can open Office documents, play flash & java apps, run most applications etc. Disabling some services makes packet captures cleaner because the VM won't make requests to the internet or LAN while idle.

### Linux




## Useful Links

### Cuckoo / VMCloak

 * http://vmcloak.org/
 * https://www.cuckoosandbox.org/
 * http://deaddrop.threatpool.com/vmcloak-how-to/

### OpenVPN 

 * http://askubuntu.com/questions/763583/correct-way-of-systemd-for-openvpn-client-on-16-04-server
 * http://unix.stackexchange.com/questions/148990/using-openvpn-with-systemd
 * `/lib/systemd/system-generators/openvpn-generator cryptostorm`

### VirtualBox

 * `vboxmanage internalcommands sethduuid win7x64.vdi`