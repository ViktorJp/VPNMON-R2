# VPNMON

**Executive Summary**: VPNON 0.4 (VPNON.SH) script is a companion of the VPNMGR program by @JackYaz running on Asus Merlin FW for Asus routers, and is meant to be run with a CRU job in order to reset and randomly connect to a new VPN server each day at a different location specified within VPNMGR through NordVPN. It also downloads a list of US-based NordVPN server IP addresses, and adds them to the Skynet whitelist each time this runs, as these frequently change. Set the variable in the scripts to enable/disable this functionality.  

I am by no means a serious script programmer. I've combed through lots of code and examples found both on the Merlin FW discussion forums and online to cobble this stuff together. You will probably find inefficient code, or possibly shaking your head with the rudimentary ways I'm pulling things off... but hey, I'm learning, and it works! ;)  Huge thanks and shoutouts to @JackYaz and @Martineau for their inspiration and gorgeous looking code, and for everyone else that has helped me along the way on the Merlin forums: https://www.snbforums.com/forums/asuswrt-merlin.42/

The Problem I was trying to solve
---------------------------------
* As a VPNMGR user, I have 5 different NordVPN VPN Client configurations populated on my Asus router running Merlin FW, each with a different city.  I wanted a way for my VPN connection to reset each night, so that it would randomly select and connect to a different configuration, thus endpoint, so that I wouldn't be connected to the same city 24x7x365.
* NordVPN has thousands of VPN endpoint servers which change frequently, depending on the distance or latency from your location scattered across the globe.  On several occations, my Asus-Merlin-based Skynet firewall would block these VPN servers, and wanted to make sure I had a way to find all the latest VPN server IPs, and add them to the Skynet whitelist.

How is this script supposed to run?
-----------------------------------
Personally, I run this script 1x a day at night using a CRU job. But you can run it as much as you want... read up on CRU formatting.  Secondarily, this script is also called from my other program, VPNMON, when it detects that the VPN connection has dropped.  Here are some steps to make a nightly job happen:
1. Copy this script over into your /jffs/scripts folder, and make sure it's called "vpnon.sh"
2. To run this script every night at 01:00, from a command prompt, enter:
   cru a vpnon "00 01 * * * /jffs/scripts/vpnon.sh"
3. Make sure this script is executable, from a command prompt, enter:
   chmod +x /jffs/scripts/vpnon.sh

What this script does
---------------------
1. Kills all VPN Clients, if they're running or not
2. Updates Skynet whitelist with all US-based NordVPN endpoint IP addresses (optional) - FYI, you can easily change this for the country of your choice.
3. Updates VPNMGR cache with recommended NordVPN endpoint information, and merges/refreshes these changes with your Merlin VPN Client configurations
4. Uses a randomizer to pick one of 5 different VPN Clients to connect to (configurable between 1 and 5)
5. Initiates the connection to the specified NordVPN endpoint.

Gotchas
-------
* Make sure you have installed VPNMGR, and have tested refreshing its cache, and that you are able to successfully connect to NordVPN before running this script. You may find the program and installation/configuration information here: https://www.snbforums.com/threads/vpnmgr-manage-and-update-vpn-client-configurations-for-nordvpn-and-pia.64930/
* Make sure you configure the N=5 variable in VPNON to the same number of VPN Client slots you have configured.
* Make sure you keep your VPN Client slots sequential... don't use 1, 2, and 4... for instance.  Keep it to 1, 2, and 3.

Disclaimer
----------
Use at your own risk.  I've been using this script successfully for a long time on an Asus RT-AC86U running Merlin FW v386.3_2 and v386.4, and seems to work just fine for my needs.
