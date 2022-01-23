# VPNMON

**Executive Summary**: VPNMON-R2 v0.5 (VPNMON-R2.SH) is an all-in-one simple script which compliments @JackYaz's VPNMGR program to maintain a NordVPN/PIA/WeVPN setup, though this is not a requirement, and can function without problems in a standalone environment. This script checks your (up to) 5 VPN connections on a regular interval to see if one is connected, and sends a ping to a host of your choice through the active connection.  If it finds that connection has been lost, it will execute a series of commands that will kill all VPN clients, and optionally use VPNMGR's functionality to poll NordVPN/PIA/WeVPN for updated server names based on the locations you have selected in VPNMGR, optionally whitelists all US-based NordVPN servers in the Skynet Firewall, and randomly picks one of the 5 VPN Clients to connect to. Logging added to capture relevant events for later review.  As mentioned, disabling VPNMGR and Skynet functionality is completely supported should you be using other VPN options, and as such, this script would help maintain an eye on your connection, and able to randomly reset it if needed.

I am by no means a serious script programmer. I've combed through lots of code and examples found both on the Merlin FW discussion forums and online to cobble this stuff together. You will probably find inefficient code, or possibly shaking your head with the rudimentary ways I'm pulling things off... but hey, I'm learning, and it works! ;)  Huge thanks and shoutouts to @JackYaz and @Martineau for their inspiration and gorgeous looking code, and for everyone else that has helped me along the way on the Merlin forums: https://www.snbforums.com/forums/asuswrt-merlin.42/.  As always, a huge thank you and a lot of admiration goes out to @RMerlin, @Adamm, @L&LD and @thelonelycoder for everything you've done for the community

The Problem I was trying to solve
---------------------------------
* As a VPNMGR user, I have 5 different NordVPN VPN Client configurations populated on my Asus router running Merlin FW, each with a different city.  There were times that I would lose connection to one of these servers, and the router would just endlessly keep trying to reconnect to no avail.  Also, sometimes the SKynet firewall would block these NordVPN endpoints, and it would again, endlessly try to connect to a blocked endpoint.  Other times, freakishly, I would have more than 1 VPN Client kick on for some reason.  This program was built as a way to check to make sure VPN is connected, that the connection is clean, and that there aren't multiple instances running.  If anything was off, it would launch a full-on assault using a second script, VPNON.SH, and reset everything back to a normal state.
* Above all, I wanted to make this script flexible enough for those who aren't running VPNMGR, using NordVPN or making use of the Skynet Firewall, so options have been built-in to bypass this functionality to make it usable in any VPN usage scenario.

How is this script supposed to run?
-----------------------------------
Personally, I run this script in its own SSH window from a PC that's connected directly to the Asus router, as it loops and checks the connection every 30 seconds. I suppose there's other ways to run this script, but I will leave that up to you.
1. Copy this script over into your /jffs/scripts folder, and make sure it's called/renamed to: "vpnmon-r2.sh"
2. To run this script, open up a dedicated SSH window, and simply execute the script:
   ``sh /jffs/scripts/vpnmon-r2.sh``
3. Optionally, you can make this script executable, from a command prompt, enter:
   ``chmod +x /jffs/scripts/vpnmon-r2.sh``

What this script does
---------------------
1. Checks the VPN State from NVRAM and determines if each of the 5 Clients are connected or not
2. If a VPN Client is connected, it sends a PING through to Google's DNS server to determine if the link is good (configurable)
3. If it determines that the VPN Client is down, or connection is broken, it will attempt to reset the VPN
4. If it determines that multiple VPN Clients are running, it will attempt to reset the VPN
5. Updates Skynet whitelist with all US-based NordVPN endpoint IP addresses (optional) - FYI, you can easily change this for the country of your choice.
6. Updates VPNMGR cache with recommended NordVPN/PIA/WeVPN endpoint information (optional), and merges/refreshes these changes with your Merlin VPN Client configurations
7. Uses a randomizer to pick one of 5 different VPN Clients to connect to (configurable between 1 and 5)
8. Initiates the connection to the specified VPN endpoint.
9. It will loop through this process every 30 seconds (configurable)
10. If it determines that my other (optional) external script VPNON.SH is resetting the connection, it will hang back until VPNON.SH is done.
11. Logs major events (resets/connection errors/etc) to /jffs/scripts/vpnmon-on.log (optional)
12. It will reset your VPN connection at a regularly scheduled time using the settings at the top of the script (optional)
13. Includes a timer to show when the last time VPN was reset, along with a spinner to show script activity
14. It now shows the last time a VPN reset happened indicated by "Last Reset:", an indicator when the next reset will happen, and how often the interval happens (in seconds) on the easy-to-read VPNMON-R2 interface in your SSH shell.

Gotchas
-------
* If you want to make the integration with VPNMGR, please make sure you have installed VPNMGR, have populated your VPN slots with it, have tested refreshing its cache, and that you are able to successfully connect to NordVPN before running this script. You may find the program and installation/configuration information here: https://www.snbforums.com/threads/v...ent-configurations-for-nordvpn-and-pia.64930/
* If you don't want to integrate with VPNMGR, or whitelist NordVPN IPs in your Skynet Firewall, please set/configure each of these options to 0 at the top of this script before running it.
* Make sure you configure the N=5 variable in VPNON to the same number of VPN Client slots you have configured.
* Make sure you keep your VPN Client slots sequential... don't use 1, 2, and 4... for instance. Keep it to 1, 2, and 3.

Disclaimer
----------
Use at your own risk.  I've been using this script successfully for a long time on an Asus RT-AC86U running Merlin FW v386.3_2 and v386.4, and seems to work just fine for my needs.
