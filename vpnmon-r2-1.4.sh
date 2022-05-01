#!/bin/sh

# VPNMON-R2 v1.4 (VPNMON-R2.SH) is an all-in-one simple script which compliments @JackYaz's VPNMGR program to maintain a
# NordVPN/PIA/WeVPN setup, though this is not a requirement, and can function without problems in a standalone environment.
# This script checks your (up to) 5 VPN connections on a regular interval to see if one is connected, and sends a ping to a
# host of your choice through the active connection.  If it finds that connection has been lost, it will execute a series of
# commands that will kill all VPN clients, and optionally use VPNMGR's functionality to poll NordVPN/PIA/WeVPN for updated
# server names based on the locations you have selected in VPNMGR, optionally whitelists all selected NordVPN servers in the
# Skynet Firewall, and randomly picks one of the 5 VPN Clients to connect to. Logging added to capture relevant events for
# later review.  As mentioned, disabling VPNMGR and Skynet functionality is completely supported should you be using other
# VPN options, and as such, this script would help maintain an eye on your connection, and able to randomly reset it if
# needed.

# -------------------------------------------------------------------------------------------------------------------------
# Usage and configuration Guide - *UPDATED*
# -------------------------------------------------------------------------------------------------------------------------
# All previous user-selectable options are now available through the Configuration Utility.  You may access and run this
# utility by running "vpnmon-r2.sh -config".  Once configured, a "vpnmon-r2.cfg" file will be written to your
# /jffs/addons/vpnmon-r2.d/ folder containing the options you have selected. Once everything looks good, you are able to
# run VPNMON-R2 for under normal monitoring conditions using this command: "vpnmon-r2.sh -monitor". Please note this change
# for any current automations you may have in place.  To easily view the log file, enter: "vpnmon-r2.sh -log".  You will be
# prompted as new updates become available going forward with v1.2.  Use "vpnmon-r2.sh -update" to update the script.

# -------------------------------------------------------------------------------------------------------------------------
# System Variables (Do not change beyond this point or this may change the programs ability to function correctly)
# -------------------------------------------------------------------------------------------------------------------------
Version="1.4"                                       # Current version of VPNMON-R2
DLVersion="0.0"                                     # Current version of VPNMON-R2 from source repository
LOCKFILE="/jffs/scripts/VPNON-Lock.txt"             # Predefined lockfile that VPNON.sh creates when it resets the VPN so
                                                    # that VPNMON-R2 does not interfere during a reset
RSTFILE="/jffs/addons/vpnmon-r2.d/vpnmon-rst.log"   # Logfile containing the last date/time a VPN reset was performed. Else,
                                                    # the latest date/time that VPNMON-R2 restarted will be shown.
LOGFILE="/jffs/addons/vpnmon-r2.d/vpnmon-r2.log"    # Logfile path/name that captures important date/time events - change
#LOGFILE="/dev/null"                                # to: "/dev/null" to disable this functionality.
APPPATH="/jffs/scripts/vpnmon-r2.sh"                # Path to the location of vpnmon-r2.sh
CFGPATH="/jffs/addons/vpnmon-r2.d/vpnmon-r2.cfg"    # Path to the location of vpnmon-r2.cfg
DLVERPATH="/jffs/addons/vpnmon-r2.d/version.txt"    # Path to downloaded version from the source repository
YAZFI_CONFIG_PATH="/jffs/addons/YazFi.d/config"     # Path to the YazFi guest network(s) config file
connState="2"                                       # Status = 2 means VPN is connected, 1 = connecting, 0 = not connected
let BASE=1                                          # Random numbers start at BASE up to N, ie. 1..3
STATUS=0                                            # Tracks whether or not a ping was successful
VPNCLCNT=0                                          # Tracks to make sure there are not multiple connections running
CURRCLNT=0                                          # Tracks which VPN client is currently active
CNT=0                                               # Counter
AVGPING=0                                           # Average ping value
SPIN=10                                             # 10-second Spin timer
state1=0                                            # Initialize the VPN connection states for VPN Clients 1-5
state2=0
state3=0
state4=0
state5=0
START=$(date +%s)                                   # Start a timer to determine intervals of VPN resets
VPNIP="Unassigned"                                  # Tracking VPN IP for city location display. API gives you 1K lookups
                                                    # per day, and is optimized to only lookup city location after a reset
VPNLOAD=0                                           # Variable tracks the NordVPN server load
AVGPING=0                                           # Variable tracks average ping time
PINGLOW=0                                           # Variable tracks lowest ping time
PINGHIGH=0                                          # Variable tracks highest ping time
SHOWSTATS=0                                         # Tracks whether you want to show stats on/off if you like minimalism
rxbytes=0                                            # Variables to capture and measure TX/RX rates on VPN Tunnel
txbytes=0
txrxbytes=0
rxgbytes=0
txgbytes=0
oldrxbytes=0
newrxbytes=0
oldtxbytes=0
newtxbytes=0

SyncYazFi=0                                         # Variables that track whether or not to sync the active VPN slot with
YF24GN1=0                                             # user-selectable YazFi guest networks
YF24GN2=0
YF24GN3=0
YF5GN1=0
YF5GN2=0
YF5GN3=0
YF52GN1=0
YF52GN2=0
YF52GN3=0

# Color variables
CBlack="\e[1;30m"
CRed="\e[1;31m"
InvRed="\e[1;41m"
CGreen="\e[1;32m"
InvGreen="\e[1;42m"
CYellow="\e[1;33m"
CBlue="\e[1;34m"
InvBlue="\e[1;44m"
CMagenta="\e[1;35m"
CCyan="\e[1;36m"
InvCyan="\e[1;46m"
CWhite="\e[1;37m"
CClear="\e[0m"

# -------------------------------------------------------------------------------------------------------------------------
# Functions
# -------------------------------------------------------------------------------------------------------------------------

# Logo is a function that displays the VPNMON-R2 script name in a cool ASCII font
logo () {
  echo -e "${CYellow} _    ______  _   ____  _______  _   __      ____ ___  "
  echo -e "| |  / / __ \/ | / /  |/  / __ \/ | / /     / __ \__ \ "
  echo -e "| | / / /_/ /  |/ / /|_/ / / / /  |/ /_____/ /_/ /_/ / "
  echo -e "| |/ / ____/ /|  / /  / / /_/ / /|  /_____/ _, _/ __/  "
  echo -e "|___/_/   /_/ |_/_/  /_/\____/_/ |_/     /_/ |_/____/  "
  echo ""
}

# -------------------------------------------------------------------------------------------------------------------------

# Promptyn is a function that helps return a 0 or 1 from a Y/N question from the configuration utility.
promptyn () {
    while true; do
        read -p "$1 " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# -------------------------------------------------------------------------------------------------------------------------

# Spinner is a script that provides a small indicator on the screen to show script activity
spinner() {

  i=0
  j=$((SPIN / 4))
  while [ $i -le $j ]; do
    for s in / - \\ \|; do
      printf "\r$s"
      sleep 1
    done
    i=$((i+1))
  done

  printf "\r"
}

# -------------------------------------------------------------------------------------------------------------------------

# Preparebar and Progressbar is a script that provides a nice progressbar to show script activity
preparebar() {
# $1 - bar length
# $2 - bar char
    barlen=$1
    barspaces=$(printf "%*s" "$1")
    barchars=$(printf "%*s" "$1" | tr ' ' "$2")
}

progressbar() {
# $1 - number (-1 for clearing the bar)
# $2 - max number
    if [ $1 -eq -1 ]; then
        printf "\r  $barspaces\r"
    else
        barch=$(($1*barlen/$2))
        barsp=$((barlen-barch))
        progr=$((100*$1/$2))
        printf "${CGreen}\r [%.${barch}s%.${barsp}s]${CClear} ${CYellow}${InvBlue}${i}s / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
    fi
}

# -------------------------------------------------------------------------------------------------------------------------

updatecheck () {

  # Download the latest version file from the source repository
  curl --silent --retry 3 "https://raw.githubusercontent.com/ViktorJp/VPNMON-R2/master/version.txt" -o "/jffs/addons/vpnmon-r2.d/version.txt"

  if [ -f $DLVERPATH ]
    then
      # Read in its contents for the current version file
      DLVersion=$(cat $DLVERPATH)

      # Compare the new version with the old version and log it
      if [ "$DLVersion" != "$Version" ]; then
          UpdateNotify="Update available: v$Version -> v$DLVersion"
          echo -e "$(date) - VPNMON-R2 - A new update (v$DLVersion) is available to download" >> $LOGFILE
        else
          UpdateNotify=0
      fi
  fi

}

# -------------------------------------------------------------------------------------------------------------------------

# VPNReset() is a script based on my VPNON.SH script to kill connections and reconnect to a clean VPN state
vpnreset() {

  # Start the VPN reset process
    echo -e "$(date) - VPNMON-R2 - Executing VPN Reset" >> $LOGFILE

  # Reset the VPN IP/Locations
    VPNIP="Unassigned"

  # Start the process
    echo -e "${CCyan}Step 1 - Kill all VPN Client Connections\n${CClear}"

  # Kill all current VPN client sessions
    echo -e "${CRed}Kill VPN Client 1${CClear}"
      service stop_vpnclient1
    echo -e "${CRed}Kill VPN Client 2${CClear}"
      service stop_vpnclient2
    echo -e "${CRed}Kill VPN Client 3${CClear}"
      service stop_vpnclient3
    echo -e "${CRed}Kill VPN Client 4${CClear}"
      service stop_vpnclient4
    echo -e "${CRed}Kill VPN Client 5${CClear}"
      service stop_vpnclient5
    echo -e "$(date) - VPNMON-R2 - Killed all VPN Client Connections" >> $LOGFILE

  # Determine if multiple countries need to be considered, and pick a random one
  if [[ $NordVPNMultipleCountries -eq 1 ]]
  then

    # Determine how many countries we're dealing with
    if [ -z "$NordVPNCountry2" ]
    then
          COUNTRYTOTAL2=0
    else
          COUNTRYTOTAL2=1
    fi

    if [ -z "$NordVPNCountry3" ]
    then
          COUNTRYTOTAL3=0
    else
          COUNTRYTOTAL3=1
    fi

    COUNTRYTOTAL=$(( COUNTRYTOTAL2 + $COUNTRYTOTAL3 + 1 ))

    # Generate a number between 1 and the total # of countries, to choose which country to connect to
      RANDOMCOUNTRY=$(awk 'BEGIN {srand(); print int(32768 * rand())}')
      COUNTRYNUM=$(( RANDOMCOUNTRY % $COUNTRYTOTAL + 1 ))

    # Set COUNTRYNUM to 1 in that rare case that it comes out to 0
      if [[ $COUNTRYNUM -eq 0 ]]
        then
        COUNTRYNUM=1
      fi

    # Pick and assign the selected NordVPN Country
      case ${COUNTRYNUM} in

        1)
            NordVPNRandomCountry=$NordVPNCountry
        ;;

        2)
            NordVPNRandomCountry=$NordVPNCountry2
        ;;

        3)
            NordVPNRandomCountry=$NordVPNCountry3
        ;;

      esac
      echo ""
      echo -e "\n${CCyan}Multi-Country Enabled - Randomly selected NordVPN Country: $NordVPNRandomCountry\n${CClear}"
      echo -e "$(date) - VPNMON-R2 - Randomly selected NordVPN Country: $NordVPNRandomCountry" >> $LOGFILE
  else
    NordVPNRandomCountry=$NordVPNCountry
  fi

  # Export NordVPN IPs via API into a txt file, and import them into Skynet
    if [[ $UpdateSkynet -eq 1 ]]
    then
      curl --silent --retry 3 "https://api.nordvpn.com/v1/servers?limit=16384" | jq --raw-output '.[] | select(.locations[].country.name == "'"$NordVPNRandomCountry"'") | .station' > /jffs/scripts/NordVPN.txt
      LINES=$(cat /jffs/scripts/NordVPN.txt | wc -l)  #Check to see how many lines/server IPs are in this file

      if [ $LINES -eq 0 ] # If there are no lines, error out
      then
        echo -e "\n${CRed}Step 2 - Error: NordVPN.txt list is blank! Check NordVPN service or config's Country Name.\n${CClear}"
        echo -e "$(date) - VPNMON-R2 ----------> ERROR: NordVPN.txt list is blank!" >> $LOGFILE
      else

        echo -e "\n${CCyan}Step 2 - Updating Skynet whitelist with NordVPN Server IPs\n${CClear}"

        firewall import whitelist /jffs/scripts/NordVPN.txt "NordVPN - $NordVPNRandomCountry"

        echo -e "\n${CCyan}VPNMON-R2 is letting Skynet import and settle for $SPIN seconds\n${CClear}"

          spinner

        echo -e "$(date) - VPNMON-R2 - Updated Skynet Whitelist" >> $LOGFILE
      fi
    else
      echo -e "\n${CCyan}Step 2 - Skipping Skynet whitelist update with NordVPN Server IPs\n${CClear}"
    fi

  # Randomly select VPN Client slots against entire field of available NordVPN server IPs for selected country
    if [[ $NordVPNSuperRandom -eq 1 ]]
    then
      UpdateVPNMGR=0 # Failsafe to make sure VPNMGR doesn't overwrite values written by the SuperRandom function

      if [ -f /jffs/scripts/NordVPN.txt ] # Check to see if NordVPN file exists from UpdateSkynet
      then
        LINES=$(cat /jffs/scripts/NordVPN.txt | wc -l)  # Check to see how many lines/server IPs are in this file

        if [ $LINES -eq 0 ] # If there are no lines, error out
        then
          echo -e "\n${CRed}Step 3 - Error: NordVPN.txt list is blank! Check NordVPN service or config's Country Name.\n${CClear}"
          echo -e "$(date) - VPNMON-R2 ----------> ERROR: NordVPN.txt list is blank!" >> $LOGFILE
          break
        fi

        echo -e "\n${CCyan}Step 3 - Updating VPN Slots 1 - $N from $LINES SuperRandom NordVPN Server IPs\n${CClear}"

        i=0
        while [[ $i -ne $N ]]  # Assign SuperRandom IPs/Descriptions to VPN Slots 1-N
          do
            i=$(($i+1))
            RANDOM=$(awk 'BEGIN {srand(); print int(32768 * rand())}')
            R_LINE=$(( RANDOM % LINES + 1 ))
            RNDVPNIP=$(sed -n "${R_LINE}p" /jffs/scripts/NordVPN.txt)
            RNDVPNCITY=$(curl --silent --retry 3 --request GET --url https://ipapi.co/$RNDVPNIP/city)
            nvram set vpn_client"$i"_addr="$RNDVPNIP"
            nvram set vpn_client"$i"_desc="NordVPN - $RNDVPNCITY"
            echo -e "\n${CGreen}VPN Slot $i - Assigned SuperRandom IP: $RNDVPNIP - City: $RNDVPNCITY\n${CClear}"
            sleep 1
        done
        echo -e "$(date) - VPNMON-R2 - Refreshed VPN Slots 1 - $N from $LINES SuperRandom NordVPN Server Locations" >> $LOGFILE

      else

        # NordVPN.txt must not exist and/or UpdateSkynet is turned off, so run API to get full server list from NordVPN
        curl --silent --retry 3 "https://api.nordvpn.com/v1/servers?limit=16384" | jq --raw-output '.[] | select(.locations[].country.name == "'"$NordVPNRandomCountry"'") | .station' > /jffs/scripts/NordVPN.txt
        LINES=$(cat /jffs/scripts/NordVPN.txt | wc -l) #Check to see how many lines/server IPs are in this file

        if [ $LINES -eq 0 ] #If there are no lines, error out
        then
          echo -e "\n${CRed}Step 3 - Error: NordVPN.txt list is blank! Check NordVPN service or config's Country Name.\n${CClear}"
          echo -e "$(date) - VPNMON-R2 ----------> ERROR: NordVPN.txt list is blank!" >> $LOGFILE
          break
        fi

        echo -e "\n${CCyan}Step 3 - Updating VPN Slots 1 - $N from $LINES SuperRandom NordVPN Server IPs\n${CClear}"

        i=0
        while [[ $i -ne $N ]] #Assign SuperRandom IPs/Descriptions to VPN Slots 1-N
          do
            i=$(($i+1))
            RANDOM=$(awk 'BEGIN {srand(); print int(32768 * rand())}')
            R_LINE=$(( RANDOM % LINES + 1 ))
            RNDVPNIP=$(sed -n "${R_LINE}p" /jffs/scripts/NordVPN.txt)
            RNDVPNCITY=$(curl --silent --retry 3 --request GET --url https://ipapi.co/$RNDVPNIP/city)
            nvram set vpn_client"$i"_addr="$RNDVPNIP"
            nvram set vpn_client"$i"_desc="NordVPN - $RNDVPNCITY"
            echo -e "\n${CGreen}VPN Slot $i - Assigned SuperRandom IP: $RNDVPNIP - City: $RNDVPNCITY\n${CClear}"
            sleep 1
        done
        echo -e "$(date) - VPNMON-R2 - Refreshed VPN Slots 1 - $N from $LINES SuperRandom NordVPN Server Locations" >> $LOGFILE
      fi
    else
      echo -e "\n${CCyan}Step 3 - Skipping update of SuperRandom NordVPN Server IPs\n${CClear}"
    fi

  # Clean up API VPN Server Extracts
    if [ -f /jffs/scripts/NordVPN.txt ]
    then
      rm /jffs/scripts/NordVPN.txt  #Cleanup
    fi

  # Call VPNMGR functions to refresh server lists and save their results to the VPN client configs
    if [[ $UpdateVPNMGR -eq 1 ]]
    then
          echo -e "${CCyan}Step 3 - Refresh VPNMGRs NordVPN/PIA/WeVPN Server Locations and Hostnames\n${CClear}"
          sh /jffs/scripts/service-event start vpnmgrrefreshcacheddata
            sleep 10
          sh /jffs/scripts/service-event start vpnmgr
            sleep 10
          echo -e "$(date) - VPNMON-R2 - Refreshed VPNMGR Server Locations and Hostnames" >> $LOGFILE
    else
          echo -e "\n${CCyan}Step 3 - Skipping VPNMGR update for NordVPN/PIA/WeVPN Server Locations and Hostname\n${CClear}"
    fi

  # Pick a random VPN Client to connect to
    echo -e "${CCyan}Step 4 - Randomly select a VPN Client between 1 and $N\n${CClear}"

  # Generate a number between BASE and N, ie.1 and 5 to choose which VPN Client is started
    RANDOM=$(awk 'BEGIN {srand(); print int(32768 * rand())}')
    option=$(( RANDOM % N + BASE ))

  # Set option to 1 in that rare case that it comes out to 0
    if [[ $option -eq 0 ]]
      then
      option=1
    fi

  # Start the selected VPN Client
    case ${option} in

      1)
          service start_vpnclient1
          logger -t VPN Client1 "Active"
          echo -e "${CGreen}VPN Client 1 ON\n${CClear}"
          echo -e "$(date) - VPNMON-R2 - Randomly selected VPN1 Client ON" >> $LOGFILE
      ;;

      2)
          service start_vpnclient2
          logger -t VPN Client2 "Active"
          echo -e "${CGreen}VPN Client 2 ON\n${CClear}"
          echo -e "$(date) - VPNMON-R2 - Randomly selected VPN2 Client ON" >> $LOGFILE
      ;;

      3)
          service start_vpnclient3
          logger -t VPN Client3 "Active"
          echo -e "${CGreen}VPN Client 3 ON\n${CClear}"
          echo -e "$(date) - VPNMON-R2 - Randomly selected VPN3 Client ON" >> $LOGFILE
      ;;

      4)
          service start_vpnclient4
          logger -t VPN Client4 "Active"
          echo -e "${CGreen}VPN Client 4 ON\n${CClear}"
          echo -e "$(date) - VPNMON-R2 - Randomly selected VPN4 Client ON" >> $LOGFILE
      ;;

      5)
          service start_vpnclient5
          logger -t VPN Client5 "Active"
          echo -e "${CGreen}VPN Client 5 ON\n${CClear}"
          echo -e "$(date) - VPNMON-R2 - Randomly selected VPN5 Client ON" >> $LOGFILE
      ;;

    esac

    # Optionally sync active VPN Slot with YazFi guest network(s)
    if [[ $SyncYazFi -eq 1 ]]
    then
      echo -e "${CCyan}YazFi Integration Enabled - Updating YazFi Guest Network(s) with current VPN Slot...\n${CClear}"

      if [ ! -f $YAZFI_CONFIG_PATH ]
        then
          echo ""
          echo -e "\n${CRed}Error: YazFi config was not located or YazFi is not installed. Unable to Proceed.\n${CClear}"
          echo -e "$(date) - VPNMON-R2 ----------> ERROR: YazFi config was not located or YazFi is not installed!" >> $LOGFILE
        else
          if [[ $YF24GN1 -eq 1 ]]
          then
            sed -i "s/^wl01_VPNCLIENTNUMBER=.*/wl01_VPNCLIENTNUMBER=$option/" "$YAZFI_CONFIG_PATH"
          fi

          if [[ $YF24GN2 -eq 1 ]]
          then
            sed -i "s/^wl02_VPNCLIENTNUMBER=.*/wl02_VPNCLIENTNUMBER=$option/" "$YAZFI_CONFIG_PATH"
          fi

          if [[ $YF24GN3 -eq 1 ]]
          then
            sed -i "s/^wl03_VPNCLIENTNUMBER=.*/wl03_VPNCLIENTNUMBER=$option/" "$YAZFI_CONFIG_PATH"
          fi

          if [[ $YF5GN1 -eq 1 ]]
          then
            sed -i "s/^wl11_VPNCLIENTNUMBER=.*/wl11_VPNCLIENTNUMBER=$option/" "$YAZFI_CONFIG_PATH"
          fi

          if [[ $YF5GN2 -eq 1 ]]
          then
            sed -i "s/^wl12_VPNCLIENTNUMBER=.*/wl12_VPNCLIENTNUMBER=$option/" "$YAZFI_CONFIG_PATH"
          fi

          if [[ $YF5GN3 -eq 1 ]]
          then
            sed -i "s/^wl13_VPNCLIENTNUMBER=.*/wl13_VPNCLIENTNUMBER=$option/" "$YAZFI_CONFIG_PATH"
          fi

          if [[ $YF52GN1 -eq 1 ]]
          then
            sed -i "s/^wl21_VPNCLIENTNUMBER=.*/wl21_VPNCLIENTNUMBER=$option/" "$YAZFI_CONFIG_PATH"
          fi

          if [[ $YF52GN2 -eq 1 ]]
          then
            sed -i "s/^wl22_VPNCLIENTNUMBER=.*/wl22_VPNCLIENTNUMBER=$option/" "$YAZFI_CONFIG_PATH"
          fi

          if [[ $YF52GN3 -eq 1 ]]
          then
            sed -i "s/^wl23_VPNCLIENTNUMBER=.*/wl23_VPNCLIENTNUMBER=$option/" "$YAZFI_CONFIG_PATH"
          fi

          #Apply settings to YazFi and get it to acknowledge changes for Guest Network Clients
          sh /jffs/scripts/YazFi runnow

          echo -e "$(date) - VPNMON-R2 - Successfully updated YazFi guest network(s) with the current VPN slot." >> $LOGFILE
        fi
    fi

    echo -e "${CCyan}VPNMON-R2 VPN Reset finished\n${CClear}"
    echo -e "$(date) - VPNMON-R2 - VPN Reset Finished" >> $LOGFILE

    # Check for any version updates from the source repository
    updatecheck

    # Reset Stats
    oldrxbytes=0
    oldtxbytes=0
    newrxbytes=0
    newtxbytes=0

}

# -------------------------------------------------------------------------------------------------------------------------

# checkvpn() is a script that checks each connection to see if its active, and performs a PING... borrowed
# heavily and much credit to @Martineau for this code from his VPN-Failover script. This piece right here
# is really how the whole VPNMON project got its start! :)

checkvpn() {

  CNT=0
  TUN="tun1"$1
  VPNSTATE=$2

  if [[ $VPNSTATE -eq $connState ]]
  then
        while [[ $CNT -lt $TRIES ]]; do
        ping -I $TUN -q -c 1 -W 2 $PINGHOST &> /dev/null
        RC=$?
        if [[ $RC -eq 0 ]];then
                    STATUS=1
                    VPNCLCNT=$((VPNCLCNT+1))
                    AVGPING=$(ping -I $TUN -c 1 $PINGHOST | awk -F'time=| ms' 'NF==3{print $(NF-1)}' | sort -rn)

                    if [[ $VPNIP == "Unassigned" ]];then
                      VPNIP=$(nvram get vpn_client$1_addr)
                      VPNCITY=$(curl --silent --retry 3 --request GET --url https://ipapi.co/$VPNIP/city)
                      echo -e "$(date) - VPNMON-R2 - API call made to update city to $VPNCITY" >> $LOGFILE
                    fi

                    echo -e "${CGreen}==VPN$1 Tunnel is active | ||${CWhite}${InvGreen} $AVGPING ms ${CClear}${CGreen}|| | ${CClear}${CYellow}Exit: ${InvBlue}$VPNCITY${CClear}"
                    CURRCLNT=$1
                    break
                else
                    sleep 1
                    CNT=$((CNT+1))

                    if [[ $CNT -eq $TRIES ]];then
                      STATUS=0
                      echo -e "${CRed}x-VPN$1 Ping failed${CClear}"
                      echo -e "$(date) - VPNMON-R2 - **VPN$1 Ping failed**" >> $LOGFILE
                    fi
                fi
        done
  else
      echo "- VPN$1 Disconnected"
  fi
}

# -------------------------------------------------------------------------------------------------------------------------
# Begin Commandline Argument Gatekeeper and Configuration Utility Functionality
# -------------------------------------------------------------------------------------------------------------------------

  # Create the necessary folder/file structure for VPNMON-R2 under /jffs/addons
  if [ ! -d "/jffs/addons/vpnmon-r2.d" ]; then
		mkdir -p "/jffs/addons/vpnmon-r2.d"
  fi

  # Check for Updates
    updatecheck

  # Check and see if any commandline option is being used
  if [ $# -eq 0 ]
    then
      clear
      echo ""
      echo "VPNMON-R2 v$Version"
      echo ""
      echo "Exiting due to missing commandline options!"
      echo "(run 'vpnmon-r2.sh -h' for help)"
      echo ""
      exit 0
  fi

  # Check and see if an invalid commandline option is being used
  if [ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "-config" ] || [ "$1" == "-monitor" ] || [ "$1" == "-log" ] || [ "$1" == "-update" ]
    then
      clear
    else
      clear
      echo ""
      echo "VPNMON-R2 v$Version"
      echo ""
      echo "Exiting due to invalid commandline options!"
      echo "(run 'vpnmon-r2.sh -h' for help)"
      echo ""
      exit 0
  fi

  # Check to see if the help option is being called
  if [ "$1" == "-h" ] || [ "$1" == "-help" ]
    then
    clear
    echo ""
    echo "VPNMON-R2 v$Version Commandline Option Usage:"
    echo ""
    echo "vpnmon-r2.sh -h | -help"
    echo "vpnmon-r2.sh -log"
    echo "vpnmon-r2.sh -config"
    echo "vpnmon-r2.sh -update"
    echo "vpnmon-r2.sh -monitor"
    echo ""
    echo " -h | -help (this output)"
    echo " -log (display the current log contents)"
    echo " -config (configuration/setup utility)"
    echo " -update (script update utility)"
    echo " -monitor (normal VPN monitoring operations)"
    echo ""
    exit 0
  fi

  # Check to see if the log option is being called, and display through nano
  if [ "$1" == "-log" ]
    then
      nano $LOGFILE
      exit 0
  fi

  # Check to see if the configuration option is being called, and run through setup utility
  if [ "$1" == "-config" ]
    then
    clear
    if [ -f $CFGPATH ] #Making sure file exists before proceeding
      then
        logo
        echo -e "VPNMON-R2 v$Version Configuration Utility${CClear}"
        echo ""
        echo -e "${CCyan}Please answer the following items to successfully configure VPNMON-R2."
        echo -e "${CCyan}This process is the same for a new installation, or if you wanted to"
        echo -e "${CCyan}configure VPNMON-R2 with new or different options. Upon completion,"
        echo -e "${CCyan}you have the option to overwrite an existing config file. Would you"
        echo -e "${CCyan}like to continue?${CClear}"
        if promptyn "(Yes/No) "; then
          echo ""
          echo -e "${CCyan}Continuing Setup...${CClear}"
          echo ""
        else
          echo ""
          echo -e "${CGreen}Exiting Configuration Utility...${CClear}"
          echo ""
          kill 0
        fi
        echo -e "${CCyan}1. How many times would you like a ping to retry your VPN tunnel before"
        echo -e "${CCyan}resetting? ${CYellow}(Default = 3)${CClear}"
        read -p 'Ping Retries: ' TRIES
        echo ""
        echo -e "${CCyan}2. What interval (in seconds) would you like to check your VPN tunnel"
        echo -e "${CCyan}to ensure the connection is healthy? ${CYellow}(Default = 60)${CClear}"
        read -p 'Interval: ' INTERVAL
        echo ""
        echo -e "${CCyan}3. What host IP would you like to ping to determine the health of your "
        echo -e "${CCyan}VPN tunnel? ${CYellow}(Default = 8.8.8.8)${CClear}"
        read -p 'Host IP: ' PINGHOST
        echo ""
        echo -e "${CCyan}4. Would you like to update VPNMGR? (Note: must be already installed "
        echo -e "${CCyan}and you must be NordVPN/PIA/WeVPN subscriber) ${CYellow}(Default = No)${CClear}"
        if promptyn "(Yes/No): "; then
          UpdateVPNMGR=1
        else
          UpdateVPNMGR=0
        fi
        echo ""
        echo -e "${CCyan}5. Is NordVPN your default VPN Provider? ${CYellow}(Default = No)${CClear}"
        if promptyn "(Yes/No): "; then
          UseNordVPN=1
        else
          UseNordVPN=0
        fi

        if [ "$UseNordVPN" == "1" ]; then
          echo ""
          echo -e "${CCyan}5a. Would you like to use the NordVPN SuperRandom functionality?"
          echo -e "${CYellow}(Default = No)${CClear}"
          if promptyn "(Yes/No): "; then
            NordVPNSuperRandom=1
          else
            NordVPNSuperRandom=0
          fi
          echo ""
          echo -e "${CCyan}5b. What Country is your country of origin for NordVPN? ${CYellow}(Default = "
          echo -e "${CYellow}United States). NOTE: Country names must be spelled correctly as below!"
          echo -e "${CCyan}Valid country names as follows: Albania, Argentina, Australia, Austria,"
          echo -e "${CCyan}Belgium, Bosnia and Herzegovina, Brazil, Bulgaria, Canada, Chile,"
          echo -e "${CCyan}Costa Rica, Croatia, Cyprus, Czech Republic, Denmark, Estonia, Finland,"
          echo -e "${CCyan}France, Georgia, Germany, Greece, Hong Kong, Hungary, Iceland, India,"
          echo -e "${CCyan}Indonesia, Ireland, Israel, Italy, Japan, Latvia, Lithuania, Luxembourg,"
          echo -e "${CCyan}Malaysia, Mexico, Moldova, Netherlands, New Zealand, North Macedonia,"
          echo -e "${CCyan}Norway, Poland, Portugal, Romania, Serbia, Singapore, Slovakia, Slovenia,"
          echo -e "${CCyan}South Africa, South Korea, Spain, Sweden, Switzerland, Taiwan, Thailand,"
          echo -e "${CCyan}Turkey, Ukraine, United Arab Emirates, United Kingdom, United States,"
          echo -e "Vietnam.${CClear}"
          read -p 'NordVPN Country: ' NordVPNCountry
          echo ""
          echo -e "${CCyan}5c. Would you like to randomize connections across multiple countries?"
          echo -e "${CCyan}NOTE: A maximum of 2 additional country names can be added. (Total of 3)"
          echo -e "${CYellow}(Default = No)${CClear}"
          if promptyn "(Yes/No): "; then
            NordVPNMultipleCountries=1
              echo ""
              read -p 'Enter Country #2 (Keep blank if not used): ' NordVPNCountry2
              echo ""
              read -p 'Enter Country #3 (Keep blank if not used): ' NordVPNCountry3
          else
            NordVPNMultipleCountries=0
            NordVPNCountry2=""
            NordVPNCountry3=""
          fi
          echo ""
          echo -e "${CCyan}5d. At what VPN server load would you like to reconnect to a different"
          echo -e "${CCyan}NordVPN Server? ${CYellow}(Default = 50)${CClear}"
          read -p 'Server Load Threshold: ' NordVPNLoadReset
          echo ""
          echo -e "${CCyan}5e. Would you like to whitelist NordVPN servers in the Skynet Firewall?"
          echo -e "${CYellow}(Default = No)${CClear}"
          if promptyn "(Yes/No): "; then
            UpdateSkynet=1
          else
            UpdateSkynet=0
          fi
        else
          NordVPNSuperRandom=0
          NordVPNCountry="United States"
          NordVPNLoadReset=50
          UpdateSkynet=0
        fi
        echo ""
        echo -e "${CCyan}6. Would you like to reset your VPN connection to a random VPN client"
        echo -e "${CCyan}daily? ${CYellow}(Default = Yes)${CClear}"
        if promptyn "(Yes/No): "; then
          ResetOption=1
          echo ""
          echo -e "${CCyan}6a. What time would you like to reset your connection?"
          echo -e "${CYellow}(Default = 01:00)${CClear}"
          read -p 'Reset Time (in HH:MM 24h): ' DailyResetTime
        else
          ResetOption=0
          DailyResetTime="00:00"
        fi
        echo ""
        echo -e "${CCyan}7. How many VPN client slots do you have properly configured? Please"
        echo -e "${CCyan}note: VPN client slots MUST be in sequential order, starting from 1"
        echo -e "${CCyan}through 5. (Example: if you are using slots 1, 2 and 3, but 4 and 5"
        echo -e "${CCyan}are disabled, you would enter 3. ${CYellow}(Default = 5)${CClear}"
        read -p 'VPN Clients: ' N
        echo ""
        echo -e "${CCyan}8. Would you like to show near-realtime VPN bandwidth stats on the UI?"
        echo -e "${CYellow}(Default = No)${CClear}"
        if promptyn "(Yes/No): "; then
          SHOWSTATS=1
        else
          SHOWSTATS=0
        fi
        echo ""
        echo -e "${CCyan}9. Would you like to sync the active VPN slot with YazFi?"
        echo -e "${CYellow}(Default = No)${CClear}"
        if promptyn "(Yes/No): "; then
          SyncYazFi=1
        else
          SyncYazFi=0
          YF24GN1=0
          YF24GN2=0
          YF24GN3=0
          YF5GN1=0
          YF5GN2=0
          YF5GN3=0
          YF52GN1=0
          YF52GN2=0
          YF52GN3=0
        fi
        if [ "$SyncYazFi" == "1" ]; then
          echo ""
          echo -e "${CCyan}9a. Please indicate which of your YazFi guest network slots you want to"
          echo -e "${CCyan}sync with the active VPN slot?"
          echo ""
          echo -e "${CYellow}2.4Ghz - Guest Network 1?${CClear}"
          if promptyn "(Yes/No): "; then
            YF24GN1=1
          else
            YF24GN1=0
          fi
          echo ""
          echo -e "${CYellow}2.4Ghz - Guest Network 2?${CClear}"
          if promptyn "(Yes/No): "; then
            YF24GN2=1
          else
            YF24GN2=0
          fi
          echo ""
          echo -e "${CYellow}2.4Ghz - Guest Network 3?${CClear}"
          if promptyn "(Yes/No): "; then
            YF24GN3=1
          else
            YF24GN3=0
          fi
          echo ""
          echo -e "${CYellow}5Ghz - Guest Network 1?${CClear}"
          if promptyn "(Yes/No): "; then
            YF5GN1=1
          else
            YF5GN1=0
          fi
          echo ""
          echo -e "${CYellow}5Ghz - Guest Network 2?${CClear}"
          if promptyn "(Yes/No): "; then
            YF5GN2=1
          else
            YF5GN2=0
          fi
          echo ""
          echo -e "${CYellow}5Ghz - Guest Network 3?${CClear}"
          if promptyn "(Yes/No): "; then
            YF5GN3=1
          else
            YF5GN3=0
          fi
          echo ""
          echo -e "${CYellow}5Ghz (Secondary) - Guest Network 1?${CClear}"
          if promptyn "(Yes/No): "; then
            YF52GN1=1
          else
            YF52GN1=0
          fi
          echo ""
          echo -e "${CYellow}5Ghz (Secondary) - Guest Network 2?${CClear}"
          if promptyn "(Yes/No): "; then
            YF52GN2=1
          else
            YF52GN2=0
          fi
          echo ""
          echo -e "${CYellow}5Ghz (Secondary) - Guest Network 3?${CClear}"
          if promptyn "(Yes/No): "; then
            YF52GN3=1
          else
            YF52GN3=0
          fi
        fi
        logo
        echo -e "${CCyan}Configuration of VPNMON-R2 is complete.  Would you like to save this config?${CClear}"
        if promptyn "(Yes/No): "; then
          { echo 'TRIES='$TRIES
            echo 'INTERVAL='$INTERVAL
            echo 'PINGHOST="'"$PINGHOST"'"'
            echo 'UpdateVPNMGR='$UpdateVPNMGR
            echo 'UseNordVPN='$UseNordVPN
            echo 'NordVPNSuperRandom='$NordVPNSuperRandom
            echo 'NordVPNMultipleCountries='$NordVPNMultipleCountries
            echo 'NordVPNCountry="'"$NordVPNCountry"'"'
            echo 'NordVPNCountry2="'"$NordVPNCountry2"'"'
            echo 'NordVPNCountry3="'"$NordVPNCountry3"'"'
            echo 'NordVPNLoadReset='$NordVPNLoadReset
            echo 'UpdateSkynet='$UpdateSkynet
            echo 'ResetOption='$ResetOption
            echo 'DailyResetTime="'"$DailyResetTime"'"'
            echo 'let N='$N
            echo 'SHOWSTATS='$SHOWSTATS
            echo 'SyncYazFi='$SyncYazFi
            echo 'YF24GN1='$YF24GN1
            echo 'YF24GN2='$YF24GN2
            echo 'YF24GN3='$YF24GN3
            echo 'YF5GN1='$YF5GN1
            echo 'YF5GN2='$YF5GN2
            echo 'YF5GN3='$YF5GN3
            echo 'YF52GN1='$YF52GN1
            echo 'YF52GN2='$YF52GN2
            echo 'YF52GN3='$YF52GN3
          } > $CFGPATH
            echo -e "$(date) - VPNMON-R2 - Successfully wrote a new config file" >> $LOGFILE
        else
            echo ""
            echo -e "${CGreen}Discarding changes and exiting setup.${CClear}"
            echo ""
            kill 0
        fi
        echo ""
        echo -e "${CYellow}Would you like to start VPNMON-R2 now?${CClear}"
        if promptyn "(Yes/No): "; then
          sh $APPPATH -monitor
        else
          echo ""
          echo -e "${CGreen}Execute VPNMON-R2 using command 'vpnmon-r2.sh -monitor' for normal operations${CClear}"
          echo ""
          kill 0
        fi
      else
        #Create a new config file with default values to get it to a basic running state
        { echo 'TRIES=3'
          echo 'INTERVAL=60'
          echo 'PINGHOST="8.8.8.8"'
          echo 'UpdateVPNMGR=0'
          echo 'UseNordVPN=0'
          echo 'NordVPNSuperRandom=0'
          echo 'NordVPNMultipleCountries=0'
          echo 'NordVPNCountry="United States"'
          echo 'NordVPNCountry2=0'
          echo 'NordVPNCountry3=0'
          echo 'NordVPNLoadReset=50'
          echo 'UpdateSkynet=0'
          echo 'ResetOption=1'
          echo 'DailyResetTime="01:00"'
          echo 'let N=5'
          echo 'SHOWSTATS=0'
          echo 'SyncYazFi=0'
          echo 'YF24GN1=0'
          echo 'YF24GN2=0'
          echo 'YF24GN3=0'
          echo 'YF5GN1=0'
          echo 'YF5GN2=0'
          echo 'YF5GN3=0'
          echo 'YF52GN1=0'
          echo 'YF52GN2=0'
          echo 'YF52GN3=0'
        } > $CFGPATH

        #Re-run vpnmon-r2 -config to restart setup process
        sh $APPPATH -config
    fi
  fi

  # Check to see if the update option is being called
  if [ "$1" == "-update" ]
    then
      # Check for the latest version from source repository
      updatecheck
      clear
      logo
      echo -e "VPNMON-R2 v$Version Update Utility${CClear}"
      echo ""
      echo -e "${CCyan}Current Version: ${CYellow}$Version${CClear}"
      echo -e "${CCyan}Updated Version: ${CYellow}$DLVersion${CClear}"
      echo ""
      if [ "$Version" == "$DLVersion" ]
        then
          echo -e "${CGreen}No update available.  Exiting Update Utility...${CClear}"
          echo ""
          kill 0
        else
          echo -e "${CCyan}Would you like to update to the latest version?${CClear}"
          if promptyn "(Yes/No): "; then
            echo ""
            echo -e "${CCyan}Updating VPNMON-R2 to ${CYellow}v$DLVersion${CClear}"
            curl --silent --retry 3 "https://raw.githubusercontent.com/ViktorJp/VPNMON-R2/master/vpnmon-r2-$DLVersion.sh" -o "/jffs/scripts/vpnmon-r2.sh" && chmod a+rx "/jffs/scripts/vpnmon-r2.sh"
            echo ""
            echo -e "${CCyan}Update successful!${CClear}"
            echo -e "$(date) - VPNMON-R2 - Successfully updated VPNMON-R2 from v$Version to v$DLVersion" >> $LOGFILE
          else
            echo ""
            echo -e "${CGreen}Exiting Update Utility...${CClear}"
            echo ""
            kill 0
          fi
          echo ""
          echo -e "${CYellow}Would you like to start VPNMON-R2 now?${CClear}"
          if promptyn "(Yes/No): "; then
            sh $APPPATH -monitor
          else
            echo ""
            echo -e "${CGreen}Execute VPNMON-R2 using command 'vpnmon-r2.sh -monitor' for normal operations${CClear}"
            echo ""
            kill 0
          fi
      fi
  fi

  # Check to see if the monitor option is being called and run operations normally
  if [ "$1" == "-monitor" ]
    then
    clear
    if [ -f $CFGPATH ]; then
      source $CFGPATH
    else
      echo -e "${CRed}Error: VPNMON-R2 is not configured.  Please run 'vpnmon-r2.sh -config' to complete setup${CClear}"
      echo ""
      echo -e "$(date) - VPNMON-R2 ----------> ERROR: vpnmon-r2.cfg was not found. Please run the configuration tool." >> $LOGFILE
      kill 0
    fi
  fi

# -------------------------------------------------------------------------------------------------------------------------
# Begin VPNMON-R2 Main Loop
# -------------------------------------------------------------------------------------------------------------------------

#DEBUG=; set -x # uncomment/comment to enable/disable debug mode
#{              # uncomment/comment to enable/disable debug mode

while true; do

  # Testing to see if a VPN Reset Date/Time Logfile exists or not, and if not, creates one
    if [ -f $RSTFILE ]
      then
          #Read in its contents for the date/time of last reset
          START=$(cat $RSTFILE)
      else
          #Create a new file with a new date/time of when VPNMON-R2 restarted, not sure when VPN last reset
          echo -e "$(date +%s)" > $RSTFILE
          START=$(cat $RSTFILE)
    fi

  # Testing to see if VPNON is currently running, and if so, hold off until it finishes
    while test -f "$LOCKFILE"; do
      # clear screen
        clear && clear

        echo -e "${CRed}VPNON is currently performing a scheduled reset of the VPN. Trying to reconnect every $SPIN seconds...${CClear}\n"
        echo -e "$(date +%s)" > $RSTFILE
        START=$(cat $RSTFILE)
        spinner

      # Reset the VPN IP/Locations
        VPNIP="Unassigned"
        PINGLOW=0 # Reset ping time history variables
        PINGHIGH=0
        oldrxbytes=0 # Reset Stats
        oldtxbytes=0
        newrxbytes=0
        newtxbytes=0
    done

  # Testing to see if a reset needs to run at the scheduled time, first by pulling our hair out to find a timeslot to
  # run this thing, by looking at current time and the scheduled time, converting to epoch seconds, and seeing if it
  # falls between scheduled time + 2 * the number of interval seconds, to ensure there's enough of a gap to check for
  # this if it happens to be in a sleep loop.

    if [[ $ResetOption -eq 1 ]]
      then
        currentepoch=$(date +%s)
        ConvDailyResetTime=$(date -d $DailyResetTime +%H:%M)
        ConvDailyResetTimeEpoch=$(date -d $ConvDailyResetTime +%s)
        variance=$(( $ConvDailyResetTimeEpoch + (( $INTERVAL*2 ))))

        # If the configured time is within 2 minutes of the current time, reset the VPN connection
        if [[ $currentepoch -gt $ConvDailyResetTimeEpoch && $currentepoch -lt $variance ]]
          then
            echo -e "\n\n${CCyan}VPNMON-R2 is executing a scheduled VPN Reset${CClear}\n"
            echo -e "$(date) - VPNMON-R2 - Executing scheduled VPN Reset" >> $LOGFILE

            vpnreset

            echo -e "\n${CCyan}Resuming VPNMON-R2 in T minus $INTERVAL${CClear}\n"
            echo -e "$(date) - VPNMON-R2 - Resuming normal operations" >> $LOGFILE
            echo -e "$(date +%s)" > $RSTFILE
            START=$(cat $RSTFILE)

            # Provide a progressbar to show script activity
              i=0
              while [[ $i -le $INTERVAL ]]
              do
                  preparebar 51 "|"
                  progressbar $i $INTERVAL
                  sleep 1
                  i=$(($i+1))
              done

              PINGLOW=0 # Reset ping time history variables
              PINGHIGH=0
              oldrxbytes=0 # Reset Stats
              oldtxbytes=0
              newrxbytes=0
              newtxbytes=0
       fi
    fi

  # Calculate days, hours, minutes and seconds between VPN resets
    END=$(date +%s)
    SDIFF=$((END-START))
    LASTVPNRESET=$(printf '%dd %02dh:%02dm:%02ds\n' $(($SDIFF/86400)) $(($SDIFF%86400/3600)) $(($SDIFF%3600/60)) $(($SDIFF%60)))

  # clear screen
    clear && clear
    #printf "\033c"

  # Display title/version
    echo -e "${CYellow}   _    ______  _   ____  _______  _   __      ____ ___  "
    echo -e "  | |  / / __ \/ | / /  |/  / __ \/ | / /     / __ \__ \ "
    echo -e "  | | / / /_/ /  |/ / /|_/ / / / /  |/ /_____/ /_/ /_/ / "
    echo -e "  | |/ / ____/ /|  / /  / / /_/ / /|  /_____/ _, _/ __/  "
    echo -e "  |___/_/   /_/ |_/_/  /_/\____/_/ |_/     /_/ |_/____/  ${CGreen}v$Version${CClear}"

    # Display update notification if an update becomes available through source repository

    if [[ "$UpdateNotify" != "0" ]]; then
      echo -e "${CRed}  $UpdateNotify${CClear}"
      echo ""
    else
      echo ""
    fi

  # Show the date and time
    echo -e "${CYellow}$(date) -------- Last Reset: ${InvBlue}$LASTVPNRESET${CClear}"

  # Determine if a VPN Client is active, first by getting the VPN state from NVRAM
    state1=$(nvram get vpn_client1_state)
    state2=$(nvram get vpn_client2_state)
    state3=$(nvram get vpn_client3_state)
    state4=$(nvram get vpn_client4_state)
    state5=$(nvram get vpn_client5_state)

  # Display the VPN states along with scheduled reset time/interval seconds
    if [[ $ResetOption -eq 1 ]]
      then
        echo -e "${CCyan}VPN State 1:$state1 2:$state2 3:$state3 4:$state4 5:$state5${CClear}${CYellow} ------ Sched Reset: ${InvBlue}$ConvDailyResetTime${CClear}${CYellow} / ${InvBlue}$INTERVAL Sec${CClear}"
      else
        echo -e "${CCyan}VPN State 1:$state1 2:$state2 3:$state3 4:$state4 5:$state5${CClear}${CYellow} --------- Interval: ${InvBlue}$INTERVAL Sec${CClear}"
    fi

    echo -e "${CGreen}-----------------------------------------------------------------${CClear}"

  # Cycle through the CheckVPN connection function for N number of VPN Clients
    i=0
    while [[ $i -ne $N ]]
      do
        i=$(($i+1))
        checkvpn $i $((state$i))
    done

    echo -e "${CGreen}-----------------------------------------------------------------${CClear}"

  # Determine whether to show all the stats based on user preference
  if [[ $SHOWSTATS == "1" ]]
    then

    # Keep track of Ping history stats and display skynet and randomizer methodology
    if [[ ${PINGLOW%.*} -eq 0 ]]
      then
        PINGLOW=${AVGPING%.*}
      elif [[ ${AVGPING%.*} -lt ${PINGLOW%.*} ]]
      then
        PINGLOW=${AVGPING%.*}
    fi

    if [[ ${PINGHIGH%.*} -eq 0 ]]
      then
        PINGHIGH=${AVGPING%.*}
      elif [[ ${AVGPING%.*} -gt ${PINGHIGH%.*} ]]
      then
        PINGHIGH=${AVGPING%.*}
    fi

    if [[ $UpdateVPNMGR -eq 1 ]]
      then
        RANDOMMETHOD="VPNMGR"
      elif [[ $NordVPNSuperRandom -eq 1 ]]
        then
          RANDOMMETHOD="NordVPN SuperRandom"
      else
        RANDOMMETHOD="Standard"
    fi

    if [[ $NordVPNSuperRandom -eq 1 ]] || [[ $UseNordVPN -eq 1 ]]
      then
        # Get the NordVPN server load - thanks to @JackYaz for letting me borrow his code from VPNMGR to accomplish this! ;)
        printf "${CYellow}\r[Checking NordVPN Server Load]..."
        VPNLOAD=$(curl --silent --retry 3 "https://api.nordvpn.com/v1/servers?limit=16354" | jq '.[] | select(.station == "'"$VPNIP"'") | .load')
        printf "\r"
    fi

    if [ -z "$VPNLOAD" ]; then VPNLOAD=0; fi # On that rare occasion where it's unable to get the NordVPN load, assign 0

    # Display some of the NordVPN-specific stats
    if [[ $NordVPNSuperRandom -eq 1 ]] || [[ $UseNordVPN -eq 1 ]]
      then
        echo -e "${CYellow}Ping Lo:${CWhite}${InvGreen}$PINGLOW${CClear}${CYellow} Hi:${CWhite}${InvRed}$PINGHIGH${CClear}${CYellow} ms | Load: ${InvBlue} $VPNLOAD % ${CClear}${CYellow} | Config: ${InvBlue}$RANDOMMETHOD${CClear}"

        # Display the high/low ping times, and for non-NordVPN customers, whether Skynet update is enabled.
        elif [[ $UpdateSkynet -eq 0 ]]
        then
          echo -e "${CYellow}Ping Lo:${CWhite}${InvGreen}$PINGLOW${CClear}${CYellow} Hi:${CWhite}${InvRed}$PINGHIGH${CClear}${CYellow} ms | Config: ${InvBlue}$RANDOMMETHOD${CClear}"
        else
          echo -e "${CYellow}Ping Lo:${CWhite}${InvGreen}$PINGLOW${CClear}${CYellow} Hi:${CWhite}${InvRed}$PINGHIGH${CClear}${CYellow} ms | Skynet: ${InvBlue}[Y]${CClear}${CYellow} | Config: ${InvBlue}$RANDOMMETHOD${CClear}"
    fi

    # Grab total bytes VPN Traffic Measurement
    txrxbytes=$(awk -F',' '1 == /TUN\/TAP read bytes/ {print $2} 1 == /TUN\/TAP write bytes/ {print $2}' /tmp/etc/openvpn/client$CURRCLNT/status 2>/dev/null)
    rxbytes="$(echo $txrxbytes | cut -d' ' -f1)"
    txbytes="$(echo $txrxbytes | cut -d' ' -f2)"

    # Assign the latest RX and TX bytes to the new counter
    newrxbytes=$rxbytes
    newtxbytes=$txbytes

    # Calculations to find the difference between old and new total bytes send/received and divided to give Megabits
    diffrxbytes=$(awk -v new=$newrxbytes -v old=$oldrxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    difftxbytes=$(awk -v new=$newtxbytes -v old=$oldtxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')

    # Results are further divided by the timer/interval to give Megabits/sec
    rxmbrate=$(awk -v rb=$diffrxbytes -v intv=$INTERVAL 'BEGIN{printf "%0.2f\n", rb/intv}')
    txmbrate=$(awk -v tb=$difftxbytes -v intv=$INTERVAL 'BEGIN{printf "%0.2f\n", tb/intv}')

    # Total bytes sent/received are divided to give total TX/RX Gigabytes
    rxgbytes=$(awk -v rx=$rxbytes -v gb=1073741824 'BEGIN{printf "%0.2f\n", rx/gb}')
    txgbytes=$(awk -v tx=$txbytes -v gb=1073741824 'BEGIN{printf "%0.2f\n", tx/gb}')

    # If stats are just fresh due to a start or reset, then wait until stats are there to display
    # NOTE: after extensive testing, it seems that the RX and TX values are reversed in the OpenVPN status file, so I am reversing these below
    # NOTE2: This is by design... not a clumsy coding mistake!  :)

    if [[ "$oldrxbytes" == "0" ]] || [[ "$oldtxbytes" == "0" ]]
      then
        # Still gathering stats
        echo -e "${CYellow}[Gathering VPN RX and TX Stats]... | Ttl RX:${InvBlue}$txgbytes GB${CClear} ${CYellow}TX:${InvBlue}$rxgbytes GB${CClear}"
      else
        # Display current avg rx/tx rates and total rx/tx bytes for active VPN tunnel.
        echo -e "${CYellow}Avg RX:${InvBlue}$txmbrate Mbps${CClear}${CYellow} TX:${InvBlue}$rxmbrate Mbps${CClear}${CYellow} | Ttl RX:${InvBlue}$txgbytes GB${CClear} ${CYellow}TX:${InvBlue}$rxgbytes GB${CClear}"
    fi

    echo -e "${CGreen}-----------------------------------------------------------------${CClear}"

    #VPN Traffic Measurement assignment of newest bytes to old counter before timer kicks off again
    oldrxbytes=$newrxbytes
    oldtxbytes=$newtxbytes

  fi

  # -------------------------------------------------------------------------------------------------------------------------
  # Check for 3 major reset scenarios - (1) Lost connection, (2) Multiple connections, or (3) High VPN Server Load, and reset
  # -------------------------------------------------------------------------------------------------------------------------

  # If STATUS remains 0 then we've lost our connection, reset the VPN
    if [[ $STATUS -eq 0 ]]; then
        echo -e "\n${CRed}Connection has failed, VPNMON-R2 is executing VPN Reset${CClear}\n"
        echo -e "$(date) - VPNMON-R2 - **Connection failed** - Executing VPN Reset" >> $LOGFILE

        vpnreset

        echo -e "\n${CCyan}Resuming VPNMON-R2 in T minus $INTERVAL${CClear}\n"
        echo -e "$(date) - VPNMON-R2 - Resuming normal operations" >> $LOGFILE
        echo -e "$(date +%s)" > $RSTFILE
        START=$(cat $RSTFILE)
        PINGLOW=0 # Reset ping time history variables
        PINGHIGH=0
        oldrxbytes=0 # Reset Stats
        oldtxbytes=0
        newrxbytes=0
        newtxbytes=0
    fi

  # If VPNCLCNT is greater than 1 there are multiple connections running, reset the VPN
    if [[ $VPNCLCNT -gt 1 ]]; then
        echo -e "\n${CRed}Multiple VPN Client Connections detected, VPNMON-R2 is executing VPN Reset${CClear}\n"
        echo -e "$(date) - VPNMON-R2 - **Multiple VPN Client Connections detected** - Executing VPN Reset" >> $LOGFILE

        vpnreset

        echo -e "\n${CCyan}Resuming VPNMON-R2 in T minus $INTERVAL ${CClear}\n"
        echo -e "$(date) - VPNMON-R2 - Resuming normal operations" >> $LOGFILE
        echo -e "$(date +%s)" > $RSTFILE
        START=$(cat $RSTFILE)
        PINGLOW=0 # Reset ping time history variables
        PINGHIGH=0
        oldrxbytes=0 # Reset Stats
        oldtxbytes=0
        newrxbytes=0
        newtxbytes=0
    fi

  # If the NordVPN Server load is greater than the set variable, reset the VPN and hopefully find a better server
    if [[ $NordVPNLoadReset -le $VPNLOAD ]]; then
        echo -e "\n${CRed}NordVPN Server Load is higher than $NordVPNLoadReset %, VPNMON-R2 is executing VPN Reset${CClear}\n"
        echo -e "$(date) - VPNMON-R2 - **NordVPN Server Load is higher than $NordVPNLoadReset %** - Executing VPN Reset" >> $LOGFILE

        vpnreset

        echo -e "\n${CCyan}Resuming VPNMON-R2 in T minus $INTERVAL ${CClear}\n"
        echo -e "$(date) - VPNMON-R2 - Resuming normal operations" >> $LOGFILE
        echo -e "$(date +%s)" > $RSTFILE
        START=$(cat $RSTFILE)
        PINGLOW=0 # Reset ping time history variables
        PINGHIGH=0
        oldrxbytes=0 # Reset Stats
        oldtxbytes=0
        newrxbytes=0
        newtxbytes=0
    fi

  # Provide a progressbar to show script activity
    i=0
    while [[ $i -le $INTERVAL ]]
    do
        preparebar 51 "|"
        progressbar $i $INTERVAL
        sleep 1
        i=$(($i+1))
    done

    #VPN Traffic Measurement after timer
    txrxbytes=$(awk -v var3="$rxbytes" -v var4="$txbytes" -F',' '1 == /TUN\/TAP read bytes/ {print $2} 1 == /TUN\/TAP write bytes/ {print $2}' /tmp/etc/openvpn/client$CURRCLNT/status 2>/dev/null)
    rxbytes="$(echo $txrxbytes | cut -d' ' -f1)"
    txbytes="$(echo $txrxbytes | cut -d' ' -f2)"
    newrxbytes=$rxbytes
    newtxbytes=$txbytes

    #read -rsp $'Press any key to continue...\n' -n1 key

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

#} #2>&1 | tee $LOG | logger -t $(basename $0)[$$]  # uncomment/comment to enable/disable debug mode
