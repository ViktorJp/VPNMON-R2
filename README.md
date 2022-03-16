# VPNMON-R2

**Executive Summary**: VPNMON-R2 v1.1 (VPNMON-R2.SH) is an all-in-one script which compliments @JackYaz's VPNMGR program to maintain a NordVPN/PIA/WeVPN setup, though this is not a requirement, and can function without problems in a standalone environment. This script checks the health of (up to) 5 VPN connections on a regular interval to see if one is connected, and sends a ping to a host of your choice through the active connection.  If it finds that connection has been lost, it will execute a series of commands that will kill all VPN clients, and optionally use VPNMGR's functionality to poll NordVPN/PIA/WeVPN for updated server names based on the locations you have selected in VPNMGR, optionally whitelists all US-based NordVPN servers in the Skynet Firewall, and randomly picks one of the 5 VPN Clients to connect to. Logging added to capture relevant events for later review.  As mentioned, disabling VPNMGR and Skynet functionality is completely supported should you be using other VPN options, and as such, this script would help maintain an eye on your connection, and able to randomly reset it if needed.

I am by no means a serious script programmer. I've combed through lots of code and examples found both on the Merlin FW discussion forums and online to cobble this stuff together. You will probably find inefficient code, or possibly shaking your head with the rudimentary ways I'm pulling things off... but hey, I'm learning, it's fun, and it works! ;)  Huge thanks and shoutouts to @JackYaz, @eibgrad and @Martineau for their inspiration and gorgeous looking code, and for everyone else that has helped me along the way on the Merlin forums: https://www.snbforums.com/forums/asuswrt-merlin.42/.  As always, a huge thank you and a lot of admiration also goes out to @RMerlin, @Adamm, @L&LD, @SomeWhereOverTheRainBow and @thelonelycoder for everything you've done for the community

The Problem I was trying to solve
---------------------------------
* As a VPNMGR user, I have 5 different NordVPN VPN Client configurations populated on my Asus router running Merlin FW, each with a different city.  There were times that I would lose connection to one of these servers, and the router would just endlessly keep trying to reconnect to no avail.  Also, sometimes the SKynet firewall would block these NordVPN endpoints, and it would again, endlessly try to connect to a blocked endpoint.  Other times, freakishly, I would have more than 1 VPN Client kick on for some reason.  This program was built as a way to check to make sure VPN is connected, that the connection is clean, and that there aren't multiple instances running.  If anything was off, it would launch a full-on assault and try to reset everything back to a normal state.
* I also wanted a way for my VPN connection to reset each night, so that it would randomly select and connect to a different configuration, thus endpoint, so that I wouldn't be connected to the same city 24x7x365.
* NordVPN literally has thousands of VPN endpoint servers which change frequently, depending on the distance or latency from your location scattered across the globe. On several occations, my Asus-Merlin-based Skynet firewall would block these VPN servers, and wanted to make sure I had a way to find all the latest VPN server IPs, and add them to the Skynet whitelist.
* Above all, I wanted to make this script flexible enough for those who aren't running VPNMGR, using NordVPN or making use of the Skynet Firewall, so options have been built-in to bypass this functionality to make it usable in any VPN usage scenario.

How is this script supposed to run?
-----------------------------------
Personally, I run this script in its own SSH window from a PC that's connected directly to the Asus router, as it loops and checks the connection every 60 seconds. Installation instructions:
1. Download and install from your favorite SSH tools, copy & paste this command:
   ``curl --retry 3 "https://raw.githubusercontent.com/ViktorJp/VPNMON-R2/master/vpnmon-r2-1.1.sh" -o "/jffs/scripts/vpnmon-r2.sh" && chmod a+rx "/jffs/scripts/vpnmon-r2.sh"``
2. To initially configure this script, open up a dedicated SSH window, and simply execute the script:
   ``sh /jffs/scripts/vpnmon-r2.sh -config``
3. Once you've successfully configured the various options, you can run the script using this command:
   ``sh /jffs/scripts/vpnmon-r2.sh -monitor``
   
One particular ingenious way to run this script is with the "screen" utility, which runs continuously from the router itself, instead of an attached session as suggested by @eibgrad.  

1. First, make sure you install the "screen" utility (and have Entware installed):
   ``opkg install screen``
2. The screen utility allows you to run the script in the background, detached from your current ssh session on the router itself. Type:
   ``screen -dmS vpnmonr2 sh /jffs/scripts/vpnmon-r2.sh -monitor``
3. You can then reattach to the running script at any time, from any ssh session, on any client machine! Type:
   ``screen -r vpnmonr2``
4. Perform the detach by hitting CTRL-A + D

What this script does
---------------------
1. Checks the VPN State from NVRAM and determines if each of the 5 Clients are connected or not
2. If a VPN Client is connected, it sends a PING through to Google's DNS server to determine if the link is good (configurable)
3. If it determines that the VPN Client is down, or connection is broken, it will attempt to reset the VPN
4. If it determines that multiple VPN Clients are running, it will attempt to reset the VPN
5. If it determines that the NordVPN server load is too high (optional), it will attempt to reset the VPN
6. Updates Skynet whitelist with all US-based NordVPN endpoint IP addresses (optional) - FYI, you can easily change this for the country of your choice.
7. Updates VPNMGR cache with recommended NordVPN/PIA/WeVPN endpoint information (optional), and merges/refreshes these changes with your VPN Client configurations
8. Uses a randomizer to pick one of 5 different VPN Clients to connect to (configurable between 1 and 5)
9. It will loop through this process every 60 seconds (configurable)
10. If it determines that my other (optional) external script VPNON.SH is resetting the connection, it will hang back until it's done.
11. Logs major events (resets/connection errors/etc) to a log file.
12. It will reset your VPN connection at a regularly scheduled time using the settings at the top of the script (optional)
13. It now shows the last time a VPN reset happened indicated by "Last Reset:", an indicator when the next reset will happen, and how often the interval happens (in seconds) on the easy-to-read VPNMON-R2 interface in your SSH shell, along with a progressbar to show script activity
14. Added a new API lookup to display the VPN exit node city/location next to the active VPN connection.  This API is free, and guarantees at least 1000 lookups per month.  In lieu of doing a lookup each single refresh interval, a location lookup is only done when either the script starts up fresh, when it detects VPNON doing a reset, or if VPNMON-R2 initiates a reset.
15. Added the concept of SuperRandom(tm) NordVPN Connections! This is a NordVPN feature only! When enabled, it will fill your VPN client slots with random VPN servers across the country of your choice.  Distance, load, and performance be damned!!
16. Added an integrated configuration utility (by running "vpnmon-r2.sh -config") that steps you through all the options and saves results to a config file, without the need to manually edit and configure the script itself.

What if I'm not running VPNMGR/NordVPN(PIA/WeVPN)/Skynet?
---------------------------------------------------------
* As long as your VPN slots are configured and tested using the VPN provider of your choice, this script will run perfectly fine, and can monitor, reset and randomly start a new VPN client slot for you each day.  Please know, this script was written to compliment VPNMGR, and gives a heavy preference to NordVPN, but neither is required.
* While stepping through the configuration utility ("vpnmon-r2.sh -config"), you can choose to disable the ability to update VPNMGR hosts, enable/disable specific NordVPN functionality, and the ability to whitelist the latest NordVPN servers in Skynet.
* Let me know how you're using this script!  Feel free to post in the forums. ;)
  Here: https://www.snbforums.com/threads/release-vpnmon-r2-a-script-that-monitors-your-vpn-connection.76748/

Usage
-------
VPNMON-R2 is driven with commandline parameters.  These are the available options:

* vpnmon-r2.sh -h (or vpnmon-r2.sh -help) -- displays a short overview of available commands 
* vpnmon-r2.sh -log -- displays the contents of the VPNMON-R2 activity log in the NANO text editor
* vpnmon-r2.sh -config -- launches the configuration utility and saves your settings to a local config file
* vpnmon-r2.sh -monitor -- launches VPNMON-R2 in a normal operations mode, ready to monitor the health of your VPN connections

Gotchas
-------
* If you want to make the integration with VPNMGR, please make sure you have installed VPNMGR, have populated your VPN slots with it, have tested refreshing its cache, and that you are able to successfully connect to your VPN provider before running this script. You may find the program and installation/configuration information here: https://www.snbforums.com/threads/v...ent-configurations-for-nordvpn-and-pia.64930/
* If you don't want to integrate with VPNMGR, or whitelist NordVPN IPs in your Skynet Firewall, etc... please choose to disable this functionality in the configuration utility ("vpnmon-r2.sh -config")
* Make sure you keep your VPN Client slots sequential... don't use 1, 2, and 4... for instance. Keep it to 1, 2, and 3.
* If you're using the NordVPN SuperRandom(tm) functionality, please be sure that each of your VPN slots are fully configured, as this function will only replace your "server address" IP and the "description" in NordVPN - [CITY] format. It is also important to disable the VPNMGR update so they don't conflict.

Disclaimer
----------
Use at your own risk.  I've been using this script successfully for a long time on an Asus RT-AC86U running Merlin FW v386.3_2, v386.4 and v386.5.  Please post any questions you may have to the forums (link below), and I will be happy to assist.

Links/Forums
----------
* VPNMON-R2 - https://www.snbforums.com/threads/release-vpnmon-r2-a-script-that-monitors-your-vpn-connection.76748/
* VPNON - https://www.snbforums.com/threads/release-vpnon-a-script-to-help-reset-and-randomize-your-vpn-connections.76742/
