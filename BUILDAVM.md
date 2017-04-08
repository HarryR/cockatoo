
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


### VirtualBox

 * `vboxmanage internalcommands sethduuid win7x64.vdi`