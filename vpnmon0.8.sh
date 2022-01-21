#!/bin/sh

#VPNMON 0.8 (VPNMON.SH) is a simple script that accompanies my VPNON.SH script, which compliments @JackYaz's VPNMGR
#program to maintain a NordVPN setup. This script checks your 5 VPN connections on a regular interval to see if one
#is connected, and sends a ping to a host of your choice through the active connection.  If it finds that connection
#has been lost, it will execute the script of your choice (in this case, VPNON.SH), which will kill all VPN clients,
#and use VPNMGR's functionality to poll NordVPN for updated server names based on the locations you have selected in
#VPNMGR, and randomly picks one of the 5 VPN Clients to connect to. Logging has been added to capture relevant events
#for later review.


# User-Selectable Variables (Feel free to change)
TRIES=3                                 # Number of times to retry a ping - default = 3 tries
INTERVAL=30                             # How often it should check your VPN connections - default = 30 seconds
PINGHOST="8.8.8.8"                      # Which host you want to use to ping to determine if VPN connection is up
CALLSCRIPT="/jffs/scripts/vpnon.sh"     # This is my default script that resets VPN connections, and uses VPNMGR to
                                        # reassign new NordVPN connections
LOGFILE="/jffs/scripts/vpnmon-on.log"   # Logfile path/name that captures important date/time events - change to:
                                        # "/dev/null" to disable this functionality.

# System Variables (Do not change)
LOCKFILE="/jffs/scripts/VPNON-Lock.txt" # Predefined lockfile that VPNON.sh creates when it resets the VPN so that
                                        # VPNMON does not interfere and possibly causes another reset during a reset
connState="2"                           # Status = 2 means VPN is connected, 1 is connecting, and 0 is not connected
STATUS=0                                # Tracks whether or not a ping was successful
VPNCLCNT=0                              # Tracks to make sure there are not multiple connections running
CNT=0                                   # Counter
AVGPING=0                               # Average ping value
state1=0                                # Initialize the VPN connection states for VPN Clients 1-5
state2=0
state3=0
state4=0
state5=0
START=$(date +%s)                       # Start a timer to determine intervals of VPN resets

# Color variables
CBlack="\e[1;30m"
CRed="\e[1;31m"
CGreen="\e[1;32m"
InvGreen="\e[1;42m"
CYellow="\e[1;33m"
CBlue="\e[1;34m"
InvBlue="\e[1;44m"
CMagenta="\e[1;35m"
CCyan="\e[1;36m"
CWhite="\e[1;37m"
CClear="\e[0m"


#Display title/version
echo -e "\n${CGreen}VPNMON v0.8${CClear}\n"

while true; do

  #Testing to see if VPNON is currently running, and if so, hold off until it finishes
  while test -f "$LOCKFILE"; do
    echo -e "${CRed}VPNON is currently resetting the VPN. Trying again in 10 seconds...${CClear}\n"
    START=$(date +%s)
    sleep 10
  done

  # Calculate days, hours, minutes and seconds between VPN resets
  END=$(date +%s)
  SDIFF=$((END-START))
  LASTVPNRESET=$(printf '%dd %02dh:%02dm:%02ds\n' $(($SDIFF/86400)) $(($SDIFF%86400/3600)) $(($SDIFF%3600/60)) $(($SDIFF%60)))

  # Show the date and time
  echo -e "${CYellow}$(date) - Last Reset: ${InvBlue}$LASTVPNRESET${CClear}"

  # Determine if a VPN Client is active, first by getting the VPN state from NVRAM
  state1=$(nvram get vpn_client1_state)
  state2=$(nvram get vpn_client2_state)
  state3=$(nvram get vpn_client3_state)
  state4=$(nvram get vpn_client4_state)
  state5=$(nvram get vpn_client5_state)
  echo -e "${CCyan}VPN State 1:$state1 2:$state2 3:$state3 4:$state4 5:$state5${CClear}"

  # Check each connection to see if its active, and perform a PING... borrowed heavily + credit to @Martineau for this code
  #VPN1
  if [[ $state1 -eq $connState ]]
  then
        while [ $CNT -lt $TRIES ]; do
        ping -I tun11 -q -c 1 -W 2 $PINGHOST &> /dev/null
        RC=$?
        if [ $RC -eq 0 ];then
                    STATUS=1
                    VPNCLCNT=$((VPNCLCNT+1))
                    AVGPING=$(ping -I tun11 -c 1 $PINGHOST | awk -F'time=| ms' 'NF==3{print $(NF-1)}' | sort -rn)
                    echo -e "${CGreen}VPN1 Ping is alive | ||${CBlack}${InvGreen} $AVGPING ms ${CClear}${CGreen}|| | ${CClear}"
                    break
                else
                    sleep 1
                    CNT=$((CNT+1))

                    if [[ $CNT -eq $TRIES ]];then
                      STATUS=0
                      echo -e "${CRed}VPN1 Ping failed${CClear}"
                      echo -e "$(date) - VPNMON - VPN1 Ping failed" >> $LOGFILE
                    fi
                fi
        done
  else
      echo "VPN1 Disconnected"
  fi

  #VPN2
  if [[ $state2 -eq $connState ]]
  then
        while [ $CNT -lt $TRIES ]; do
        ping -I tun12 -q -c 1 -W 2 $PINGHOST &> /dev/null
        RC=$?
        if [ $RC -eq 0 ];then
                    STATUS=1
                    VPNCLCNT=$((VPNCLCNT+1))
                    AVGPING=$(ping -I tun12 -c 1 $PINGHOST | awk -F'time=| ms' 'NF==3{print $(NF-1)}' | sort -rn)
                    echo -e "${CGreen}VPN2 Ping is alive | ||${CBlack}${InvGreen} $AVGPING ms ${CClear}${CGreen}|| | ${CClear}"
                    break
                else
                    sleep 1
                    CNT=$((CNT+1))

                    if [[ $CNT -eq $TRIES ]];then
                      STATUS=0
                      echo -e "${CRed}VPN2 Ping failed${CClear}"
                      echo -e "$(date) - VPNMON - VPN2 Ping failed" >> $LOGFILE
                    fi
                fi
        done
  else
      echo "VPN2 Disconnected"
  fi

  #VPN3
  if [[ $state3 -eq $connState ]]
  then
        while [ $CNT -lt $TRIES ]; do
        ping -I tun13 -q -c 1 -W 2 $PINGHOST &> /dev/null
        RC=$?
        if [ $RC -eq 0 ];then
                    STATUS=1
                    VPNCLCNT=$((VPNCLCNT+1))
                    AVGPING=$(ping -I tun13 -c 1 $PINGHOST | awk -F'time=| ms' 'NF==3{print $(NF-1)}' | sort -rn)
                    echo -e "${CGreen}VPN3 Ping is alive | ||${CBlack}${InvGreen} $AVGPING ms ${CClear}${CGreen}|| | ${CClear}"
                    break
                else
                    sleep 1
                    CNT=$((CNT+1))

                    if [[ $CNT -eq $TRIES ]];then
                      STATUS=0
                      echo -e "${CRed}VPN3 Ping failed${CClear}"
                      echo -e "$(date) - VPNMON - VPN3 Ping failed" >> $LOGFILE
                    fi
                fi
        done
  else
      echo "VPN3 Disconnected"
  fi

  #VPN4
  if [[ $state4 -eq $connState ]]
  then
        while [ $CNT -lt $TRIES ]; do
        ping -I tun14 -q -c 1 -W 2 $PINGHOST &> /dev/null
        RC=$?
        if [ $RC -eq 0 ];then
                    STATUS=1
                    VPNCLCNT=$((VPNCLCNT+1))
                    AVGPING=$(ping -I tun14 -c 1 $PINGHOST | awk -F'time=| ms' 'NF==3{print $(NF-1)}' | sort -rn)
                    echo -e "${CGreen}VPN4 Ping is alive | ||${CBlack}${InvGreen} $AVGPING ms ${CClear}${CGreen}|| | ${CClear}"
                    break
                else
                    sleep 1
                    CNT=$((CNT+1))

                    if [[ $CNT -eq $TRIES ]];then
                      STATUS=0
                      echo -e "${CRed}VPN4 Ping failed${CClear}"
                      echo -e "$(date) - VPNMON - VPN4 Ping failed" >> $LOGFILE
                    fi
                fi
        done
  else
      echo "VPN4 Disconnected"
  fi

  #VPN5
  if [[ $state5 -eq $connState ]]
  then
        while [ $CNT -lt $TRIES ]; do
        ping -I tun15 -q -c 1 -W 2 $PINGHOST &> /dev/null
        RC=$?
        if [ $RC -eq 0 ];then
                    STATUS=1
                    VPNCLCNT=$((VPNCLCNT+1))
                    AVGPING=$(ping -I tun15 -c 1 $PINGHOST | awk -F'time=| ms' 'NF==3{print $(NF-1)}' | sort -rn)
                    echo -e "${CGreen}VPN5 Ping is alive | ||${CBlack}${InvGreen} $AVGPING ms ${CClear}${CGreen}|| | ${CClear}"
                    break
                else
                    sleep 1
                    CNT=$((CNT+1))

                    if [[ $CNT -eq $TRIES ]];then
                      STATUS=0
                      echo -e "${CRed}VPN5 Ping failed${CClear}"
                      echo -e "$(date) - VPNMON - VPN5 Ping failed" >> $LOGFILE
                    fi
                fi
        done
  else
      echo "VPN5 Disconnected"
  fi


  #If STATUS remains 0 then reset the VPN
    if [ $STATUS -eq 0 ]; then
        echo -e "${CRed}Connection has failed, VPNMON is executing script to reset VPN${CClear}"
        echo -e "$(date) - VPNMON - Connection failed, executing script to reset VPN" >> $LOGFILE
        sh $CALLSCRIPT

            while test -f "$LOCKFILE"; do
                echo -e "${CGreen}VPNON is currently resetting the VPN. Trying again in 10 seconds...${CClear}\n"
                sleep 10
            done

        echo -e "\n${CCyan}VPNMON is letting the VPN settle for 30 seconds${CClear}\n"
            sleep 30
        START=$(date +%s)
        echo -e "\n${CCyan}Resuming VPNMON in T minus $INTERVAL${CClear}\n"
        echo -e "$(date) - VPNMON - Resuming normal operations" >> $LOGFILE
    fi

  #If VPNCLCNT is greater than 1 there are multiple connections running, reset the VPN
    if [ $VPNCLCNT -gt 1 ]; then
        echo -e "${CRed}Multiple VPN Client Connections detected, VPNMON is executing script to reset VPN${CClear}"
        echo -e "$(date) - VPNMON - Multiple VPN Client Connections detected, executing script to reset VPN" >> $LOGFILE
        sh $CALLSCRIPT

            while test -f "$LOCKFILE"; do
                echo -e "${CGreen}VPNON is currently resetting the VPN. Trying again in 10 seconds...${CClear}\n"
                sleep 10
            done

        echo -e "\n${CCyan}VPNMON is letting the VPN settle for 30 seconds${CClear}\n"
            sleep 30
        START=$(date +%s)
        echo -e "\n${CCyan}Resuming VPNMON in T minus $INTERVAL ${CClear}\n"
        echo -e "$(date) - VPNMON - Resuming normal operations" >> $LOGFILE
    fi


echo -e "\r"

#Provide a spinner to show script continues to run
i=0
j=$((INTERVAL / 4))
while [ $i -le $j ]; do
  for s in / - \\ \|; do
    printf "\r$s"
    sleep 1
  done
  i=$((i+1))
done

printf "\r"

#sleep $INTERVAL

#Reset Variables
STATUS=0
VPNCLCNT=0
CNT=0
AVGPING=0
state1=0
state2=0
state3=0
state4=0
state5=0

done

exit 0
