# VPNMON

**Executive Summary**: #VPNMON 0.5 (VPNMON.SH) is a simple script that accompanies my VPNON.SH script, which ultimately compliments @JackYaz's VPNMGR program to maintain a NordVPN setup on a Asus RT-AC86U router running Merlin FW. This script checks your 5 VPN connections on a regular interval to see if one is connected, and sends a ping to a host of your choice through the active connection.  If it finds that connection has been lost, it can execute the script of your choice (in this case, VPNON.SH), which will kill all VPN clients, and use VPNMGR's functionality to poll NordVPN for updated server names based on the locations you have selected in VPNMGR, and randomly picks one of the 5 VPN Clients to connect to. 

I am by no means a serious script programmer. I've combed through lots of code and examples found both on the Merlin FW discussion forums and online to cobble this stuff together. You will probably find inefficient code, or possibly shaking your head with the rudimentary ways I'm pulling things off... but hey, I'm learning, and it works! ;)  Huge thanks and shoutouts to @JackYaz and @Martineau for their inspiration and gorgeous looking code, and for everyone else that has helped me along the way on the Merlin forums: https://www.snbforums.com/forums/asuswrt-merlin.42/.  As always, a huge thank you and a lot of admiration goes out to @RMerlin, @Adamm, @L&LD and @thelonelycoder for everything you've done for the community

The Problem I was trying to solve
---------------------------------
* As a VPNMGR user, I have 5 different NordVPN VPN Client configurations populated on my Asus router running Merlin FW, each with a different city.  There were times that I would lose connection to one of these servers, and the router would just endlessly keep trying to reconnect to no avail.  Also, sometimes the SKynet firewall would block these NordVPN endpoints, and it would again, endlessly try to connect to a blocked endpoint.  Other times, freakishly, I would have more than 1 VPN Client kick on for some reason.  This program was built as a way to check to make sure VPN is connected, that the connection is clean, and that there aren't multiple instances running.  If anything was off, it would launch a full-on assault using a second script, VPNON.SH, and reset everything back to a normal state.

How is this script supposed to run?
-----------------------------------
Personally, I run this script in its own SSH window from a PC that's connected directly to the Asus router, as it loops and checks the connection every 30 seconds. I suppose there's other ways to run this script, but I will leave that up to you.
1. Copy this script over into your /jffs/scripts folder, and make sure it's called "vpnmon.sh"
2. To run this script, open up a dedicated SSH window, and simply execute the script:
   ``sh /jffs/scripts/vpnmon.sh``
3. Optionally, you can make this script executable, from a command prompt, enter:
   ``chmod +x /jffs/scripts/vpnmon.sh``

What this script does
---------------------
1. Checks the VPN State from NVRAM and determines if each of the 5 Clients are connected or not
2. If a VPN Client is connected, it sends a PING through to Google's DNS server to determine if the link is good (configurable)
3. If it determines that the VPN Client is down, or connection is broken, it will reset the VPN with VPNON.SH (configurable)
4. If it determines that multiple VPN Clients are running, it will reset the VPN with VPNON.SH (configurable)
5. It will loop through this process every 30 seconds (configurable)
6. If it determines that VPNON.SH is resetting the connection, it will hang back until VPNON.SH is done.

Gotchas
-------
* Make sure you have installed VPNMGR, that you have populated your VPN slots with it, have tested refreshing its cache, and that you are able to successfully connect to NordVPN before running this script. You may find the program and installation/configuration information here: https://www.snbforums.com/threads/vpnmgr-manage-and-update-vpn-client-configurations-for-nordvpn-and-pia.64930/
* VPNMON by default relies heavily on VPNON, though you can switch this out with any script of your choice to help reset your VPN connections.  Make sure you have copied over VPNON (https://github.com/ViktorJp/VPNON), and have placed it in your /jffs/scripts folder, named "vpnon.sh".

Disclaimer
----------
Use at your own risk.  I've been using this script successfully for a long time on an Asus RT-AC86U running Merlin FW v386.3_2 and v386.4, and seems to work just fine for my needs.
