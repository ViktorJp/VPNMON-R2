#!/bin/sh

# VPNMON-R2 v1.91 (VPNMON-R2.SH) is an all-in-one shell script which compliments @JackYaz's VPNMGR program to maintain a
# NordVPN/PIA/WeVPN setup, though this is not a requirement, and can function without problems in a standalone environment.
# This script checks your (up to) 5 VPN connections on a regular interval to see if one is connected, and sends a ping to a
# host of your choice through the active connection.  If it finds that connection has been lost, it will execute a series of
# commands that will kill all VPN clients, and optionally use VPNMGR's to poll NordVPN/PIA/WeVPN for updated
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
# prompted as new updates become available going forward with v1.2.  Use "vpnmon-r2.sh -update" to update the script. If
# you want to learn about other functions, use "vpnmon-r2.sh -h or -help".

# -------------------------------------------------------------------------------------------------------------------------
# Shellcheck exclusions
# -------------------------------------------------------------------------------------------------------------------------
# shellcheck disable=SC2034
# shellcheck disable=SC3037
# shellcheck disable=SC2162
# shellcheck disable=SC3045
# shellcheck disable=SC2183
# shellcheck disable=SC2086
# shellcheck disable=SC3014
# shellcheck disable=SC2059
# shellcheck disable=SC2002
# shellcheck disable=SC2004
# shellcheck disable=SC3028
# shellcheck disable=SC2140
# shellcheck disable=SC3046
# shellcheck disable=SC1090

# -------------------------------------------------------------------------------------------------------------------------
# System Variables (Do not change beyond this point or this may change the programs ability to function correctly)
# -------------------------------------------------------------------------------------------------------------------------
Version="1.91"                                      # Current version of VPNMON-R2
DLVersion="0.0"                                     # Current version of VPNMON-R2 from source repository
Beta=0                                              # Beta Testmode on/off
LOCKFILE="/jffs/scripts/VPNON-Lock.txt"             # Predefined lockfile that VPNON.sh creates when it resets the VPN so
                                                    # that VPNMON-R2 does not interfere during a reset
RSTFILE="/jffs/addons/vpnmon-r2.d/vpnmon-rst.log"   # Logfile containing the last date/time a VPN reset was performed. Else,
                                                    # the latest date/time that VPNMON-R2 restarted will be shown.
PERSIST="/jffs/addons/vpnmon-r2.d/persist.log"      # Logfile containing a persistence date/time log
LOGFILE="/jffs/addons/vpnmon-r2.d/vpnmon-r2.log"    # Logfile path/name that captures important date/time events - change
APPPATH="/jffs/scripts/vpnmon-r2.sh"                # Path to the location of vpnmon-r2.sh
CFGPATH="/jffs/addons/vpnmon-r2.d/vpnmon-r2.cfg"    # Path to the location of vpnmon-r2.cfg
DLVERPATH="/jffs/addons/vpnmon-r2.d/version.txt"    # Path to downloaded version from the source repository
YAZFI_CONFIG_PATH="/jffs/addons/YazFi.d/config"     # Path to the YazFi guest network(s) config file
connState="2"                                       # Status = 2 means VPN is connected, 1 = connecting, 0 = not connected
BASE=1                                              # Random numbers start at BASE up to N, ie. 1..3
STATUS=0                                            # Tracks whether or not a ping was successful
VPNCLCNT=0                                          # Tracks to make sure there are not multiple connections running
CURRCLNT=0                                          # Tracks which VPN client is currently active
CNT=0                                               # Counter
AVGPING=0                                           # Average ping value
MINPING=100                                         # Minimum ping value in ms before a reset takes place
USELOWESTSLOT=1                                     # Option to select either random VPN slot connections, or using the one
                                                    # with the lowest PING
FORCEDRESET=0                                       # Variable tracks whether a forced reset is initiated through the UI
LOWPINGCOUNT=0                                      # Counter for the number of tries before switching to lower ping server
PINGCHANCES=5                                       # Number of chances your current connection gets before reconnecting to
                                                    # faster server
SPIN=15                                             # 15-second Spin timer
state1=0                                            # Initialize the VPN connection states for VPN Clients 1-5
state2=0
state3=0
state4=0
state5=0
START=$(date +%s)                                   # Start a timer to determine intervals of VPN resets
DelayStartup=0                                      # Tracking the delayed startup timer
TRIMLOGS=0                                          # Tracking log sizes for trimming functionality
MAXLOGSIZE=1000
CURRLOGSIZE=0
SKIPPROGRESS=0                                      # Variable to skip the progress bar
VPNIP="Unassigned"                                  # Tracking VPN IP for city location display. API gives you 1K lookups
                                                    # per day, and is optimized to only lookup city location after a reset
vpnresettripped=0                                   # Tracking whether a VPN Reset is tripped due to a WAN outage
WANIP="Unassigned"                                  # Tracking WAN IP for city location display
ICANHAZIP=""                                        # Variable for tracking public facing VPN IP
VPNLOAD=0                                           # Variable tracks the NordVPN server load
AVGPING=0                                           # Variable tracks average ping time
PINGLOW=0                                           # Variable tracks lowest ping time
PINGHIGH=0                                          # Variable tracks highest ping time
SHOWSTATS=0                                         # Tracks whether you want to show stats on/off if you like minimalism
rxbytes=0                                           # Variables to capture and measure TX/RX rates on VPN Tunnel
txbytes=0
txrxbytes=0
rxgbytes=0
txgbytes=0
oldrxbytes=0
newrxbytes=0
oldtxbytes=0
newtxbytes=0

SyncYazFi=0                                         # Variables that track whether or not to sythe active VPN slot with
YF24GN1=0                                           # user-selectable YazFi guest networks
YF24GN2=0
YF24GN3=0
YF5GN1=0
YF5GN2=0
YF5GN3=0
YF52GN1=0
YF52GN2=0
YF52GN3=0

UseSurfShark=0                                      # Variables for SurfShark VPN
SurfSharkMultipleCountries=0
SurfSharkCountry="United States"
SurfSharkCountry2=""
SurfSharkCountry3=""
SurfSharkSuperRandom=0
SurfSharkLoadReset=50

UsePP=0                                             # Variables for Perfect Privacy VPN
PPMultipleCountries=0
PPCountry="United States"
PPCountry2=""
PPCountry3=""
PPSuperRandom=0
PPLoadReset=50

# Color variables
CBlack="\e[1;30m"
CRed="\e[1;31m"
InvRed="\e[1;41m"
CGreen="\e[1;32m"
InvGreen="\e[1;42m"
CYellow="\e[1;33m"
InvYellow="\e[1;43m"
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
promptYesn () {   # Enter defaults Yes
  while true; do
    read -p "[Y/n]? " yn
      case $yn in
        [Yy] ) echo -e "${CGreen}Using: Yes${CClear}";return 0 ;;
        [Nn] ) echo -e "${CGreen}Using: No${CClear}";return 1 ;;
        "" ) echo -e "${CGreen}Using: Yes${CClear}";return 0 ;;
        * ) echo -e "\nPlease answer Yes or No, or Enter to accept default value.";;
      esac
  done
}

promptyNo () {   # Enter defaults No
  while true; do
    read -p "[y/N]? " yn
      case $yn in
        [Yy] ) echo -e "${CGreen}Using: Yes${CClear}";return 0 ;;
        [Nn] ) echo -e "${CGreen}Using: No${CClear}";return 1 ;;
        "" ) echo -e "${CGreen}Using: No${CClear}";return 1 ;;
        * ) echo -e "\nPlease answer Yes or No, or Enter to accept default value.";;
      esac
  done
}

promptyn () {   # No defaults, just y or n
  while true; do
    read -p "[Y/N]? " -n 1 -r yn
      case "${yn}" in
        [Yy]* ) return 0 ;;
        [Nn]* ) return 1 ;;
        * ) echo -e "\nPlease answer Yes or No.";;
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

    if [ $progr -lt 60 ]; then
      printf "${CGreen}\r [%.${barch}s%.${barsp}s]${CClear} ${CYellow}${InvBlue}${i}s / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
    elif [ $progr -gt 59 ] && [ $progr -lt 85 ]; then
      printf "${CYellow}\r [%.${barch}s%.${barsp}s]${CClear} ${CYellow}${InvBlue}${i}s / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
    else
      printf "${CRed}\r [%.${barch}s%.${barsp}s]${CClear} ${CYellow}${InvBlue}${i}s / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
    fi
  fi

  # Borrowed this wonderful keypress capturing mechanism from @Eibgrad... thank you! :)
  key_press=''; read -rsn1 -t 1 key_press < "$(tty 0>&2)"

  if [ $key_press ]; then
      case $key_press in
          's') vsetup;;
          'S') vsetup;;
          'r') echo -e "${CGreen} [Reset Queued]                                                            "; FORCEDRESET=1;;
          'R') echo -e "${CGreen} [Reset Queued]                                                            "; FORCEDRESET=1;;
          'e') exit 0;;
      esac
  fi

}

# -------------------------------------------------------------------------------------------------------------------------

# Trimlogs is a function that does exactly what you think it does - it, uh... trims the logs. LOL
trimlogs() {

  if [ $TRIMLOGS == "1" ]
    then

      CURRLOGSIZE=$(wc -l $LOGFILE | awk '{ print $1 }' ) # Determine the number of rows in the log

      if [ $CURRLOGSIZE -gt $MAXLOGSIZE ] # If it's bigger than the max allowed, tail/trim it!
        then
          echo "$(tail -$MAXLOGSIZE $LOGFILE)" > $LOGFILE
          echo -e "$(date) - VPNMON-R2 - Trimmed the log file down to $MAXLOGSIZE lines" >> $LOGFILE
      fi

  fi
}

# -------------------------------------------------------------------------------------------------------------------------

# This function was "borrowed" graciously from @dave14305 from his FlexQoS script to determine the active WAN connection.
# Thanks much for your troubleshooting help as we tackled how to best derive the active WAN interface, Dave!

get_wan_setting() {
  local varname varval
  varname="${1}"
  prefixes="wan0_ wan1_"

  if [ "$($timeoutcmd$timeoutsec nvram get wans_mode)" = "lb" ] ; then
      for prefix in $prefixes; do
          state="$($timeoutcmd$timeoutsec nvram get "${prefix}"state_t)"
          sbstate="$($timeoutcmd$timeoutsec nvram get "${prefix}"sbstate_t)"
          auxstate="$($timeoutcmd$timeoutsec nvram get "${prefix}"auxstate_t)"

          # is_wan_connect()
          [ "${state}" = "2" ] || continue
          [ "${sbstate}" = "0" ] || continue
          [ "${auxstate}" = "0" ] || [ "${auxstate}" = "2" ] || continue

          # get_wan_ifname()
          proto="$($timeoutcmd$timeoutsec nvram get "${prefix}"proto)"
          if [ "${proto}" = "pppoe" ] || [ "${proto}" = "pptp" ] || [ "${proto}" = "l2tp" ] ; then
              varval="$($timeoutcmd$timeoutsec nvram get "${prefix}"pppoe_"${varname}")"
          else
              varval="$($timeoutcmd$timeoutsec nvram get "${prefix}""${varname}")"
          fi
      done
  else
      for prefix in $prefixes; do
          primary="$($timeoutcmd$timeoutsec nvram get "${prefix}"primary)"
          [ "${primary}" = "1" ] && break
      done

      proto="$($timeoutcmd$timeoutsec nvram get "${prefix}"proto)"
      if [ "${proto}" = "pppoe" ] || [ "${proto}" = "pptp" ] || [ "${proto}" = "l2tp" ] ; then
          varval="$($timeoutcmd$timeoutsec nvram get "${prefix}"pppoe_"${varname}")"
      else
          varval="$($timeoutcmd$timeoutsec nvram get "${prefix}""${varname}")"
      fi
  fi
  printf "%s" "${varval}"
} # get_wan_setting

# -------------------------------------------------------------------------------------------------------------------------

# Updatecheck is a function that downloads the latest update version file, and compares it with what's currently installed
updatecheck () {

  # Check if Dev/Beta Mode is enabled and exit
  if [ $Beta == "1" ]; then UpdateNotify=0; return; fi

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

# Checkwan is a function that checks the viability of the current WAN connection and will loop until the WAN connection is restored.
checkwan () {

  # Using Google's 8.8.8.8 server to test for WAN connectivity over verified SSL Handshake
  wandownbreakertrip=0
  WAN_ELAPSED_TIME=0
  testssl=8.8.8.8

  # Show that we're testing the WAN connection
  if [ $1 == "Loop" ]
  then
    printf "${CGreen}\r [Checking WAN Connectivity]..."
  elif [ $1 = "Reset" ]
  then
    printf "${CGreen}\r [Checking WAN Connectivity]..."
  fi

  #Run main checkwan loop
  while true; do

    # Start a timer to see how long this takes to add to the TX/RX Calculations
    WAN_START_TIME=$(date +%s)

    # Check the actual WAN State from NVRAM before running connectivity test, or insert itself into loop after failing an SSL handshake test
    if [ "$($timeoutcmd$timeoutsec nvram get wan0_state_t)" -ne 2 ] && [ "$($timeoutcmd$timeoutsec nvram get wan1_state_t)" -ne 2 ] || [ $wandownbreakertrip == "1" ]
      then

        # The WAN is most likely down, and keep looping through until NVRAM reports that it's back up
        wandownbreakertrip=1

        while [ $wandownbreakertrip == "1" ]; do

          # Continue to test for WAN connectivity while in this loop. If it comes back up, break out of the loop and reset VPN
          if [ "$($timeoutcmd$timeoutsec nvram get wan0_state_t)" -ne 2 ] && [ "$($timeoutcmd$timeoutsec nvram get wan1_state_t)" -ne 2 ]
            then
              # Continue to loop and retest the WAN every 15 seconds
              SPIN=15
              echo -e "$(date) - VPNMON-R2 ----------> ERROR: WAN DOWN" >> $LOGFILE
              clear && clear
                echo -e "${CRed}-----------------> ERROR: WAN DOWN <-----------------"
                echo ""
                echo -e "${CRed}VPNMON-R2 is unable to detect a stable WAN connection."
                echo -e "Trying to verify connection every $SPIN seconds...${CClear}\n"
                echo ""
                echo -e "${CRed}Please check with your ISP, or reset your modem to "
                echo -e "${CRed}re-establish a connection.${CClear}\n"
                spinner
                wandownbreakertrip=1
            else
              wandownbreakertrip=2
          fi
        done

      else

        # If the WAN was down, and now it has just reset, then run a VPN Reset, and try to establish a new VPN connection
        if [ $wandownbreakertrip == "2" ]
          then
            echo -e "$(date) - VPNMON-R2 - WAN Link Detected -- Trying to reconnect/Reset VPN" >> $LOGFILE
            wandownbreakertrip=0
            vpnresettripped=1
            clear && clear
            echo ""
            echo -e "${CRed}-----------------> ERROR: WAN DOWN <-----------------"
            echo ""
            echo -e "${CGreen}WAN Link Detected... waiting 60 seconds to reconnect"
            echo -e "${CGreen}or for connection to stabilize."
            SPIN=60
            spinner
            echo -e "$(date +%s)" > $RSTFILE
            START=$(cat $RSTFILE)
            clear && clear
            vpnreset
        fi

        # Else test the active WAN connection using 443 and verifying a handshake... if this fails, then the WAN connection is most likely down... or Google is down ;)
        if ($timeoutcmd$timeoutlng nc -w1 $testssl 443 && echo |openssl s_client -connect $testssl:443 2>&1 |awk 'handshake && $1 == "Verification" { if ($2=="OK") exit; exit 1 } $1 $2 == "SSLhandshake" { handshake = 1 }')
          then
            if [ $1 == "Loop" ]
            then
              printf "${CGreen}\r [Checking WAN Connectivity]...ACTIVE"
              sleep 1
              printf "\33[2K\r"
            elif [ $1 = "Reset" ]
            then
              printf "${CGreen}\r [Checking WAN Connectivity]...ACTIVE"
              sleep 1
              echo -e "\n"
            fi

            WAN_END_TIME=$(date +%s)
            WAN_ELAPSED_TIME=$(( WAN_END_TIME - WAN_START_TIME ))

            return

          else
            wandownbreakertrip=1
            echo -e "$(date) - VPNMON-R2 ----------> ERROR: WAN CONNECTIVITY ISSUE DETECTED" >> $LOGFILE
        fi
    fi
  done
}

# -------------------------------------------------------------------------------------------------------------------------

# vpnresetlowestping is a function that resets the VPN connection based on lowest ping.
vpnresetlowestping() {

  if [ $USELOWESTSLOT == "1" ]; then

    # Start the VPN reset process
      echo -e "$(date) - VPNMON-R2 - Executing VPN Reset to Slot with Lowest PING" >> $LOGFILE

    # Reset the VPN IP/Locations
      VPNIP="Unassigned"

    # Kill all current VPN client sessions
      echo ""
      printf "${CGreen}\r [Killing all VPN Client Connections]                          "
      service stop_vpnclient1 >/dev/null 2>&1
      service stop_vpnclient2 >/dev/null 2>&1
      service stop_vpnclient3 >/dev/null 2>&1
      service stop_vpnclient4 >/dev/null 2>&1
      service stop_vpnclient5 >/dev/null 2>&1

      echo -e "$(date) - VPNMON-R2 - Killed all VPN Client Connections" >> $LOGFILE

      # Check the WAN state before continuing
        printf "${CGreen}\r                                                               "
        checkwan Loop

      # Reset VPN connection to one with lowest PING
        service start_vpnclient$LOWEST >/dev/null 2>&1
        logger -t VPN Client$LOWEST "Active" >/dev/null 2>&1
        printf "${CGreen}\r [VPN$LOWEST Client ON]                                       "
        sleep 2
        echo -e "$(date) - VPNMON-R2 - VPN$LOWEST Client ON - Lowest PING of $N VPN slots" >> $LOGFILE

      # Optionally sync active VPN Slot with YazFi guest network(s)
        if [ $SyncYazFi -eq 1 ]
        then
          echo ""
          printf "${CGreen}\r [Updating YazFi Guest Networks]                               "
          sleep 1

          if [ ! -f $YAZFI_CONFIG_PATH ]
            then
              echo ""
              echo -e "\n${CRed} Error: YazFi config was not located or YazFi is not installed. Unable to Proceed.\n${CClear}"
              echo -e "$(date) - VPNMON-R2 ----------> ERROR: YazFi config was not located or YazFi is not installed!" >> $LOGFILE
              sleep 3
            else
              if [ $YF24GN1 -eq 1 ]
              then
                sed -i "s/^wl01_VPNCLIENTNUMBER=.*/wl01_VPNCLIENTNUMBER=$LOWEST/" "$YAZFI_CONFIG_PATH"
              fi

              if [ $YF24GN2 -eq 1 ]
              then
                sed -i "s/^wl02_VPNCLIENTNUMBER=.*/wl02_VPNCLIENTNUMBER=$LOWEST/" "$YAZFI_CONFIG_PATH"
              fi

              if [ $YF24GN3 -eq 1 ]
              then
                sed -i "s/^wl03_VPNCLIENTNUMBER=.*/wl03_VPNCLIENTNUMBER=$LOWEST/" "$YAZFI_CONFIG_PATH"
              fi

              if [ $YF5GN1 -eq 1 ]
              then
                sed -i "s/^wl11_VPNCLIENTNUMBER=.*/wl11_VPNCLIENTNUMBER=$LOWEST/" "$YAZFI_CONFIG_PATH"
              fi

              if [ $YF5GN2 -eq 1 ]
              then
                sed -i "s/^wl12_VPNCLIENTNUMBER=.*/wl12_VPNCLIENTNUMBER=$LOWEST/" "$YAZFI_CONFIG_PATH"
              fi

              if [ $YF5GN3 -eq 1 ]
              then
                sed -i "s/^wl13_VPNCLIENTNUMBER=.*/wl13_VPNCLIENTNUMBER=$LOWEST/" "$YAZFI_CONFIG_PATH"
              fi

              if [ $YF52GN1 -eq 1 ]
              then
                sed -i "s/^wl21_VPNCLIENTNUMBER=.*/wl21_VPNCLIENTNUMBER=$LOWEST/" "$YAZFI_CONFIG_PATH"
              fi

              if [ $YF52GN2 -eq 1 ]
              then
                sed -i "s/^wl22_VPNCLIENTNUMBER=.*/wl22_VPNCLIENTNUMBER=$LOWEST/" "$YAZFI_CONFIG_PATH"
              fi

              if [ $YF52GN3 -eq 1 ]
              then
                sed -i "s/^wl23_VPNCLIENTNUMBER=.*/wl23_VPNCLIENTNUMBER=$LOWEST/" "$YAZFI_CONFIG_PATH"
              fi

              #Apply settings to YazFi and get it to acknowledge changes for Guest Network Clients
              ResetYazFi=$($timeoutcmd$timeoutlng sh /jffs/scripts/YazFi runnow >/dev/null 2>&1)
              echo -e "$(date) - VPNMON-R2 - Successfully updated YazFi guest network(s) with the current VPN slot." >> $LOGFILE
          fi
        fi

        printf "${CGreen}\r [VPNMON-R2 Reset Finished]                                    "
        echo -e "$(date) - VPNMON-R2 - VPN Reset Finished" >> $LOGFILE
        sleep 2

        # Check for any version updates from the source repository
        updatecheck

        # Check to see if the logs need to be trimmed down to size
        trimlogs

        # Reset Stats
        oldrxbytes=0
        oldtxbytes=0
        newrxbytes=0
        newtxbytes=0

        # Returning from a WAN Down situation, restart VPNMON-R2 with -monitor switch
        if [ $vpnresettripped == "1" ]
          then
            vpnresettripped=0
            sh /jffs/scripts/vpnmon-r2.sh -monitor
        fi
  fi
}

# -------------------------------------------------------------------------------------------------------------------------

# VPNReset is a function based on my VPNON.SH script to kill connections and reconnect to a clean VPN state
vpnreset() {

  # Start the VPN reset process
    echo -e "$(date) - VPNMON-R2 - Executing VPN Reset" >> $LOGFILE

  # Reset the VPN IP/Locations
    VPNIP="Unassigned"

  # Kill all current VPN client sessions
    printf "${CGreen}\r [Killing all VPN Client Connections]...                          "
    service stop_vpnclient1 >/dev/null 2>&1
    service stop_vpnclient2 >/dev/null 2>&1
    service stop_vpnclient3 >/dev/null 2>&1
    service stop_vpnclient4 >/dev/null 2>&1
    service stop_vpnclient5 >/dev/null 2>&1

    echo -e "$(date) - VPNMON-R2 - Killed all VPN Client Connections" >> $LOGFILE

  # Check the WAN state before continuing
    printf "${CGreen}\r                                                               "
    checkwan Reset

  # Determine if multiple NordVPN countries need to be considered, and pick a random one
    if [ $NordVPNMultipleCountries -eq 1 ]
    then

      # Determine how many countries we're dealing with
      if [ -z "$NordVPNCountry2" ] || [ "$NordVPNCountry2" == "0" ]
      then
            COUNTRYTOTAL2=0
      else
            COUNTRYTOTAL2=1
      fi

      if [ -z "$NordVPNCountry3" ] || [ "$NordVPNCountry3" == "0" ]
      then
            COUNTRYTOTAL3=0
      else
            COUNTRYTOTAL3=1
      fi

      COUNTRYTOTAL=$(( COUNTRYTOTAL2 + COUNTRYTOTAL3 + 1 ))

      # Generate a number between 1 and the total # of countries, to choose which country to connect to
        RANDOMCOUNTRY=$(awk 'BEGIN {srand(); print int(32768 * rand())}')
        COUNTRYNUM=$(( RANDOMCOUNTRY % COUNTRYTOTAL + 1 ))

      # Set COUNTRYNUM to 1 in that rare case that it comes out to 0
        if [ $COUNTRYNUM -eq 0 ]
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
        printf "${CGreen}\r                                                               "
        printf "${CGreen}\r [Random NordVPN Multi-Country selected: $NordVPNRandomCountry]"
        echo -e "$(date) - VPNMON-R2 - Randomly selected NordVPN Country: $NordVPNRandomCountry" >> $LOGFILE
        sleep 1
    else
      NordVPNRandomCountry=$NordVPNCountry
    fi

  # Determine if multiple SurfShark countries need to be considered, and pick a random one
    if [ $SurfSharkMultipleCountries -eq 1 ]
    then

      # Determine how many countries we're dealing with
      if [ -z "$SurfSharkCountry2" ] || [ "$SurfSharkCountry2" == "0" ]
      then
            COUNTRYTOTAL2=0
      else
            COUNTRYTOTAL2=1
      fi

      if [ -z "$SurfSharkCountry3" ] || [ "$SurfSharkCountry3" == "0" ]
      then
            COUNTRYTOTAL3=0
      else
            COUNTRYTOTAL3=1
      fi

      COUNTRYTOTAL=$(( COUNTRYTOTAL2 + COUNTRYTOTAL3 + 1 ))

      # Generate a number between 1 and the total # of countries, to choose which country to connect to
        RANDOMCOUNTRY=$(awk 'BEGIN {srand(); print int(32768 * rand())}')
        COUNTRYNUM=$(( RANDOMCOUNTRY % COUNTRYTOTAL + 1 ))

      # Set COUNTRYNUM to 1 in that rare case that it comes out to 0
        if [ $COUNTRYNUM -eq 0 ]
          then
          COUNTRYNUM=1
        fi

      # Pick and assign the selected SurfShark Country
        case ${COUNTRYNUM} in

          1)
              SurfSharkRandomCountry=$SurfSharkCountry
          ;;

          2)
              SurfSharkRandomCountry=$SurfSharkCountry2
          ;;

          3)
              SurfSharkRandomCountry=$SurfSharkCountry3
          ;;

        esac
        echo ""
        printf "${CGreen}\r                                                               "
        printf "${CGreen}\r [Random SurfShark Multi-Country selected: $SurfSharkRandomCountry]"
        echo -e "$(date) - VPNMON-R2 - Randomly selected SurfShark Country: $SurfSharkRandomCountry" >> $LOGFILE
        sleep 1
    else
      SurfSharkRandomCountry=$SurfSharkCountry
    fi

  # Determine if multiple Perfect Privacy countries need to be considered, and pick a random one
    if [ $PPMultipleCountries -eq 1 ]
    then

      # Determine how many countries we're dealing with
      if [ -z "$PPCountry2" ] || [ "$PPCountry2" == "0" ]
      then
            COUNTRYTOTAL2=0
      else
            COUNTRYTOTAL2=1
      fi

      if [ -z "$PPCountry3" ] || [ "$PPCountry3" == "0" ]
      then
            COUNTRYTOTAL3=0
      else
            COUNTRYTOTAL3=1
      fi

      COUNTRYTOTAL=$(( COUNTRYTOTAL2 + COUNTRYTOTAL3 + 1 ))

      # Generate a number between 1 and the total # of countries, to choose which country to connect to
        RANDOMCOUNTRY=$(awk 'BEGIN {srand(); print int(32768 * rand())}')
        COUNTRYNUM=$(( RANDOMCOUNTRY % COUNTRYTOTAL + 1 ))

      # Set COUNTRYNUM to 1 in that rare case that it comes out to 0
        if [ $COUNTRYNUM -eq 0 ]
          then
          COUNTRYNUM=1
        fi

      # Pick and assign the selected Perfect Privacy Country
        case ${COUNTRYNUM} in

          1)
              PPRandomCountry=$PPCountry
          ;;

          2)
              PPRandomCountry=$PPCountry2
          ;;

          3)
              PPRandomCountry=$PPCountry3
          ;;

        esac
        echo ""
        printf "${CGreen}\r                                                               "
        printf "${CGreen}\r [Random PerfPriv Multi-Country selected: $PPRandomCountry]    "
        echo -e "$(date) - VPNMON-R2 - Randomly selected Percect Privacy Country: $PPRandomCountry" >> $LOGFILE
        sleep 1
    else
      PPRandomCountry=$PPCountry
    fi

  # Export NordVPN/PerfectPrivacy IPs via API into a txt file, and import them into Skynet
    if [ $UpdateSkynet -eq 1 ]
    then

      if [ $UseNordVPN -eq 1 ]
      then
        curl --silent --retry 3 "https://api.nordvpn.com/v1/servers?limit=16384" | jq --raw-output '.[] | select(.locations[].country.name == "'"$NordVPNRandomCountry"'") | .station' > /jffs/scripts/NordVPN.txt
        LINES=$(cat /jffs/scripts/NordVPN.txt | wc -l)  #Check to see how many lines/server IPs are in this file

        if [ $LINES -eq 0 ] # If there are no lines, error out
        then
          echo -e "\n${CRed}Error: NordVPN.txt list is blank! Check NordVPN service or config's Country Name.\n${CClear}"
          echo -e "$(date) - VPNMON-R2 ----------> ERROR: NordVPN.txt list is blank!" >> $LOGFILE
        else
          printf "${CGreen}\r                                                               "
          printf "${CGreen}\r [Updating Skynet whitelist with NordVPN Server IPs]           "
          sleep 1

          firewall import whitelist /jffs/scripts/NordVPN.txt "NordVPN - $NordVPNRandomCountry" >/dev/null 2>&1

          SPIN=15
          printf "${CGreen}\r                                                               "
          printf "${CGreen}\r  [Letting Skynet import and settle for $SPIN seconds]         "

            spinner

          echo -e "$(date) - VPNMON-R2 - Updated Skynet Whitelist" >> $LOGFILE
        fi
      fi

      if [ $UsePP -eq 1 ]
      then
        curl --silent --retry 3 "https://www.perfect-privacy.com/api/serverips" > /jffs/scripts/ppips.txt
        awk -F' ' '{print $2}' /jffs/scripts/ppips.txt > /jffs/scripts/ppipscln.txt
        sed "s/,/\n/g" /jffs/scripts/ppipscln.txt > /jffs/scripts/ppipslst.txt
        LINES=$(cat /jffs/scripts/ppipslst.txt | wc -l)  #Check to see how many lines/server IPs are in this file

        if [ $LINES -eq 0 ] # If there are no lines, error out
        then
          echo -e "\n${CRed}Error: ppipslst.txt list is blank! Check Perfect Privacy service.\n${CClear}"
          echo -e "$(date) - VPNMON-R2 ----------> ERROR: ppipslst.txt Perfect Privacy VPN list is blank!" >> $LOGFILE
        else
          printf "${CGreen}\r                                                               "
          printf "${CGreen}\r [Updating Skynet whitelist with Perfect Privacy Server IPs]   "
          sleep 1

          firewall import whitelist /jffs/scripts/ppipslst.txt "Perfect Privacy VPN" >/dev/null 2>&1

          SPIN=15
          printf "${CGreen}\r                                                               "
          printf "${CGreen}\r  [Letting Skynet import and settle for $SPIN seconds]         "

            spinner

          echo -e "$(date) - VPNMON-R2 - Updated Skynet Whitelist" >> $LOGFILE
        fi
      fi
    fi

  # Randomly select VPN Client slots against entire field of available NordVPN server IPs for selected country
    if [ $NordVPNSuperRandom -eq 1 ]
    then
      UpdateVPNMGR=0 # Failsafe to make sure VPNMGR doesn't overwrite values written by the SuperRandom function

      if [ -f /jffs/scripts/NordVPN.txt ] # Check to see if NordVPN file exists from UpdateSkynet
      then
        LINES=$(cat /jffs/scripts/NordVPN.txt | wc -l)  # Check to see how many lines/server IPs are in this file

        if [ $LINES -eq 0 ] # If there are no lines, error out
        then
          echo -e "${CRed}Error: NordVPN.txt list is blank! Check NordVPN service or config's Country Name.\n${CClear}"
          echo -e "$(date) - VPNMON-R2 ----------> ERROR: NordVPN.txt list is blank!" >> $LOGFILE
          return
        fi

        printf "${CGreen}\r                                                               "
        printf "${CGreen}\r [Updating VPN Slots 1-$N from $LINES SuperRandom NordVPN IPs] "
        sleep 1
        echo ""

        i=0
        while [ $i -ne $N ] #Assign SuperRandom IPs/Descriptions to VPN Slots 1-N
          do
            i=$(($i+1))
            RANDOM=$(awk 'BEGIN {srand(); print int(32768 * rand())}')
            R_LINE=$(( RANDOM % LINES + 1 ))
            RNDVPNIP=$(sed -n "${R_LINE}p" /jffs/scripts/NordVPN.txt)
            RNDVPNCITY="curl --silent --retry 3 --request GET --url https://ipapi.co/$RNDVPNIP/city"
            RNDVPNCITY="$(eval $RNDVPNCITY)"; if echo $RNDVPNCITY | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then RNDVPNCITY="$RNDVPNIP"; fi
            nvram set vpn_client"$i"_addr="$RNDVPNIP"
            nvram set vpn_client"$i"_desc="NordVPN - $RNDVPNCITY"
            echo -e "${CGreen}  VPN$i Slot - SuperRandom IP: $RNDVPNIP - City: $RNDVPNCITY${CClear}"
            sleep 1
        done
        echo ""
        echo -e "$(date) - VPNMON-R2 - Refreshed VPN Slots 1 - $N from $LINES SuperRandom NordVPN Server Locations" >> $LOGFILE

      else

        # NordVPN.txt must not exist and/or UpdateSkynet is turned off, so run API to get full server list from NordVPN
        curl --silent --retry 3 "https://api.nordvpn.com/v1/servers?limit=16384" | jq --raw-output '.[] | select(.locations[].country.name == "'"$NordVPNRandomCountry"'") | .station' > /jffs/scripts/NordVPN.txt
        LINES=$(cat /jffs/scripts/NordVPN.txt | wc -l) #Check to see how many lines/server IPs are in this file

        if [ $LINES -eq 0 ] #If there are no lines, error out
        then
          echo -e "\n${CRed}Error: NordVPN.txt list is blank! Check NordVPN service or config's Country Name.\n${CClear}"
          echo -e "$(date) - VPNMON-R2 ----------> ERROR: NordVPN.txt list is blank!" >> $LOGFILE
          sleep 3
          return
        fi

        printf "${CGreen}\r                                                               "
        printf "${CGreen}\r [Update VPN Slots 1-$N from $LINES SuperRandom NordVPN IPs]   "
        sleep 1
        echo ""

        i=0
        while [ $i -ne $N ] #Assign SuperRandom IPs/Descriptions to VPN Slots 1-N
          do
            i=$(($i+1))
            RANDOM=$(awk 'BEGIN {srand(); print int(32768 * rand())}')
            R_LINE=$(( RANDOM % LINES + 1 ))
            RNDVPNIP=$(sed -n "${R_LINE}p" /jffs/scripts/NordVPN.txt)
            RNDVPNCITY="curl --silent --retry 3 --request GET --url https://ipapi.co/$RNDVPNIP/city"
            RNDVPNCITY="$(eval $RNDVPNCITY)"; if echo $RNDVPNCITY | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then RNDVPNCITY="$RNDVPNIP"; fi
            nvram set vpn_client"$i"_addr="$RNDVPNIP"
            nvram set vpn_client"$i"_desc="NordVPN - $RNDVPNCITY"
            echo -e "${CGreen}  VPN$i Slot - SuperRandom IP: $RNDVPNIP - City: $RNDVPNCITY${CClear}"
            sleep 1
        done
        echo ""
        echo -e "$(date) - VPNMON-R2 - Refreshed VPN Slots 1 - $N from $LINES SuperRandom NordVPN Server Locations" >> $LOGFILE
      fi
    fi

    if [ $UseSurfShark -eq 1 ]
    then
      # Randomly select VPN Client slots against entire field of available SurfShark server IPs for selected country
      if [ $SurfSharkSuperRandom -eq 1 ]
      then
        UpdateVPNMGR=0 # Failsafe to make sure VPNMGR doesn't overwrite values written by the SuperRandom function

          # Run SurfShark API to get full server list from SurfShark
          curl --silent --retry 3 "https://api.surfshark.com/v3/server/clusters" | jq --raw-output '.[] | select(.country == "'"$SurfSharkRandomCountry"'") | .connectionName' > /jffs/scripts/surfshark.txt

          LINES=$(cat /jffs/scripts/surfshark.txt | wc -l) #Check to see how many linesare in this file

          if [ $LINES -eq 0 ] #If there are no lines, error out
          then
            echo -e "\n${CRed}Error: surfshark.txt list is blank! Check SurfShark service or config's Country Name.\n${CClear}"
            echo -e "$(date) - VPNMON-R2 ----------> ERROR: surfshark.txt list is blank!" >> $LOGFILE
            sleep 3
            return
          fi

          printf "${CGreen}\r                                                               "
          printf "${CGreen}\r [Update VPN Slots 1-$N from $LINES SuperRandom SurfShark IPs] "
          sleep 1
          echo ""

          i=0
          while [ $i -ne $N ] #Assign SuperRandom IPs/Descriptions to VPN Slots 1-N
            do
              i=$(($i+1))
              RANDOM=$(awk 'BEGIN {srand(); print int(32768 * rand())}')
              R_LINE=$(( RANDOM % LINES + 1 ))
              RNDVPNHOST=$(sed -n "${R_LINE}p" /jffs/scripts/surfshark.txt)
              RNDVPNIP=$(ping -q -c1 -n $RNDVPNHOST | head -n1 | sed "s/.*(\([0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\)).*/\1/g") > /dev/null 2>&1 #2>/dev/null
              RNDVPNCITY="curl --silent --retry 3 --request GET --url https://ipapi.co/$RNDVPNIP/city"
              RNDVPNCITY="$(eval $RNDVPNCITY)"; if echo $RNDVPNCITY | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then RNDVPNCITY="$RNDVPNIP"; fi
              nvram set vpn_client"$i"_addr="$RNDVPNHOST"
              nvram set vpn_client"$i"_desc="SurfShark - $RNDVPNCITY"
              echo -e "${CGreen}  VPN$i Slot - SuperRandom Host: $RNDVPNHOST - City: $RNDVPNCITY${CClear}"
              sleep 1
          done
            echo ""
            echo -e "$(date) - VPNMON-R2 - Refreshed VPN Slots 1 - $N from $LINES SuperRandom SurfShark Server Locations" >> $LOGFILE
      fi
    fi

    if [ $UsePP -eq 1 ]
      then
        # Randomly select VPN Client slots against entire field of available Perfect Privacy server IPs for selected country
        if [ $PPSuperRandom -eq 1 ]
        then
          UpdateVPNMGR=0 # Failsafe to make sure VPNMGR doesn't overwrite values written by the SuperRandom function

            # Run Perfect Privacy API to get full server list from Perfect Privacy VPN
            curl --silent --retry 3 "https://www.perfect-privacy.com/api/serverlocations.json" | jq -r 'path(.[] | select(.country =="'"$PPRandomCountry"'"))[0]' > /jffs/scripts/pp.txt

            LINES=$(cat /jffs/scripts/pp.txt | wc -l) #Check to see how many linesare in this file

            if [ $LINES -eq 0 ] #If there are no lines, error out
            then
              echo -e "\n${CRed}Error: pp.txt VPN server list is blank! Check Perfect Privacy VPN service or config's Country Name.\n${CClear}"
              echo -e "$(date) - VPNMON-R2 ----------> ERROR: pp.txt Perfect Privacy VPN list is blank!" >> $LOGFILE
              sleep 3
              return
            fi

            printf "${CGreen}\r                                                               "
            printf "${CGreen}\r [Update VPN Slots 1-$N from $LINES SuperRandom PerfPriv IPs]  "
            sleep 1
            echo ""

            i=0
            while [ $i -ne $N ] #Assign SuperRandom IPs/Descriptions to VPN Slots 1-N
              do
                i=$(($i+1))
                RANDOM=$(awk 'BEGIN {srand(); print int(32768 * rand())}')
                R_LINE=$(( RANDOM % LINES + 1 ))
                RNDVPNHOST=$(sed -n "${R_LINE}p" /jffs/scripts/pp.txt)
                RNDVPNIP=$(ping -q -c1 -n $RNDVPNHOST | head -n1 | sed "s/.*(\([0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\)).*/\1/g") > /dev/null 2>&1 #2>/dev/null
                RNDVPNCITY="curl --silent --retry 3 --request GET --url https://ipapi.co/$RNDVPNIP/city"
                RNDVPNCITY="$(eval $RNDVPNCITY)"; if echo $RNDVPNCITY | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then RNDVPNCITY="$RNDVPNIP"; fi
                nvram set vpn_client"$i"_addr="$RNDVPNHOST"
                nvram set vpn_client"$i"_desc="Perfect Privacy - $RNDVPNCITY"
                echo -e "${CGreen}  VPN$i Slot - SuperRandom Host: $RNDVPNHOST - City: $RNDVPNCITY\n${CClear}"
                sleep 1
            done
              echo ""
              echo -e "$(date) - VPNMON-R2 - Refreshed VPN Slots 1 - $N from $LINES SuperRandom Perfect Privacy Server Locations" >> $LOGFILE
        fi
    fi

  # Clean up API NordVPN Server Extracts
    if [ -f /jffs/scripts/NordVPN.txt ]
    then
      rm /jffs/scripts/NordVPN.txt  #Cleanup NordVPN temp files
    fi

  # Clean up API SurfShark Server Extracts
    if [ -f /jffs/scripts/surfshark.txt ]
    then
      rm /jffs/scripts/surfshark.txt  #Cleanup Surfshark temp files
    fi

  # Clean up API Perfect Privacy Server Extracts
    if [ -f /jffs/scripts/pp.txt ] || [ -f /jffs/scripts/ppips.txt ]
    then
      rm /jffs/scripts/pp.txt  #Cleanup Perfect Privacy temp files
      rm /jffs/scripts/ppips.txt
      rm /jffs/scripts/ppipscln.txt
      rm /jffs/scripts/ppipslst.txt
    fi

  # Call VPNMGR functions to refresh server lists and save their results to the VPN client configs
    if [ $UpdateVPNMGR -eq 1 ]
    then

      printf "${CGreen}\r                                                               "
      printf "${CGreen}\r [Refresh VPNMGRs NordVPN/PIA/WeVPN Server Locations]          "
      sh /jffs/scripts/service-event start vpnmgrrefreshcacheddata >/dev/null 2>&1
      sleep 10
      sh /jffs/scripts/service-event start vpnmgr >/dev/null 2>&1
      sleep 10
      echo -e "$(date) - VPNMON-R2 - Refreshed VPNMGR Server Locations and Hostnames" >> $LOGFILE
    fi

    if [ $USELOWESTSLOT == "0" ]; then

    # Pick a random VPN Client to connect to
      printf "${CGreen}\r                                                               "
      printf "${CGreen}\r [Randomly selecting a VPN Client between 1 and $N]            "
      sleep 1

    # Generate a number between BASE and N, ie.1 and 5 to choose which VPN Client is started
      RANDOM=$(awk 'BEGIN {srand(); print int(32768 * rand())}')
      option=$(( RANDOM % N + BASE ))

    # Set option to 1 in that rare case that it comes out to 0
      if [ $option -eq 0 ]
        then
        option=1
      fi

    # Start the selected VPN Client
      case ${option} in

        1)
          service start_vpnclient1 >/dev/null 2>&1
          logger -t VPN Client1 "Active"
          printf "${CGreen}\r                                                               "
          printf "${CGreen}\r [VPN1 Client ON]                                              "
          echo -e "$(date) - VPNMON-R2 - Randomly selected VPN1 Client ON" >> $LOGFILE
          sleep 1
        ;;

        2)
          service start_vpnclient2 >/dev/null 2>&1
          logger -t VPN Client2 "Active"
          printf "${CGreen}\r                                                               "
          printf "${CGreen}\r [VPN2 Client ON]                                              "
          echo -e "$(date) - VPNMON-R2 - Randomly selected VPN2 Client ON" >> $LOGFILE
          sleep 1
        ;;

        3)
          service start_vpnclient3 >/dev/null 2>&1
          logger -t VPN Client3 "Active"
          printf "${CGreen}\r                                                               "
          printf "${CGreen}\r [VPN3 Client ON]                                              "
          echo -e "$(date) - VPNMON-R2 - Randomly selected VPN3 Client ON" >> $LOGFILE
          sleep 1
        ;;

        4)
          service start_vpnclient4 >/dev/null 2>&1
          logger -t VPN Client4 "Active"
          printf "${CGreen}\r                                                               "
          printf "${CGreen}\r [VPN4 Client ON]                                              "
          echo -e "$(date) - VPNMON-R2 - Randomly selected VPN4 Client ON" >> $LOGFILE
          sleep 1
        ;;

        5)
          service start_vpnclient5 >/dev/null 2>&1
          logger -t VPN Client5 "Active"
          printf "${CGreen}\r                                                               "
          printf "${CGreen}\r [VPN5 Client ON]                                              "
          echo -e "$(date) - VPNMON-R2 - Randomly selected VPN5 Client ON" >> $LOGFILE
          sleep 1
        ;;
      esac
      sleep 1
    else
      i=0
      while [ $i -ne $N ]
        do
          i=$(($i+1))
          OFFLINEVPNIP=$($timeoutcmd$timeoutsec nvram get vpn_client"$i"_addr)
          DISCHOSTPING=$(ping -I $WANIFNAME -c 1 $OFFLINEVPNIP | awk -F'time=| ms' 'NF==3{print $(NF-1)}' | sort -rn) # Get ping stats
          testping=${DISCHOSTPING%.*}
          if [ -z "$DISCHOSTPING" ]; then DISCHOSTPING=1; fi # On that rare occasion where it's unable to get the Ping time, assign 1

          if [ $i -eq 1 ]; then
            LOWEST=$i
            LOWESTPING=${testping%.*}
          elif [ ${testping%.*} -lt ${LOWESTPING%.*} ]; then
            LOWEST=$i
            LOWESTPING=${testping%.*}
          fi

          if [ $LOWESTPING -eq 1 ]; then
            LOWEST=$CURRCLNT
          fi
      done

      printf "${CGreen}\r                                                               "
      printf "${CGreen}\r [Starting fastest PING VPN$LOWEST Client ON]                  "
      service start_vpnclient$LOWEST >/dev/null 2>&1
      logger -t VPN Client$LOWEST "Active" >/dev/null 2>&1
      echo -e "$(date) - VPNMON-R2 - VPN$LOWEST Client ON - Lowest PING of $N VPN slots" >> $LOGFILE
      option=$LOWEST
      CURRCLNT=$LOWEST
      sleep 2
    fi

    # Optionally sync active VPN Slot with YazFi guest network(s)
    if [ $SyncYazFi -eq 1 ]
    then
      echo ""
      printf "${CGreen}\r                                                               "
      printf "${CGreen}\r [Updating YazFi Guest Network(s) with current VPN Slot...]    "
      sleep 1

      if [ ! -f $YAZFI_CONFIG_PATH ]
        then
          echo ""
          echo -e "\n${CRed}Error: YazFi config was not located or YazFi is not installed. Unable to Proceed.\n${CClear}"
          echo -e "$(date) - VPNMON-R2 ----------> ERROR: YazFi config was not located or YazFi is not installed!" >> $LOGFILE
          sleep 3
        else
          if [ $YF24GN1 -eq 1 ]
          then
            sed -i "s/^wl01_VPNCLIENTNUMBER=.*/wl01_VPNCLIENTNUMBER=$option/" "$YAZFI_CONFIG_PATH"
          fi

          if [ $YF24GN2 -eq 1 ]
          then
            sed -i "s/^wl02_VPNCLIENTNUMBER=.*/wl02_VPNCLIENTNUMBER=$option/" "$YAZFI_CONFIG_PATH"
          fi

          if [ $YF24GN3 -eq 1 ]
          then
            sed -i "s/^wl03_VPNCLIENTNUMBER=.*/wl03_VPNCLIENTNUMBER=$option/" "$YAZFI_CONFIG_PATH"
          fi

          if [ $YF5GN1 -eq 1 ]
          then
            sed -i "s/^wl11_VPNCLIENTNUMBER=.*/wl11_VPNCLIENTNUMBER=$option/" "$YAZFI_CONFIG_PATH"
          fi

          if [ $YF5GN2 -eq 1 ]
          then
            sed -i "s/^wl12_VPNCLIENTNUMBER=.*/wl12_VPNCLIENTNUMBER=$option/" "$YAZFI_CONFIG_PATH"
          fi

          if [ $YF5GN3 -eq 1 ]
          then
            sed -i "s/^wl13_VPNCLIENTNUMBER=.*/wl13_VPNCLIENTNUMBER=$option/" "$YAZFI_CONFIG_PATH"
          fi

          if [ $YF52GN1 -eq 1 ]
          then
            sed -i "s/^wl21_VPNCLIENTNUMBER=.*/wl21_VPNCLIENTNUMBER=$option/" "$YAZFI_CONFIG_PATH"
          fi

          if [ $YF52GN2 -eq 1 ]
          then
            sed -i "s/^wl22_VPNCLIENTNUMBER=.*/wl22_VPNCLIENTNUMBER=$option/" "$YAZFI_CONFIG_PATH"
          fi

          if [ $YF52GN3 -eq 1 ]
          then
            sed -i "s/^wl23_VPNCLIENTNUMBER=.*/wl23_VPNCLIENTNUMBER=$option/" "$YAZFI_CONFIG_PATH"
          fi

          #Apply settings to YazFi and get it to acknowledge changes for Guest Network Clients
          ResetYazFi=$($timeoutcmd$timeoutlng sh /jffs/scripts/YazFi runnow >/dev/null 2>&1)
          echo -e "$(date) - VPNMON-R2 - Successfully updated YazFi guest network(s) with the current VPN slot." >> $LOGFILE
        fi
    fi

    printf "${CGreen}\r                                                               "
    printf "${CGreen}\r [VPNMON-R2 VPN Reset finished]                                "
    echo -e "$(date) - VPNMON-R2 - VPN Reset Finished" >> $LOGFILE
    sleep 2

    # Check for any version updates from the source repository
    updatecheck

    # Check to see if the logs need to be trimmed down to size
    trimlogs

    # Reset Stats
    oldrxbytes=0
    oldtxbytes=0
    newrxbytes=0
    newtxbytes=0

    # Returning from a WAN Down situation, restart VPNMON-R2 with -monitor switch
    if [ $vpnresettripped == "1" ]
      then
        vpnresettripped=0
        sh /jffs/scripts/vpnmon-r2.sh -monitor
    fi
}

# -------------------------------------------------------------------------------------------------------------------------

# checkvpn is a function that checks each connection to see if its active, and performs a ping... borrowed
# heavily and much credit to @Martineau for this code from his VPN-Failover script. This piece right here
# is really how the whole VPNMON project got its start! :)

checkvpn() {

  CNT=0
  TUN="tun1"$1
  VPNSTATE=$2

  # If the VPN slot is connected then proceed, else display it's disconnected
  if [ $VPNSTATE -eq $connState ]
  then
    while [ $CNT -lt $TRIES ]; do # Loop through number of tries
      ping -I $TUN -q -c 1 -W 2 $PINGHOST > /dev/null 2>&1 # First try pings
      RC=$?
      ICANHAZIP=$(curl --silent --fail --interface $TUN --request GET --url http://icanhazip.com) # Grab the public IP of the VPN Connection
      IC=$?
      if [ $RC -eq 0 ] && [ $IC -eq 0 ];then  # If both ping/curl come back successful, then proceed
        STATUS=1
        VPNCLCNT=$((VPNCLCNT+1))
        AVGPING=$(ping -I $TUN -c 1 $PINGHOST | awk -F'time=| ms' 'NF==3{print $(NF-1)}' | sort -rn) # Get ping stats

        if [ -z "$AVGPING" ]; then AVGPING=1; fi # On that rare occasion where it's unable to get the Ping time, assign 1

        if [ $VPNIP == "Unassigned" ];then # The first time through, use API lookup to get exit VPN city and display
          VPNIP=$($timeoutcmd$timeoutsec nvram get vpn_client$1_addr)
          VPNCITY="curl --silent --retry 3 --request GET --url https://ipapi.co/$ICANHAZIP/city"
          VPNCITY="$(eval $VPNCITY)"; if echo $VPNCITY | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then VPNCITY="$ICANHAZIP"; fi
          echo -e "$(date) - VPNMON-R2 - API call made to update VPN city to $VPNCITY" >> $LOGFILE
        fi

        CONNHOSTPING=$(ping -I $WANIFNAME -c 1 $VPNIP | awk -F'time=| ms' 'NF==3{print $(NF-1)}' | sort -rn) # Get ping stats
        testping=${CONNHOSTPING%.*}

        echo -e "${CGreen} ==VPN$1 Tunnel Active | ||${CWhite}${InvGreen} $AVGPING ms ${CClear}${CGreen}|| | ${CClear}${CYellow}Exit: ${InvBlue}$VPNCITY${CClear}"
        CURRCLNT=$1
        break
      else
        sleep 1 # Giving the VPN a chance to recover a certain number of times
        CNT=$((CNT+1))

        if [ $CNT -eq $TRIES ];then # But if it fails, report back that we have an issue requiring a VPN reset
          STATUS=0
          echo -e "${CRed} x-VPN$1 Ping/http failed${CClear}"
          echo -e "$(date) - VPNMON-R2 - **VPN$1 Ping/http failed**" >> $LOGFILE
        fi
      fi
    done
  else
    OFFLINEVPNIP=$($timeoutcmd$timeoutsec nvram get vpn_client$1_addr)
    DISCHOSTPING=$(ping -I $WANIFNAME -c 1 $OFFLINEVPNIP | awk -F'time=| ms' 'NF==3{print $(NF-1)}' | sort -rn) # Get ping stats
    testping=${DISCHOSTPING%.*}
    if [ -z "$DISCHOSTPING" ]; then DISCHOSTPING=1; fi # On that rare occasion where it's unable to get the Ping time, assign 1

    echo -e "${CClear} - VPN$1 Disconnected  | || $DISCHOSTPING ms || | "

  fi

  if [ $1 -eq 1 ]; then
      LOWEST=$1
      LOWESTPING=${testping%.*}
    elif [ ${testping%.*} -lt ${LOWESTPING%.*} ]; then
      LOWEST=$1
      LOWESTPING=${testping%.*}
  fi

  if [ $LOWESTPING -eq 1 ]; then
    LOWEST=$CURRCLNT
  fi

}

# -------------------------------------------------------------------------------------------------------------------------

# checkwan is a function that checks each wan connection to see if its active, and performs a ping and a city lookup...
wancheck() {

  WANIF=$1

  # If WAN 0 or 1 is connected, then proceed, else display that it's inactive
  if [ "$($timeoutcmd$timeoutsec nvram get wan"$WANIF"_state_t)" -eq 2 ]
    then

      # Call the get_wan_setting function courtesy of @dave14305 and using this interface name to ping and get a city name from
      WANIFNAME=$(get_wan_setting ifname)

      # Backup Interface Retrieval method courtesy of @SomewhereOverTheRainbow's excellent coding skills:
      #WANIFNAME=$(ip r | grep default | grep -oE "\b($(nvram get wan_ifname)|$(nvram get wan0_ifname)|$(nvram get wan1_ifname)|$(nvram get wan_pppoe_ifname)|$(nvram get wan0_pppoe_ifname)|$(nvram get wan1_pppoe_ifname))\b")

      # Ping through the WAN interface
      WANPING=$(ping -I $WANIFNAME -c 1 $PINGHOST | awk -F'time=| ms' 'NF==3{print $(NF-1)}' | sort -rn)

      if [ -z "$WANPING" ]; then WANPING=1; fi # On that rare occasion where it's unable to get the Ping time, assign 1

      # Get the public IP of the WAN, determine the city from it, and display it on screen
      if [ $WANIP == "Unassigned" ];then
        WANIP=$(curl --silent --fail --interface $WANIFNAME --request GET --url http://icanhazip.com)
        WANCITY="curl --silent --retry 3 --request GET --url https://ipapi.co/$WANIP/city"
        WANCITY="$(eval $WANCITY)"; if echo $WANCITY | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then WANCITY="$WANIP"; fi
        echo -e "$(date) - VPNMON-R2 - API call made to update WAN city to $WANCITY" >> $LOGFILE
      fi

      #WANCITY="Your City"
      echo -e "${CGreen} ==WAN$WANIF $WANIFNAME Active | ||${CWhite}${InvGreen} $WANPING ms ${CClear}${CGreen}|| | ${CClear}${CYellow}Exit: ${InvBlue}$WANCITY${CClear}"

    else
      echo -e "${CClear} - WAN$WANIF Port Inactive"
  fi
}

# -------------------------------------------------------------------------------------------------------------------------

# vconfig is a function that steps you through the configuration items for a new or existing setup of VPNMON-R2...
vconfig () {
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
      if promptyn; then
        echo ""
        echo -e "${CCyan}\nContinuing Setup...${CClear}"
        echo ""
      else
        echo ""
        echo ""
        echo -e "${CGreen}Exiting Configuration Utility...${CClear}"
        sleep 2
        return
      fi
      # -----------------------------------------------------------------------------------------
      echo -e "${CCyan}Would you like to use proceed through this setup using default values,"
      echo -e "${CCyan}or your own custom values that are used from an already existing"
      echo -e "${CCyan}config file? NOTE: Hitting enter on field selections will use your"
      echo -e "${CCyan}custom values as default values if 'custom' is selected."
      echo -e "${CYellow}(Default = 1, Custom = 2)${CClear}"
      while true; do
        read -p "Default/Custom Values? (1/2): " DefCusVals
          case $DefCusVals in
            [1] ) echo -e "${CGreen}Using value: Default${CClear}";DefCusVals=1;break ;;
            [2] ) echo -e "${CGreen}Using value: Custom${CClear}";DefCusVals=2;break ;;
            "" ) echo -e "${CGreen}Using value: Default${CClear}";DefCusVals=1;break ;;
            * ) echo -e "\nPlease answer 1 or 2, or Enter to accept default value.";;
          esac
      done
        if [ $DefCusVals == "1" ]; then
          TRIES=3
          INTERVAL=60
          PINGHOST="8.8.8.8"
          UpdateVPNMGR=0
          USELOWESTSLOT=0
          PINGCHANCES=5
          UseNordVPN=0
          NordVPNSuperRandom=0
          NordVPNMultipleCountries=0
          NordVPNCountry="United States"
          NordVPNCountry2=0
          NordVPNCountry3=0
          NordVPNLoadReset=50
          UseSurfShark=0
          SurfSharkSuperRandom=0
          SurfSharkMultipleCountries=0
          SurfSharkCountry="United States"
          SurfSharkCountry2=0
          SurfSharkCountry3=0
          SurfSharkLoadReset=50
          UsePP=0
          PPSuperRandom=0
          PPMultipleCountries=0
          PPCountry="U.S.A."
          PPCountry2=0
          PPCountry3=0
          PPLoadReset=50
          UpdateSkynet=0
          ResetOption=1
          DailyResetTime="01:00"
          MINPING=100
          N=5
          SHOWSTATS=0
          DelayStartup=0
          TRIMLOGS=0
          MAXLOGSIZE=1000
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
        elif [ $DefCusVals == "2" ]; then
          if [ -f $CFGPATH ]; then
            source $CFGPATH
          else
            echo -e "${CRed}Error: VPNMON-R2 is not configured.  Please run 'vpnmon-r2.sh -setup' to complete setup${CClear}"
            echo ""
            echo -e "$(date) - VPNMON-R2 ----------> ERROR: vpnmon-r2.cfg was not found. Please run the install tool." >> $LOGFILE
            kill 0
          fi
        fi

      # -----------------------------------------------------------------------------------------
      echo ""
      echo -e "${CCyan}1. How many times would you like a ping to retry your VPN tunnel before"
      echo -e "${CCyan}resetting? ${CYellow}(Default = $TRIES)${CClear}"
      read -p 'Ping Retries: ' TRIES1
      if [ -z "$TRIES1" ]; then TRIES1=$TRIES; else TRIES=$TRIES1; fi # Using default/existing value on enter keypress
      echo -e "${CGreen}Using value: "$TRIES
      # -----------------------------------------------------------------------------------------
      echo ""
      echo -e "${CCyan}2. What interval (in seconds) would you like to check your VPN tunnel"
      echo -e "${CCyan}to ensure the connection is healthy? ${CYellow}(Default = $INTERVAL)${CClear}"
      read -p 'Interval (seconds): ' INTERVAL1
      if [ -z "$INTERVAL1" ]; then INTERVAL1=$INTERVAL; else INTERVAL=$INTERVAL1; fi # Using default/existing value on enter keypress
      echo -e "${CGreen}Using value: "$INTERVAL
      # -----------------------------------------------------------------------------------------
      echo ""
      echo -e "${CCyan}3. What host IP would you like to ping to determine the health of your "
      echo -e "${CCyan}VPN tunnel? ${CYellow}(Default = $PINGHOST)${CClear}"
      read -p 'Host IP: ' PINGHOST1
      if [ -z "$PINGHOST1" ]; then PINGHOST1="$PINGHOST"; else PINGHOST=$PINGHOST1; fi # Using default value on enter keypress
      echo -e "${CGreen}Using value: "$PINGHOST
      # -----------------------------------------------------------------------------------------
      echo ""
      echo -e "${CCyan}4. Would you like to update VPNMGR? (Note: must be already installed "
      echo -e "${CCyan}and you must be NordVPN/PIA/WeVPN subscriber) ${CYellow}(No=0, Yes=1)${CClear}"
      echo -e "${CYellow}(Default = $UpdateVPNMGR)${CClear}"
      while true; do
        read -p "Update VPNMGR? (0/1): " UpdateVPNMGR1
          case $UpdateVPNMGR1 in
            [0] ) echo -e "${CGreen}Using value: 0 (No)${CClear}";UpdateVPNMGR=0;break ;;
            [1] ) echo -e "${CGreen}Using value: 1 (Yes)${CClear}";UpdateVPNMGR=1;break ;;
            "" ) echo -e "${CGreen}Using value: $UpdateVPNMGR${CClear}";UpdateVPNMGR1=$UpdateVPNMGR;break ;;
            * ) echo -e "\nPlease answer 0 or 1, or Enter to accept default value.";;
          esac
      done
      # -----------------------------------------------------------------------------------------
      echo ""
      echo -e "${CCyan}5. In what manner you like VPNMON-R2 to activate a selected a VPN slot?"
      echo -e "${CCyan}There are 2 options to consider: ${CYellow}Random or Lowest PING.${CCyan} The 'Random'"
      echo -e "${CCyan}option will randomly pick one of your configured VPN slots to connect"
      echo -e "${CCyan}to, while the 'Lowest PING' option will continually test each of your"
      echo -e "${CCyan}VPN slots through each interval see which one has the lowest PING,"
      echo -e "${CCyan}which most likely will be your fastest connection, and will always"
      echo -e "${CCyan}force a connection to it.${CYellow}(Random=0, Lowest PING=1)${CClear}"
      echo -e "${CYellow}(Default = $USELOWESTSLOT)${CClear}"
      while true; do
        read -p "Random or Lowest PING? (0/1): " USELOWESTSLOT1
          case $USELOWESTSLOT1 in
            [0] ) echo -e "${CGreen}Using value: 0 (Random)${CClear}";USELOWESTSLOT=0;break ;;
            [1] ) echo -e "${CGreen}Using value: 1 (Lowest PING)${CClear}";USELOWESTSLOT=1;break ;;
            "" ) echo -e "${CGreen}Using value: $USELOWESTSLOT${CClear}";USELOWESTSLOT1=$USELOWESTSLOT;break ;;
            * ) echo -e "\nPlease answer 0 or 1, or Enter to accept default value.";;
          esac
      done
      # -----------------------------------------------------------------------------------------
      if [ $USELOWESTSLOT == "1" ]; then
        echo ""
        echo -e "${CCyan}5a. When using the 'Lowest PING' method, there is a higher chance that"
        echo -e "${CCyan}your connections will reset at a higher rate, due to competing servers"
        echo -e "${CCyan}giving slighly lower pings.  To combat this, a counter is available to"
        echo -e "${CCyan}help give your connection a chance to recover and regain its status as"
        echo -e "${CCyan}the connection with the lowest ping.  How many chances would you like"
        echo -e "${CCyan}to give your connection before reconnecting to a faster VPN server?"
        echo -e "${CYellow}(Default = $PINGCHANCES)${CClear}"
        read -p 'Number of Chances?: ' PINGCHANCES1
        if [ -z "$PINGCHANCES1" ]; then PINGCHANCES1="$PINGCHANCES"; else PINGCHANCES="$PINGCHANCES1"; fi # Using default value on enter keypress
        echo -e "${CGreen}Using value: "$PINGCHANCES
      fi
      # -----------------------------------------------------------------------------------------
      echo ""

      if [ $UseNordVPN == "1" ]; then
        VPNProvider=1
      elif [ $UseSurfShark == "1" ]; then
        VPNProvider=2
      elif [ $UsePP == "1" ]; then
        VPNProvider=3
      else
        VPNProvider=4
      fi

      echo -e "${CCyan}6. Which service is your default VPN Provider? ${CYellow}(NordVPN = 1,"
      echo -e "${CYellow}Surfshark = 2, Perfect Privacy = 3, Not Listed = 4) (Default = $VPNProvider)${CClear}"

      while true; do
        read -p "VPN Provider (1/2/3/4): " VPNProvider1
          case $VPNProvider1 in
            [1] ) echo -e "${CGreen}Using value: 1 (NordVPN)${CClear}";VPNProvider=$VPNProvider1;break ;;
            [2] ) echo -e "${CGreen}Using value: 2 (Surfshark)${CClear}";VPNProvider=$VPNProvider1;break ;;
            [3] ) echo -e "${CGreen}Using value: 3 (Perfect Privacy)${CClear}";VPNProvider=$VPNProvider1;break ;;
            [4] ) echo -e "${CGreen}Using value: 4 (Not Listed)${CClear}";VPNProvider=$VPNProvider1;break ;;
            "" ) echo -e "${CGreen}Using value: $VPNProvider${CClear}";break ;;
            * ) echo -e "\nPlease answer 1/2/3/4, or Enter to accept default value.";;
          esac
      done

      # -----------------------------------------------------------------------------------------
      # NordVPN Logic
      # -----------------------------------------------------------------------------------------

      if [ $VPNProvider == "1" ]; then # NordVPN
        UseNordVPN=1

        echo ""
        echo -e "${CCyan}6a. Would you like to use the NordVPN SuperRandom functionality?"
        echo -e "${CYellow}(No=0, Yes=1) (Default = $NordVPNSuperRandom)${CClear}"
        while true; do
          read -p "Use SuperRandom? (0/1): " NordVPNSuperRandom1
            case $NordVPNSuperRandom1 in
              [0] ) echo -e "${CGreen}Using value: 0 (No)${CClear}";NordVPNSuperRandom=0;break ;;
              [1] ) echo -e "${CGreen}Using value: 1 (Yes)${CClear}";NordVPNSuperRandom=1;break ;;
              "" ) echo -e "${CGreen}Using value: $NordVPNSuperRandom${CClear}";NordVPNSuperRandom1=$NordVPNSuperRandom;break ;;
              * ) echo -e "\nPlease answer 0 or 1, or Enter to accept default value.";;
            esac
        done
        # -----------------------------------------------------------------------------------------
        echo ""
        echo -e "${CCyan}6b. What Country is your country of origin for NordVPN? ${CYellow}(Default = "
        echo -e "${CYellow}$NordVPNCountry). NOTE: Country names must be spelled correctly as below!"
        echo -e "${CCyan}Valid country names as follows: Albania, Argentina, Australia, Austria,"
        echo -e "${CCyan}Belgium, Bosnia and Herzegovina, Brazil, Bulgaria, Canada, Chile,"
        echo -e "${CCyan}Costa Rica, Croatia, Cyprus, Czech Republic, Denmark, Estonia, Finland,"
        echo -e "${CCyan}France, Georgia, Germany, Greece, Hong Kong, Hungary, Iceland, Indonesia,"
        echo -e "${CCyan}Ireland, Israel, Italy, Japan, Latvia, Lithuania, Luxembourg, Malaysia,"
        echo -e "${CCyan}Mexico, Moldova, Netherlands, New Zealand, North Macedonia, Norway, Poland,"
        echo -e "${CCyan}Portugal, Romania, Serbia, Singapore, Slovakia, Slovenia, South Africa,"
        echo -e "${CCyan}South Korea, Spain, Sweden, Switzerland, Taiwan, Thailand, Turkey, Ukraine,"
        echo -e "${CCyan}United Arab Emirates, United Kingdom, United States, Vietnam.${CClear}"
        read -p 'NordVPN Country: ' NordVPNCountry1
        if [ -z "$NordVPNCountry1" ]; then NordVPNCountry1="$NordVPNCountry"; else NordVPNCountry="$NordVPNCountry1"; fi # Using default value on enter keypress
        echo -e "${CGreen}Using value: "$NordVPNCountry
        # -----------------------------------------------------------------------------------------
        if [ "$NordVPNSuperRandom" == "1" ]; then
          echo ""
          echo -e "${CCyan}6c. Would you like to randomize connections across multiple countries?"
          echo -e "${CCyan}NOTE: A maximum of 2 additional country names can be added. (Total of 3)"
          echo -e "${CYellow}(No=0, Yes=1) (Default = $NordVPNMultipleCountries)${CClear}"
          while true; do
            read -p "Use Multiple Countries? (0/1): " NordVPNMultipleCountries1
              case $NordVPNMultipleCountries1 in
                [0] ) echo -e "${CGreen}Using value: 0 (No)${CClear}";NordVPNMultipleCountries=0;break ;;
                [1] ) echo -e "${CGreen}Using value: 1 (Yes)${CClear}";NordVPNMultipleCountries=1;break ;;
                "" ) echo -e "${CGreen}Using value: $NordVPNMultipleCountries${CClear}";NordVPNMultipleCountries1=$NordVPNMultipleCountries;break ;;
                * ) echo -e "\nPlease answer 0 or 1, or Enter to accept default value.";;
              esac
          done

          if [ $NordVPNMultipleCountries == "1" ]; then
              echo -e "${CCyan}"
              read -p "Enter Country #2 (Use 0 for blank) (Default = $NordVPNCountry2): " NordVPNCountry21
              if [ -z "$NordVPNCountry21" ]; then NordVPNCountry21="$NordVPNCountry2"; else NordVPNCountry2="$NordVPNCountry21"; fi # Using default value on enter keypress
              echo -e "${CGreen}Using value: "$NordVPNCountry2
              echo -e "${CCyan}"
              read -p "Enter Country #3 (Use 0 for blank) (Default = $NordVPNCountry3): " NordVPNCountry31
              if [ -z "$NordVPNCountry31" ]; then NordVPNCountry31="$NordVPNCountry3"; else NordVPNCountry3="$NordVPNCountry31"; fi # Using default value on enter keypress
              echo -e "${CGreen}Using value: "$NordVPNCountry3
          else
            NordVPNMultipleCountries=0
            NordVPNCountry2=0
            NordVPNCountry3=0
          fi

        else
          NordVPNMultipleCountries=0
          NordVPNCountry2=0
          NordVPNCountry3=0
        fi
        # -----------------------------------------------------------------------------------------
        echo ""
        echo -e "${CCyan}6d. At what % VPN server load would you like to reconnect to a different"
        echo -e "${CCyan}NordVPN Server? ${CYellow}(Default = $NordVPNLoadReset)${CClear}"
        read -p "% Server Load Threshold: " NordVPNLoadReset1
        if [ -z "$NordVPNLoadReset1" ]; then NordVPNLoadReset1=$NordVPNLoadReset; else NordVPNLoadReset=$NordVPNLoadReset1; fi # Using default value on enter keypress
        echo -e "${CGreen}Using value: "$NordVPNLoadReset
        # -----------------------------------------------------------------------------------------
        echo ""
        echo -e "${CCyan}6e. Would you like to whitelist NordVPN servers in the Skynet Firewall?"
        echo -e "${CYellow}(No=0, Yes=1) (Default = $UpdateSkynet)${CClear}"
        while true; do
          read -p "Update Skynet? (0/1): " UpdateSkynet1
            case $UpdateSkynet1 in
              [0] ) echo -e "${CGreen}Using value: 0 (No)${CClear}";UpdateSkynet=0;break ;;
              [1] ) echo -e "${CGreen}Using value: 1 (Yes)${CClear}";UpdateSkynet=1;break ;;
              "" ) echo -e "${CGreen}Using value: $UpdateSkynet${CClear}";UpdateSkynet1=$UpdateSkynet;break ;;
              * ) echo -e "\nPlease answer 0 or 1, or Enter to accept default value.";;
            esac
        done
        # -----------------------------------------------------------------------------------------
      else
        UseNordVPN=0
        NordVPNSuperRandom=0
        NordVPNMultipleCountries=0
        NordVPNCountry="United States"
        NordVPNCountry2=0
        NordVPNCountry3=0
        NordVPNLoadReset=50
        UpdateSkynet=0
      fi

      # -----------------------------------------------------------------------------------------
      # Surfshark Logic
      # -----------------------------------------------------------------------------------------

      if [ $VPNProvider == "2" ]; then # Surfshark
        UseSurfShark=1

        echo ""
        echo -e "${CCyan}6a. Would you like to use the SurfShark SuperRandom functionality?"
        echo -e "${CYellow}(No=0, Yes=1) (Default = $SurfSharkSuperRandom)${CClear}"
        while true; do
          read -p "Use SuperRandom? (0/1): " SurfSharkSuperRandom1
            case $SurfSharkSuperRandom1 in
              [0] ) echo -e "${CGreen}Using value: 0 (No)${CClear}";SurfSharkSuperRandom=0;break ;;
              [1] ) echo -e "${CGreen}Using value: 1 (Yes)${CClear}";SurfSharkSuperRandom=1;break ;;
              "" ) echo -e "${CGreen}Using value: $SurfSharkSuperRandom${CClear}";SurfSharkSuperRandom1=$SurfSharkSuperRandom;break ;;
              * ) echo -e "\nPlease answer 0 or 1, or Enter to accept default value.";;
            esac
        done
        # -----------------------------------------------------------------------------------------
        echo ""
        echo -e "${CCyan}6b. What Country is your country of origin for SurfShark? ${CYellow}(Default = "
        echo -e "${CYellow}$SurfSharkCountry). NOTE: Country names must be spelled correctly as below!"
        echo -e "${CCyan}Valid country names as follows: Albania, Algeria, Andorra, Argentina,"
        echo -e "${CCyan}Armenia, Australia, Austria, Azerbaijan, Bahamas, Belgium Belize Bhutan,"
        echo -e "${CCyan}Bolivia, Bosnia and Herzegovina, Brazil, Brunei, Bulgaria, Canada, Chile,"
        echo -e "${CCyan}Colombia, Combodia, Costa Rica, Croatia, Cyprus, Czech Republic, Denmark,"
        echo -e "${CCyan}Ecuador, Egypt, Estonia, Finland, France, Georgia, Germany, Greece,"
        echo -e "${CCyan}Hong Kong, Hungary, Iceland, India, Indonesia, Ireland, Israel, Italy, Japan,"
        echo -e "${CCyan}Kazakhstan, Laos, Latvia, Liechtenstein, Lithuania, Luxembourg, Malaysia,"
        echo -e "${CCyan}Malta, Marocco, Mexico, Moldova, Monaco, Mongolia, Montenegro, Myanmar,"
        echo -e "${CCyan}Nepal, Netherlands, New Zealand, Nigeria, North Macedonia, Norway, Panama,"
        echo -e "${CCyan}Paraguay, Peru, Philippines, Poland, Portugal, Romania, Serbia, Singapore,"
        echo -e "${CCyan}Slovakia, Slovenia, South Africa, South Korea, Spain, Sri Lanka, Sweden,"
        echo -e "${CCyan}Switzerland, Taiwan, Thailand, Turkey, Ukraine, United Arab Emirates,"
        echo -e "${CCyan}United Kingdom, United States, Uruguay, Uzbekistan, Venezuela, Vietnam${CClear}"
        read -p 'SurfShark Country: ' SurfSharkCountry1
        if [ -z "$SurfSharkCountry1" ]; then SurfSharkCountry1="$SurfSharkCountry"; else SurfSharkCountry="$SurfSharkCountry1"; fi # Using default value on enter keypress
        echo -e "${CGreen}Using value: "$SurfSharkCountry
        # -----------------------------------------------------------------------------------------
        if [ "$SurfSharkSuperRandom" == "1" ]; then
          echo ""
          echo -e "${CCyan}6c. Would you like to randomize connections across multiple countries?"
          echo -e "${CCyan}NOTE: A maximum of 2 additional country names can be added. (Total of 3)"
          echo -e "${CYellow}(No=0, Yes=1) (Default = $SurfSharkMultipleCountries)${CClear}"
          while true; do
            read -p "Use Multiple Countries? (0/1): " SurfSharkMultipleCountries1
              case $SurfSharkMultipleCountries1 in
                [0] ) echo -e "${CGreen}Using value: 0 (No)${CClear}";SurfSharkMultipleCountries=0;break ;;
                [1] ) echo -e "${CGreen}Using value: 1 (Yes)${CClear}";SurfSharkMultipleCountries=1;break ;;
                "" ) echo -e "${CGreen}Using value: $SurfSharkMultipleCountries${CClear}";SurfSharkMultipleCountries1=$SurfSharkMultipleCountries;break ;;
                * ) echo -e "\nPlease answer 0 or 1, or Enter to accept default value.";;
              esac
          done

          if [ $SurfSharkMultipleCountries == "1" ]; then
              echo -e "${CCyan}"
              read -p "Enter Country #2 (Use 0 for blank) (Default = $SurfSharkCountry2): " SurfSharkCountry21
              if [ -z "$SurfSharkCountry21" ]; then SurfSharkCountry21="$SurfSharkCountry2"; else SurfSharkCountry2="$SurfSharkCountry21"; fi # Using default value on enter keypress
              echo -e "${CGreen}Using value: "$SurfSharkCountry2
              echo -e "${CCyan}"
              read -p "Enter Country #3 (Use 0 for blank) (Default = $SurfSharkCountry3): " SurfSharkCountry31
              if [ -z "$SurfSharkCountry31" ]; then SurfSharkCountry31="$SurfSharkCountry3"; else SurfSharkCountry3="$SurfSharkCountry31"; fi # Using default value on enter keypress
              echo -e "${CGreen}Using value: "$SurfSharkCountry3
          else
            SurfSharkMultipleCountries=0
            SurfSharkCountry2=0
            SurfSharkCountry3=0
          fi
        else
          SurfSharkMultipleCountries=0
          SurfSharkCountry2=0
          SurfSharkCountry3=0
        fi
        # -----------------------------------------------------------------------------------------
        echo ""
        echo -e "${CCyan}6d. At what % VPN server load would you like to reconnect to a different"
        echo -e "${CCyan}SurfShark Server? ${CYellow}(Default = $SurfSharkLoadReset)${CClear}"
        read -p "% Server Load Threshold: " SurfSharkLoadReset1
        if [ -z "$SurfSharkLoadReset1" ]; then SurfSharkLoadReset1=$SurfSharkLoadReset; else SurfSharkLoadReset=$SurfSharkLoadReset1; fi # Using default value on enter keypress
        echo -e "${CGreen}Using value: "$SurfSharkLoadReset
        # -----------------------------------------------------------------------------------------
      else
        UseSurfShark=0
        SurfSharkSuperRandom=0
        SurfSharkMultipleCountries=0
        SurfSharkCountry="United States"
        SurfSharkCountry2=0
        SurfSharkCountry3=0
        SurfSharkLoadReset=50
      fi

      # -----------------------------------------------------------------------------------------
      # Perfect Privacy Logic
      # -----------------------------------------------------------------------------------------

      if [ $VPNProvider == "3" ]; then # Perfect Privacy
        UsePP=1

        echo ""
        echo -e "${CCyan}6a. Would you like to use the Perfect Privacy SuperRandom functionality?"
        echo -e "${CYellow}(No=0, Yes=1) (Default = $PPSuperRandom)${CClear}"
        while true; do
          read -p "Use SuperRandom? (0/1): " PPSuperRandom1
            case $PPSuperRandom1 in
              [0] ) echo -e "${CGreen}Using value: 0 (No)${CClear}";PPSuperRandom=0;break ;;
              [1] ) echo -e "${CGreen}Using value: 1 (Yes)${CClear}";PPSuperRandom=1;break ;;
              "" ) echo -e "${CGreen}Using value: $PPSuperRandom${CClear}";PPSuperRandom1=$PPSuperRandom;break ;;
              * ) echo -e "\nPlease answer 0 or 1, or Enter to accept default value.";;
            esac
        done
        # -----------------------------------------------------------------------------------------
        echo ""
        echo -e "${CCyan}6b. What Country is your country of origin for Perfect Privacy? ${CYellow}(Default = "
        echo -e "${CYellow}$PPCountry). NOTE: Country names must be spelled correctly as below!"
        echo -e "${CCyan}Valid country names as follows: Australia, Austria, Canada, China,"
        echo -e "${CCyan}Czech Republic, Denmark, France, Germany, Iceland, Israel, Italy,"
        echo -e "${CCyan}Japan, Latvia, Netherlands, Norway, Poland, Romania, Russia, Serbia,"
        echo -e "${CCyan}Singapore, Spain, Sweden, Switzerland, Turkey, U.S.A., United Kingdom${CClear}"
        read -p 'Perfect Prviacy Country: ' PPCountry1
        if [ -z "$PPCountry1" ]; then PPCountry1="$PPCountry"; else PPCountry="$PPCountry1"; fi # Using default value on enter keypress
        echo -e "${CGreen}Using value: "$PPCountry
        # -----------------------------------------------------------------------------------------
        if [ "$PPSuperRandom" == "1" ]; then
          echo ""
          echo -e "${CCyan}6c. Would you like to randomize connections across multiple countries?"
          echo -e "${CCyan}NOTE: A maximum of 2 additional country names can be added. (Total of 3)"
          echo -e "${CYellow}(No=0, Yes=1) (Default = $PPMultipleCountries)${CClear}"
          while true; do
            read -p "Use Multiple Countries? (0/1): " PPMultipleCountries1
              case $PPMultipleCountries1 in
                [0] ) echo -e "${CGreen}Using value: 0 (No)${CClear}";PPMultipleCountries=0;break ;;
                [1] ) echo -e "${CGreen}Using value: 1 (Yes)${CClear}";PPMultipleCountries=1;break ;;
                "" ) echo -e "${CGreen}Using value: $PPMultipleCountries${CClear}";PPMultipleCountries1=$PPMultipleCountries;break ;;
                * ) echo -e "\nPlease answer 0 or 1, or Enter to accept default value.";;
              esac
          done
          if [ $PPMultipleCountries == "1" ]; then
              echo -e "${CCyan}"
              read -p "Enter Country #2 (Use 0 for blank) (Default = $PPCountry2): " PPCountry21
              if [ -z "$PPCountry21" ]; then PPCountry21="$PPCountry2"; else PPCountry2="$PPCountry21"; fi # Using default value on enter keypress
              echo -e "${CGreen}Using value: "$PPCountry2
              echo -e "${CCyan}"
              read -p "Enter Country #3 (Use 0 for blank) (Default = $PPCountry3): " PPCountry31
              if [ -z "$PPCountry31" ]; then PPCountry31="$PPCountry3"; else PPCountry3="$PPCountry31"; fi # Using default value on enter keypress
              echo -e "${CGreen}Using value: "$PPCountry3
          else
            PPMultipleCountries=0
            PPCountry2=0
            PPCountry3=0
          fi
        else
          PPMultipleCountries=0
          PPCountry2=0
          PPCountry3=0
        fi
        # -----------------------------------------------------------------------------------------
        echo ""
        echo -e "${CCyan}6d. At what VPN server load would you like to reconnect to a different"
        echo -e "${CCyan}Perfect Privacy Server? ${CYellow}(Default = $PPLoadReset)${CClear}"
        read -p "% Server Load Threshold: " PPLoadReset1
        if [ -z "$PPLoadReset1" ]; then PPLoadReset1=$PPLoadReset; else PPLoadReset=$PPLoadReset1; fi # Using default value on enter keypress
        echo -e "${CGreen}Using value: "$PPLoadReset
        # -----------------------------------------------------------------------------------------
        echo ""
        echo -e "${CCyan}6e. Would you like to whitelist Perfect Privacy VPN servers in the Skynet"
        echo -e "${CCyan}Firewall? ${CYellow}(No=0, Yes=1) (Default = $UpdateSkynet)${CClear}"
        while true; do
          read -p "Update Skynet? (0/1): " UpdateSkynet1
            case $UpdateSkynet1 in
              [0] ) echo -e "${CGreen}Using value: 0 (No)${CClear}";UpdateSkynet=0;break ;;
              [1] ) echo -e "${CGreen}Using value: 1 (Yes)${CClear}";UpdateSkynet=1;break ;;
              "" ) echo -e "${CGreen}Using value: $UpdateSkynet${CClear}";UpdateSkynet1=$UpdateSkynet;break ;;
              * ) echo -e "\nPlease answer 0 or 1, or Enter to accept default value.";;
            esac
        done
      else
        UsePP=0
        PPSuperRandom=0
        PPMultipleCountries=0
        PPCountry="U.S.A."
        PPCountry2=0
        PPCountry3=0
        PPLoadReset=50
      fi

      # -----------------------------------------------------------------------------------------
      # VPN Service Not Listed Logic
      # -----------------------------------------------------------------------------------------

      if [ $VPNProvider == "4" ]; then # Not Listed
        UseNordVPN=0
        NordVPNSuperRandom=0
        NordVPNMultipleCountries=0
        NordVPNCountry="United States"
        NordVPNCountry2=0
        NordVPNCountry3=0
        NordVPNLoadReset=50
        UpdateSkynet=0

        UseSurfShark=0
        SurfSharkSuperRandom=0
        SurfSharkMultipleCountries=0
        SurfSharkCountry="United States"
        SurfSharkCountry2=0
        SurfSharkCountry3=0
        SurfSharkLoadReset=50

        UsePP=0
        PPSuperRandom=0
        PPMultipleCountries=0
        PPCountry="U.S.A."
        PPCountry2=0
        PPCountry3=0
        PPLoadReset=50
      fi

      # -----------------------------------------------------------------------------------------
      echo ""
      echo -e "${CCyan}7. Would you like to reset your VPN connection to a random VPN client"
      echo -e "${CCyan}slot daily? ${CYellow}(No=0, Yes=1) (Default = $ResetOption)${CClear}"
      while true; do
        read -p "Reset Daily? (0/1): " ResetOption1
          case $ResetOption1 in
            [0] ) echo -e "${CGreen}Using value: 0 (No)${CClear}";ResetOption=0;break ;;
            [1] ) echo -e "${CGreen}Using value: 1 (Yes)${CClear}";ResetOption=1;break ;;
            "" ) echo -e "${CGreen}Using value: $ResetOption${CClear}";ResetOption1=$ResetOption;break ;;
            * ) echo -e "\nPlease answer 0 or 1, or Enter to accept default value.";;
          esac
      done
      # -----------------------------------------------------------------------------------------
      if [ $ResetOption == "1" ]; then
        echo ""
        echo -e "${CCyan}7a. What time would you like to reset your connection?"
        echo -e "${CYellow}(Default = $DailyResetTime)${CClear}"
        read -p 'Reset Time (in HH:MM 24h): ' DailyResetTime1
        if [ -z "$DailyResetTime1" ]; then DailyResetTime1="$DailyResetTime"; else DailyResetTime="$DailyResetTime1"; fi # Using default value on enter keypress
        echo -e "${CGreen}Using value: "$DailyResetTime
      else
        ResetOption=0
        DailyResetTime="00:00"
      fi
      # -----------------------------------------------------------------------------------------
      echo ""
      echo -e "${CCyan}8. What is the minimum acceptable PING value in milliseconds across"
      echo -e "${CCyan}your VPN tunnel before VPNMON-R2 resets the connection in search for"
      echo -e "${CCyan}a faster/lower PING server? ${CYellow}(Default = $MINPING)${CClear}"
      read -p 'Minimum PING (in ms): ' MINPING1
      if [ -z "$MINPING1" ]; then MINPING1=$MINPING; else MINPING=$MINPING1; fi # Using default value on enter keypress
      echo -e "${CGreen}Using value: "$MINPING
      # -----------------------------------------------------------------------------------------
      echo ""
      echo -e "${CCyan}9. How many VPN client slots do you have properly configured? Please"
      echo -e "${CCyan}note: VPN client slots MUST be in sequential order, starting from 1"
      echo -e "${CCyan}through 5. (Example: if you are using slots 1, 2 and 3, but 4 and 5"
      echo -e "${CCyan}are disabled, you would enter 3. ${CYellow}(Default = $N)${CClear}"
      read -p 'VPN Clients: ' N1
      if [ -z "$N1" ]; then N1=$N; else N=$N1; fi # Using default value on enter keypress
      echo -e "${CGreen}Using value: "$N
      # -----------------------------------------------------------------------------------------
      echo ""
      echo -e "${CCyan}10. Would you like to show near-realtime VPN bandwidth stats on the UI?"
      echo -e "${CYellow}(No=0, Yes=1) (Default = $SHOWSTATS)${CClear}"
      while true; do
        read -p "Show Stats? (0/1): " SHOWSTATS1
          case $SHOWSTATS1 in
            [0] ) echo -e "${CGreen}Using value: 0 (No)${CClear}";SHOWSTATS=0;break ;;
            [1] ) echo -e "${CGreen}Using value: 1 (Yes)${CClear}";SHOWSTATS=1;break ;;
            "" ) echo -e "${CGreen}Using value: $SHOWSTATS${CClear}";SHOWSTATS1=$SHOWSTATS;break ;;
            * ) echo -e "\nPlease answer 0 or 1, or Enter to accept default value.";;
          esac
      done
      # -----------------------------------------------------------------------------------------
      echo ""
      echo -e "${CCyan}11. How many seconds would you like to delay start-up of VPNMON-R2 in"
      echo -e "${CCyan}order to provide more stability among other competing start-up scripts"
      echo -e "${CCyan}during a reboot? ${CYellow}(Default = $DelayStartup)${CClear}"
      read -p 'Delay Startup (seconds): ' DelayStartup1
      if [ -z "$DelayStartup1" ]; then DelayStartup1=$DelayStartup; else DelayStartup=$DelayStartup1; fi # Using default value on enter keypress
      echo -e "${CGreen}Using value: "$DelayStartup
      # -----------------------------------------------------------------------------------------
      echo ""
      echo -e "${CCyan}12. Would you like to trim your log file when your VPN connection resets?"
      echo -e "${CYellow}(No=0, Yes=1) (Default = $TRIMLOGS)${CClear}"
      while true; do
        read -p "Trim Logs? (0/1): " TRIMLOGS1
          case $TRIMLOGS1 in
            [0] ) echo -e "${CGreen}Using value: 0 (No)${CClear}";TRIMLOGS=0;break ;;
            [1] ) echo -e "${CGreen}Using value: 1 (Yes)${CClear}";TRIMLOGS=1;break ;;
            "" ) echo -e "${CGreen}Using value: $TRIMLOGS${CClear}";TRIMLOGS1=$TRIMLOGS;break ;;
            * ) echo -e "\nPlease answer 0 or 1, or Enter to accept default value.";;
          esac
      done
      # -----------------------------------------------------------------------------------------
      if [ $TRIMLOGS == "1" ]; then
          echo ""
        echo -e "${CCyan}12a. How large would you like your log file to grow (in # of lines)?"
        echo -e "${CCyan}This option will automatically trim your log after each VPN reset."
        echo -e "${CYellow}(Default = $MAXLOGSIZE lines)${CClear}"
        read -p 'Log file size (in # of lines): ' MAXLOGSIZE1
        if [ -z "$MAXLOGSIZE1" ]; then MAXLOGSIZE1=$MAXLOGSIZE; else MAXLOGSIZE=$MAXLOGSIZE1; fi # Using default value on enter keypress
        echo -e "${CGreen}Using value: "$MAXLOGSIZE
      else
        TRIMLOGS=0
        MAXLOGSIZE=1000
      fi
      # -----------------------------------------------------------------------------------------
      echo ""
      echo -e "${CCyan}13. Would you like to sync the active VPN slot with YazFi?"
      echo -e "${CYellow}(No=0, Yes=1) (Default = $SyncYazFi)${CClear}"
      while true; do
        read -p "Sync YazFi? (0/1): " SyncYazFi1
          case $SyncYazFi1 in
            [0] ) echo -e "${CGreen}Using value: 0 (No)${CClear}";SyncYazFi=0;break ;;
            [1] ) echo -e "${CGreen}Using value: 1 (Yes)${CClear}";SyncYazFi=1;break ;;
            "" ) echo -e "${CGreen}Using value: $SyncYazFi${CClear}";SyncYazFi1=$SyncYazFi;break ;;
            * ) echo -e "\nPlease answer 0 or 1, or Enter to accept default value.";;
          esac
      done
      # -----------------------------------------------------------------------------------------
      if [ $SyncYazFi == "1" ]; then
        echo ""
        echo -e "${CCyan}13a. Please indicate which of your YazFi guest network slots you want to"
        echo -e "${CCyan}sync with the active VPN slot?${CClear}"
        echo ""
        echo -e "${CYellow}2.4Ghz - Guest Network 1? ${CYellow}(No=0, Yes=1) (Default = $YF24GN1)${CClear}"
        while true; do
          read -p "Please select? (0/1): " YF24GN11
            case $YF24GN11 in
              [0] ) echo -e "${CGreen}Using value: 0 (No)${CClear}";YF24GN1=0;break ;;
              [1] ) echo -e "${CGreen}Using value: 1 (Yes)${CClear}";YF24GN1=1;break ;;
              "" ) echo -e "${CGreen}Using value: $YF24GN1${CClear}";YF24GN11=$YF24GN1;break ;;
              * ) echo -e "\nPlease answer 0 or 1, or Enter to accept default value.";;
            esac
        done
        echo ""
        echo -e "${CYellow}2.4Ghz - Guest Network 2? ${CYellow}(No=0, Yes=1) (Default = $YF24GN2)${CClear}"
        while true; do
          read -p "Please select? (0/1): " YF24GN21
            case $YF24GN21 in
              [0] ) echo -e "${CGreen}Using value: 0 (No)${CClear}";YF24GN2=0;break ;;
              [1] ) echo -e "${CGreen}Using value: 1 (Yes)${CClear}";YF24GN2=1;break ;;
              "" ) echo -e "${CGreen}Using value: $YF24GN2${CClear}";YF24GN21=$YF24GN2;break ;;
              * ) echo -e "\nPlease answer 0 or 1, or Enter to accept default value.";;
            esac
        done
        echo ""
        echo -e "${CYellow}2.4Ghz - Guest Network 3? ${CYellow}(No=0, Yes=1) (Default = $YF24GN3)${CClear}"
        while true; do
          read -p "Please select? (0/1): " YF24GN31
            case $YF24GN31 in
              [0] ) echo -e "${CGreen}Using value: 0 (No)${CClear}";YF24GN3=0;break ;;
              [1] ) echo -e "${CGreen}Using value: 1 (Yes)${CClear}";YF24GN3=1;break ;;
              "" ) echo -e "${CGreen}Using value: $YF24GN3${CClear}";YF24GN31=$YF24GN3;break ;;
              * ) echo -e "\nPlease answer 0 or 1, or Enter to accept default value.";;
            esac
        done
        echo ""
        echo -e "${CYellow}5Ghz - Guest Network 1? ${CYellow}(No=0, Yes=1) (Default = $YF5GN1)${CClear}"
        while true; do
          read -p "Please select? (0/1): " YF5GN11
            case $YF5GN11 in
              [0] ) echo -e "${CGreen}Using value: 0 (No)${CClear}";YF5GN1=0;break ;;
              [1] ) echo -e "${CGreen}Using value: 1 (Yes)${CClear}";YF5GN1=1;break ;;
              "" ) echo -e "${CGreen}Using value: $YF5GN1${CClear}";YF5GN11=$YF5GN1;break ;;
              * ) echo -e "\nPlease answer 0 or 1, or Enter to accept default value.";;
            esac
        done
        echo ""
        echo -e "${CYellow}5Ghz - Guest Network 2? ${CYellow}(No=0, Yes=1) (Default = $YF5GN2)${CClear}"
        while true; do
          read -p "Please select? (0/1): " YF5GN21
            case $YF5GN21 in
              [0] ) echo -e "${CGreen}Using value: 0 (No)${CClear}";YF5GN2=0;break ;;
              [1] ) echo -e "${CGreen}Using value: 1 (Yes)${CClear}";YF5GN2=1;break ;;
              "" ) echo -e "${CGreen}Using value: $YF5GN2${CClear}";YF5GN21=$YF5GN2;break ;;
              * ) echo -e "\nPlease answer 0 or 1, or Enter to accept default value.";;
            esac
        done
        echo ""
        echo -e "${CYellow}5Ghz - Guest Network 3? ${CYellow}(No=0, Yes=1) (Default = $YF5GN3)${CClear}"
        while true; do
          read -p "Please select? (0/1): " YF5GN31
            case $YF5GN31 in
              [0] ) echo -e "${CGreen}Using value: 0 (No)${CClear}";YF5GN3=0;break ;;
              [1] ) echo -e "${CGreen}Using value: 1 (Yes)${CClear}";YF5GN3=1;break ;;
              "" ) echo -e "${CGreen}Using value: $YF5GN3${CClear}";YF5GN31=$YF5GN3;break ;;
              * ) echo -e "\nPlease answer 0 or 1, or Enter to accept default value.";;
            esac
        done
        echo ""
        echo -e "${CYellow}5Ghz (Secondary) - Guest Network 1? ${CYellow}(No=0, Yes=1) (Default = $YF52GN1)${CClear}"
        while true; do
          read -p "Please select? (0/1): " YF52GN11
            case $YF52GN11 in
              [0] ) echo -e "${CGreen}Using value: 0 (No)${CClear}";YF52GN1=0;break ;;
              [1] ) echo -e "${CGreen}Using value: 1 (Yes)${CClear}";YF52GN1=1;break ;;
              "" ) echo -e "${CGreen}Using value: $YF52GN1${CClear}";YF52GN11=$YF52GN1;break ;;
              * ) echo -e "\nPlease answer 0 or 1, or Enter to accept default value.";;
            esac
        done
        echo ""
        echo -e "${CYellow}5Ghz (Secondary) - Guest Network 2? ${CYellow}(No=0, Yes=1) (Default = $YF52GN2)${CClear}"
        while true; do
          read -p "Please select? (0/1): " YF52GN21
            case $YF52GN21 in
              [0] ) echo -e "${CGreen}Using value: 0 (No)${CClear}";YF52GN2=0;break ;;
              [1] ) echo -e "${CGreen}Using value: 1 (Yes)${CClear}";YF52GN2=1;break ;;
              "" ) echo -e "${CGreen}Using value: $YF52GN2${CClear}";YF52GN21=$YF52GN2;break ;;
              * ) echo -e "\nPlease answer 0 or 1, or Enter to accept default value.";;
            esac
        done
        echo ""
        echo -e "${CYellow}5Ghz (Secondary) - Guest Network 3? ${CYellow}(No=0, Yes=1) (Default = $YF52GN3)${CClear}"
        while true; do
          read -p "Please select? (0/1): " YF52GN31
            case $YF52GN31 in
              [0] ) echo -e "${CGreen}Using value: 0 (No)${CClear}";YF52GN3=0;break ;;
              [1] ) echo -e "${CGreen}Using value: 1 (Yes)${CClear}";YF52GN3=1;break ;;
              "" ) echo -e "${CGreen}Using value: $YF52GN3${CClear}";YF52GN31=$YF52GN3;break ;;
              * ) echo -e "\nPlease answer 0 or 1, or Enter to accept default value.";;
            esac
        done
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
      # -----------------------------------------------------------------------------------------
      logo
      echo -e "${CCyan}Configuration of VPNMON-R2 is complete.  Would you like to save this config?${CClear}"
      if promptyNo; then
        { echo 'TRIES='$TRIES
          echo 'INTERVAL='$INTERVAL
          echo 'PINGHOST="'"$PINGHOST"'"'
          echo 'UpdateVPNMGR='$UpdateVPNMGR
          echo 'USELOWESTSLOT='$USELOWESTSLOT
          echo 'PINGCHANCES='$PINGCHANCES
          echo 'UseNordVPN='$UseNordVPN
          echo 'NordVPNSuperRandom='$NordVPNSuperRandom
          echo 'NordVPNMultipleCountries='$NordVPNMultipleCountries
          echo 'NordVPNCountry="'"$NordVPNCountry"'"'
          echo 'NordVPNCountry2="'"$NordVPNCountry2"'"'
          echo 'NordVPNCountry3="'"$NordVPNCountry3"'"'
          echo 'NordVPNLoadReset='$NordVPNLoadReset
          echo 'UseSurfShark='$UseSurfShark
          echo 'SurfSharkSuperRandom='$SurfSharkSuperRandom
          echo 'SurfSharkMultipleCountries='$SurfSharkMultipleCountries
          echo 'SurfSharkCountry="'"$SurfSharkCountry"'"'
          echo 'SurfSharkCountry2="'"$SurfSharkCountry2"'"'
          echo 'SurfSharkCountry3="'"$SurfSharkCountry3"'"'
          echo 'SurfSharkLoadReset='$SurfSharkLoadReset
          echo 'UsePP='$UsePP
          echo 'PPSuperRandom='$PPSuperRandom
          echo 'PPMultipleCountries='$PPMultipleCountries
          echo 'PPCountry="'"$PPCountry"'"'
          echo 'PPCountry2="'"$PPCountry2"'"'
          echo 'PPCountry3="'"$PPCountry3"'"'
          echo 'PPLoadReset='$PPLoadReset
          echo 'UpdateSkynet='$UpdateSkynet
          echo 'ResetOption='$ResetOption
          echo 'DailyResetTime="'"$DailyResetTime"'"'
          echo 'MINPING='$MINPING
          echo 'N='$N
          echo 'SHOWSTATS='$SHOWSTATS
          echo 'DelayStartup='$DelayStartup
          echo 'TRIMLOGS='$TRIMLOGS
          echo 'MAXLOGSIZE='$MAXLOGSIZE
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
          printf '%b\n' "${CGreen}\nDiscarding changes and exiting setup.${CClear}"
          echo ""
          sleep 2
          return
      fi
      echo ""
      echo -e "${CYellow}Would you like to start VPNMON-R2 now?${CClear}"
      if promptyNo; then
        sh $APPPATH -monitor
      else
        echo ""
        printf '%b\n' "${CGreen}\nExecute VPNMON-R2 using command 'vpnmon-r2.sh -monitor' for normal operations${CClear}"
        echo ""
        sleep 2
        return
      fi
    else
      #Create a new config file with default values to get it to a basic running state
      { echo 'TRIES=3'
        echo 'INTERVAL=60'
        echo 'PINGHOST="8.8.8.8"'
        echo 'UpdateVPNMGR=0'
        echo 'USELOWESTSLOT=0'
        echo 'PINGCHANCES=5'
        echo 'UseNordVPN=0'
        echo 'NordVPNSuperRandom=0'
        echo 'NordVPNMultipleCountries=0'
        echo 'NordVPNCountry="United States"'
        echo 'NordVPNCountry2=0'
        echo 'NordVPNCountry3=0'
        echo 'NordVPNLoadReset=50'
        echo 'UseSurfShark=0'
        echo 'SurfSharkSuperRandom=0'
        echo 'SurfSharkMultipleCountries=0'
        echo 'SurfSharkCountry="United States"'
        echo 'SurfSharkCountry2=0'
        echo 'SurfSharkCountry3=0'
        echo 'SurfSharkLoadReset=50'
        echo 'UsePP=0'
        echo 'PPSuperRandom=0'
        echo 'PPMultipleCountries=0'
        echo 'PPCountry="U.S.A."'
        echo 'PPCountry2=0'
        echo 'PPCountry3=0'
        echo 'PPLoadReset=50'
        echo 'UpdateSkynet=0'
        echo 'ResetOption=1'
        echo 'DailyResetTime="01:00"'
        echo 'MINPING=100'
        echo 'N=5'
        echo 'SHOWSTATS=0'
        echo 'DelayStartup=0'
        echo 'TRIMLOGS=0'
        echo 'MAXLOGSIZE=1000'
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
      vconfig
  fi
}

# -------------------------------------------------------------------------------------------------------------------------

# vupdate is a function that provides a UI to check for script updates and allows you to install the latest version...
vupdate () {
  updatecheck # Check for the latest version from source repository
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
      sleep 2
      return
    else
      echo -e "${CCyan}Would you like to update to the latest version?${CClear}"
      if promptyn "(Yes/No): "; then
        echo ""
        echo -e "${CCyan}Updating VPNMON-R2 to ${CYellow}v$DLVersion${CClear}"
        curl --silent --retry 3 "https://raw.githubusercontent.com/ViktorJp/VPNMON-R2/master/vpnmon-r2-$DLVersion.sh" -o "/jffs/scripts/vpnmon-r2.sh" && chmod a+rx "/jffs/scripts/vpnmon-r2.sh"
        echo ""
        echo -e "${CCyan}Update successful!${CClear}"
        echo -e "$(date) - VPNMON-R2 - Successfully updated VPNMON-R2 from v$Version to v$DLVersion" >> $LOGFILE
        echo ""
        echo -e "${CYellow}Please exit, restart and configure new options using: 'vpnmon-r2.sh -config'.${CClear}"
        echo -e "${CYellow}NOTE: New features may have been added that require your input for full${CClear}"
        echo -e "${CYellow}functionality.${CClear}"
        echo ""
        read -rsp $'Press any key to continue...\n' -n1 key
        return
      else
        echo ""
        echo ""
        echo -e "${CGreen}Exiting Update Utility...${CClear}"
        echo ""
        sleep 1
        return
      fi
  fi
}

# -------------------------------------------------------------------------------------------------------------------------

# vuninstall is a function that uninstalls and removes all traces of VPNMON-R2 from your router...
vuninstall () {
  clear
  logo
  echo -e "VPNMON-R2 v$Version Uninstall Utility${CClear}"
  echo ""
  echo -e "${CCyan}You are about to uninstall VPNMON-R2!  This action is irreversible."
  echo -e "${CCyan}Do you wish to proceed?${CClear}"
  if promptyn "(Yes/No): "; then
    echo ""
    echo -e "${CCyan}Are you sure? Please type 'Yes' to validate you want to proceed.${CClear}"
      if promptyn "(Yes/No): "; then
        clear
        rm -r /jffs/addons/vpnmon-r2.d
        rm /jffs/scripts/vpnmon-r2.sh
        echo ""
        echo -e "${CGreen}VPNMON-R2 has been uninstalled...${CClear}"
        echo ""
        return
      else
        echo ""
        echo -e "${CGreen}Exiting Uninstall Utility...${CClear}"
        echo ""
        return
      fi
  else
    echo ""
    echo -e "${CGreen}Exiting Uninstall Utility...${CClear}"
    echo ""
    return
  fi
}

# -------------------------------------------------------------------------------------------------------------------------

# vsetup is a function that sets up and confiures VPNMON-R2 on your router...
vsetup () {
  while true; do
    clear
    logo
    echo -e "VPNMON-R2 v$Version Setup Utility${CClear}" # Provide main setup menu
    echo ""
    echo -e "${CGreen}--------------------------------------------------------------------"
    echo -e "${CCyan}"
    echo -e "${CCyan}1: Setup and Configure VPNMON-R2"
    echo -e "${CCyan}2: Force Re-install Entware Dependencies"
    echo -e "${CCyan}3: Check for latest updates"
    echo -e "${CCyan}4: Launch VPNMON-R2 into Normal Monitoring Mode"
    echo -e "${CCyan}5: Launch VPNMON-R2 into Normal Monitoring Mode using Screen utility"
    echo -e "${CCyan}u: Uninstall VPNMON-R2"
    echo -e "${CCyan}e: Exit"
    echo ""
    printf "Selection: "
    read -r InstallSelection

    # Execute chosen selections
        case "$InstallSelection" in

          1) # Check for existence of entware, and if so proceed and install the timeout package, then run vpnmon-r2 -config
            clear
            logo
            echo -e "${CYellow}Installing VPNMON-R2...${CClear}"
            echo ""
            echo -e "${CCyan}Would you like to optionally install the CoreUtils-Timeout${CClear}"
            echo -e "${CCyan}and Screen utility? These utilities require you to have Entware${CClear}"
            echo -e "${CCyan}already installed using the AMTM tool. If Entware is present, the ${CClear}"
            echo -e "${CCyan}Timeout and Screen utilities will be downloaded and installed during${CClear}"
            echo -e "${CCyan}this setup process, and used by VPNMON-R2.${CClear}"
            echo ""
            echo -e "${CGreen}CoreUtils-Timeout${CCyan} is a utility that provides more stability for${CClear}"
            echo -e "${CCyan}certain routers (like the RT-AC86U) which has a tendency to randomly${CClear}"
            echo -e "${CCyan}hang scripts running on this router model.${CClear}"
            echo ""
            echo -e "${CGreen}Screen${CCyan} is a utility that allows you to run SSH scripts in a standalone"
            echo -e "${CCyan}environment directly on the router itself, instead of running your"
            echo -e "${CCyan}commands or a script from a network-attached SSH client. This can"
            echo -e "${CCyan}provide greater stability due to it running from the router itself."
            echo ""
            RouterModel=$(nvram get model)
            echo -e "${CCyan}Your router model is: ${CYellow}$RouterModel"
            echo ""
            echo -e "${CCyan}Install?${CClear}"
            if promptyn "(Yes/No): "
              then
                if [ -d "/opt" ]; then # Does entware exist? If yes proceed, if no error out.
                  echo ""
                  echo -e "\n${CGreen}Updating Entware Packages...${CClear}"
                  echo ""
                  opkg update
                  echo ""
                  echo -e "${CGreen}Installing Entware CoreUtils-Timeout Package...${CClear}"
                  echo ""
                  opkg install coreutils-timeout
                  echo -e "${CGreen}Installing Entware Screen Package...${CClear}"
                  echo ""
                  opkg install screen
                  echo ""
                  sleep 1
                  echo -e "${CGreen}Executing VPNMON-R2 Configuration Utility...${CClear}"
                  sleep 2
                  vnconfig
                else
                  clear
                  echo -e "${CGreen}ERROR: Entware was not found on this router...${CClear}"
                  echo -e "${CGreen}Please install Entware using the AMTM utility before proceeding...${CClear}"
                  echo ""
                  sleep 3
                fi
              else
                echo ""
                echo -e "\n${CGreen}Executing VPNMON-R2 Configuration Utility...${CClear}"
                sleep 2
                vconfig
            fi
          ;;

          2) # Force re-install the CoreUtils timeout/screen package
            clear
            logo
            echo -e "${CYellow}Force Re-installing CoreUtils-Timeout/Screen Packages...${CClear}"
            echo ""
            echo -e "${CCyan}Would you like to optionally re-install the CoreUtils-Timeout${CClear}"
            echo -e "${CCyan}and Screen utility? These utilities require you to have Entware${CClear}"
            echo -e "${CCyan}already installed using the AMTM tool. If Entware is present, the ${CClear}"
            echo -e "${CCyan}Timeout and Screen utilities will be downloaded and installed during${CClear}"
            echo -e "${CCyan}this setup process, and used by VPNMON-R2.${CClear}"
            echo ""
            echo -e "${CGreen}CoreUtils-Timeout${CCyan} is a utility that provides more stability for${CClear}"
            echo -e "${CCyan}certain routers (like the RT-AC86U) which has a tendency to randomly${CClear}"
            echo -e "${CCyan}hang scripts running on this router model.${CClear}"
            echo ""
            echo -e "${CGreen}Screen${CCyan} is a utility that allows you to run SSH scripts in a standalone"
            echo -e "${CCyan}environment directly on the router itself, instead of running your"
            echo -e "${CCyan}commands or a script from a network-attached SSH client. This can"
            echo -e "${CCyan}provide greater stability due to it running from the router itself."
            echo ""
            RouterModel=$(nvram get model)
            echo -e "${CCyan}Your router model is: ${CYellow}$RouterModel"
            echo ""
            echo -e "${CCyan}Force Re-install?${CClear}"
            if promptyn "(Yes/No): "
              then
                if [ -d "/opt" ]; then # Does entware exist? If yes proceed, if no error out.
                  echo ""
                  echo -e "\n${CGreen}Updating Entware Packages...${CClear}"
                  echo ""
                  opkg update
                  echo ""
                  echo -e "${CGreen}Force Re-installing Entware CoreUtils-Timeout Package...${CClear}"
                  echo ""
                  opkg install --force-reinstall coreutils-timeout
                  echo -e "${CGreen}Force Re-installing Entware Screen Package...${CClear}"
                  echo ""
                  opkg install --force-reinstall screen
                  echo ""
                  echo -e "${CGreen}Re-install completed...${CClear}"
                  sleep 2
                else
                  clear
                  echo -e "${CGreen}ERROR: Entware was not found on this router...${CClear}"
                  echo -e "${CGreen}Please install Entware using the AMTM utility before proceeding...${CClear}"
                  echo ""
                  sleep 3
                fi
            fi
          ;;

          3)
            echo ""
            vupdate
          ;;

          4)
            echo ""
            echo -e "\n${CGreen}Launching VPNMON-R2 into Monitor Mode...${CClear}"
            sleep 2
            sh $APPPATH -monitor
          ;;

          5)
            echo ""
            echo -e "\n${CGreen}Launching VPNMON-R2 into Monitor Mode with Screen Utility...${CClear}"
            sleep 2
            sh $APPPATH -screen
          ;;

          u)
            echo ""
            vuninstall
          ;;

          e)
            echo ""
            exit 0
          ;;

          *)
            echo ""
            echo -e "${CRed}Invalid choice - Please enter a valid option...${CClear}"
            echo ""
            sleep 2
          ;;

        esac
  done
}

# -------------------------------------------------------------------------------------------------------------------------
# Begin Commandline Argument Gatekeeper and Configuration Utility Functionality
# -------------------------------------------------------------------------------------------------------------------------

#DEBUG=; set -x # uncomment/comment to enable/disable debug mode
#{              # uncomment/comment to enable/disable debug mode

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
  if [ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "-config" ] || [ "$1" == "-monitor" ] || [ "$1" == "-log" ] || [ "$1" == "-update" ] || [ "$1" == "-setup" ] || [ "$1" == "-uninstall" ] || [ "$1" == "-screen" ] || [ "$1" == "-quit" ]
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
    echo "vpnmon-r2.sh -setup"
    echo "vpnmon-r2.sh -uninstall"
    echo "vpnmon-r2.sh -screen"
    echo "vpnmon-r2.sh -monitor"
    echo ""
    echo " -h | -help (this output)"
    echo " -log (display the current log contents)"
    echo " -config (configuration/setup utility)"
    echo " -update (script update utility)"
    echo " -setup (setup/dependencies utility)"
    echo " -uninstall (uninstall utility)"
    echo " -screen (normal VPN monitoring using the screen utility)"
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
      vconfig
      exit 0
  fi

  # Check to see if the update option is being called
  if [ "$1" == "-update" ]
    then
      vupdate
      exit 0
  fi

  # Check to see if the install option is being called
  if [ "$1" == "-setup" ]
    then
      vsetup
  fi

  # Check to see if the uninstall option is being called
  if [ "$1" == "-uninstall" ]
    then
      vuninstall
      exit 0
  fi

  # Check to see if the screen option is being called and run operations normally using the screen utility
  if [ "$1" == "-screen" ]
    then
      clear
      echo -e "${CGreen}Executing VPNMON-R2 using the SCREEN utility...${CClear}"
      echo ""
      echo -e "${CGreen}Reconnect at any time using the command 'screen -r vpnmon-r2'${CClear}"
      echo -e "${CGreen}To exit the SCREEN session, type: CTRL-A + D${CClear}"
      echo ""
      screen -dmS "vpnmon-r2" $APPPATH -monitor
      sleep 2
      read -rsp $'Press any key to continue...\n' -n1 key
      exit 0
  fi

  # Check to see if the monitor option is being called and run operations normally
  if [ "$1" == "-monitor" ]
    then
      clear
      if [ -f $CFGPATH ]; then
        source $CFGPATH

          if [ -f "/opt/bin/timeout" ] # If the timeout utility is available then use it and assign variables
            then
              timeoutcmd="timeout "
              timeoutsec="10"
              timeoutlng="60"
            else
              timeoutcmd=""
              timeoutsec=""
              timeoutlng=""
          fi

          if [ $DelayStartup != "0" ]
            then
              SPIN=$DelayStartup
              echo -e "${CGreen}Delaying VPNMON-R2 start-up for $DelayStartup seconds..."
              spinner
          fi

    else
      echo -e "${CRed}Error: VPNMON-R2 is not configured.  Please run 'vpnmon-r2.sh -setup' to complete setup${CClear}"
      echo ""
      echo -e "$(date) - VPNMON-R2 ----------> ERROR: vpnmon-r2.cfg was not found. Please run the setup tool." >> $LOGFILE
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

  # Write persistence logfile
  echo -e "$(date +%s)" > $PERSIST

  # Testing to see if VPNON is currently running, and if so, hold off until it finishes
  while test -f "$LOCKFILE"; do
    # clear screen
    clear && clear
    SPIN=15
    echo ""
    echo -e "${CRed}-----------------> NOTICE: VPNON ACTIVE <-----------------"
    echo ""
    echo -e "${CGreen}VPNON is currently performing a scheduled reset of the VPN."
    echo -e "${CGreen}Retrying for normal operations every $SPIN seconds...${CClear}\n"
    echo -e "$(date +%s)" > $RSTFILE
    START=$(cat $RSTFILE)
    spinner

    # Reset the VPN IP/Locations after a reset occurred
    VPNIP="Unassigned" # Look for a new VPN IP/Location
    ICANHAZIP="" # Reset Public VPN IP
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

  if [ $ResetOption -eq 1 ]
    then
      currentepoch=$(date +%s)
      ConvDailyResetTime=$(date -d $DailyResetTime +%H:%M)
      ConvDailyResetTimeEpoch=$(date -d $ConvDailyResetTime +%s)
      variance=$(( $ConvDailyResetTimeEpoch + (( $INTERVAL*2 ))))

      # If the configured time is within 2 minutes of the current time, reset the VPN connection
      if [ $currentepoch -gt $ConvDailyResetTimeEpoch ] && [ $currentepoch -lt $variance ]
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
          while [ $i -le $INTERVAL ]
          do
              preparebar 51 "|"
              progressbar $i $INTERVAL
              sleep 1
              i=$(($i+1))
          done

          PINGLOW=0 # Reset ping time history variables
          PINGHIGH=0
          ICANHAZIP=""
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

  # Display title/version
  echo -e "${CYellow}   _    ______  _   ____  _______  _   __      ____ ___  "
  echo -e "  | |  / / __ \/ | / /  |/  / __ \/ | / /     / __ \__ \  ${CGreen}v$Version${CYellow}"
  echo -e "  | | / / /_/ /  |/ / /|_/ / / / /  |/ /_____/ /_/ /_/ / ${CRed}(S)${CGreen}etup${CYellow}"
  echo -e "  | |/ / ____/ /|  / /  / / /_/ / /|  /_____/ _, _/ __/  ${CRed}(R)${CGreen}eset${CYellow}"
  echo -e "  |___/_/   /_/ |_/_/  /_/\____/_/ |_/     /_/ |_/____/  ${CRed}(E)${CGreen}xit${CClear}"

  # Display update notification if an update becomes available through source repository
  if [ "$UpdateNotify" != "0" ]; then
    echo -e "${CRed}  $UpdateNotify${CClear}"
    echo -e "${CGreen} ____________${CClear}"
  else
    echo -e "${CGreen} ____________${CClear}"
  fi

  echo -e "${CGreen}/${CRed}General Info${CClear}${CGreen}\____________________________________________________${CClear}"
  echo ""

  # Show the date and time
  echo -e "${CWhite} $(date)${CGreen} -------- ${CYellow}Last Reset: ${InvBlue}$LASTVPNRESET${CClear}"

  # Determine if a VPN Client is active, first by getting the VPN state from NVRAM
  state1=$($timeoutcmd$timeoutsec nvram get vpn_client1_state)
  state2=$($timeoutcmd$timeoutsec nvram get vpn_client2_state)
  state3=$($timeoutcmd$timeoutsec nvram get vpn_client3_state)
  state4=$($timeoutcmd$timeoutsec nvram get vpn_client4_state)
  state5=$($timeoutcmd$timeoutsec nvram get vpn_client5_state)

  # Determine the WAN states along with the Public IP of your VPN connection
  wstate0=$($timeoutcmd$timeoutsec nvram get wan0_state_t)
  wstate1=$($timeoutcmd$timeoutsec nvram get wan1_state_t)
  if [ -z $ICANHAZIP ]; then ICANHAZIP="Probing"; fi

  # Display the VPN and WAN states along with the public VPN IP and other info
  echo -e "${CCyan} VPN State 1:$state1 2:$state2 3:$state3 4:$state4 5:$state5${CClear}${CGreen} ---- ${CYellow}Public VPN IP: ${InvBlue}$ICANHAZIP${CClear}"

  if [ $ResetOption -eq 1 ]
    then
      echo -e "${CCyan} WAN State 0:$wstate0 1:$wstate1${CGreen} ------------------ ${CYellow}Sched Reset: ${InvBlue}$ConvDailyResetTime${CClear}${CYellow} / ${InvBlue}$INTERVAL Sec${CClear}"
    else
      echo -e "${CCyan} WAN State 0:$wstate0 1:$wstate1${CGreen} --------------------- ${CYellow}Interval: ${InvBlue}$INTERVAL Sec${CClear}"
  fi

  echo -e "${CGreen} __________${CClear}"
  echo -e "${CGreen}/${CRed}Interfaces${CClear}${CGreen}\______________________________________________________${CClear}"
  echo ""

  # Cycle through the WANCheck connection function to display ping/city info
  i=0
  for i in 0 1
    do
      wancheck $i
  done

  echo -e "${CGreen} -----------------------------------------------------------------${CClear}"

  # Cycle through the CheckVPN connection function for N number of VPN Clients
  i=0
  while [ $i -ne $N ]
    do
      i=$(($i+1))
      checkvpn $i $((state$i))
  done

  # Determine whether to show all the stats based on user preference
  if [ $SHOWSTATS == "1" ]
    then

      echo -e "${CGreen} _________"
      echo -e "${CGreen}/${CRed}VPN Stats${CClear}${CGreen}\_______________________________________________________${CClear}"
      echo ""

    # Keep track of Ping history stats and display skynet and randomizer methodology
    if [ ${PINGLOW%.*} -eq 0 ]
      then
        PINGLOW=${AVGPING%.*}
      elif [ ${AVGPING%.*} -lt ${PINGLOW%.*} ]
      then
        PINGLOW=${AVGPING%.*}
    fi

    if [ ${PINGHIGH%.*} -eq 0 ]
      then
        PINGHIGH=${AVGPING%.*}
      elif [ ${AVGPING%.*} -gt ${PINGHIGH%.*} ]
      then
        PINGHIGH=${AVGPING%.*}
    fi

    if [ $UpdateVPNMGR -eq 1 ]
      then
        RANDOMMETHOD="VPNMGR"
      elif [ $NordVPNSuperRandom -eq 1 ]
        then
          RANDOMMETHOD="NordVPN SuperRandom"
      elif [ $SurfSharkSuperRandom -eq 1 ]
        then
          RANDOMMETHOD="SurfShark SuperRandom"
      elif [ $PPSuperRandom -eq 1 ]
        then
          RANDOMMETHOD="PerfPriv SuperRandom"
      else
        RANDOMMETHOD="Standard"
    fi

    # Check the WAN connectivity to determine if we need to keep looping until WAN connection is re-established
    checkwan Loop

    # Initialize timer to measure how long it takes to grab the VPN server load
    LOAD_ELAPSED_TIME=0

    if [ $NordVPNSuperRandom -eq 1 ] || [ $UseNordVPN -eq 1 ]
      then
        # Get the NordVPN server load - thanks to @JackYaz for letting me borrow his code from VPNMGR to accomplish this! ;)
        LOAD_START_TIME=$(date +%s)
        printf "${CYellow}\r [Checking NordVPN Server Load]..."
        VPNLOAD=$(curl --silent --retry 3 "https://api.nordvpn.com/v1/servers?limit=16354" | jq '.[] | select(.station == "'"$VPNIP"'") | .load')
        printf "\r"
        LOAD_END_TIME=$(date +%s)
        LOAD_ELAPSED_TIME=$(( LOAD_END_TIME - LOAD_START_TIME ))
    fi

    if [ $SurfSharkSuperRandom -eq 1 ] || [ $UseSurfShark -eq 1 ]
      then
        # Get the SurfShark server load - thanks to @JackYaz for letting me borrow his code from VPNMGR to accomplish this! ;)
        LOAD_START_TIME=$(date +%s)
        printf "${CYellow}\r [Checking SurfShark Server Load]..."
        VPNLOAD=$(curl --silent --retry 3 "https://api.surfshark.com/v3/server/clusters" | jq --raw-output '.[] | select(.connectionName == "'"$VPNIP"'") | .load')
        printf "\r"
        LOAD_END_TIME=$(date +%s)
        LOAD_ELAPSED_TIME=$(( LOAD_END_TIME - LOAD_START_TIME ))
    fi

    if [ $PPSuperRandom -eq 1 ] || [ $UsePP -eq 1 ]
      then
        # Get the Perfect Privacy server load - thanks to @JackYaz for letting me borrow his code from VPNMGR to accomplish this! ;)
        LOAD_START_TIME=$(date +%s)
        printf "${CYellow}\r [Checking Perfect Privacy Server Load]..."
        PPcurl=$(curl --silent --retry 3 "https://www.perfect-privacy.com/api/traffic.json")
        PP_in=$(echo $PPcurl | jq -r '."'"$VPNIP"'" | ."bandwidth_in"')
        PP_out=$(echo $PPcurl | jq -r '."'"$VPNIP"'" | ."bandwidth_out"')
        PP_max=$(echo $PPcurl | jq -r '."'"$VPNIP"'" | ."bandwidth_max"')
        max1=$PP_in
        if [ $PP_out -gt $PP_in ]; then max1=$PP_out; fi
        max2=$PP_max
        if [ $PP_in -gt $PP_max ]; then max2=$PP_in; elif [ $PP_out -gt $PP_max ]; then max2=$PP_out; fi
        VPNLOAD=$(awk -v m1=$max1 -v m2=$max2 'BEGIN{printf "%0.0f\n", 100*m1/m2}')
        printf "\r"
        LOAD_END_TIME=$(date +%s)
        LOAD_ELAPSED_TIME=$(( LOAD_END_TIME - LOAD_START_TIME ))
    fi

    if [ -z "$VPNLOAD" ]; then VPNLOAD=0; fi # On that rare occasion where it's unable to get the NordVPN/SurfShark/PerfectPrivacy load, assign 0

    # Display some of the NordVPN/SurfShark/PerfectPrivacy specific stats
    if [ $NordVPNSuperRandom -eq 1 ] || [ $UseNordVPN -eq 1 ] || [ $SurfSharkSuperRandom -eq 1 ] || [ $UseSurfShark -eq 1 ] || [ $PPSuperRandom -eq 1 ] || [ $UsePP -eq 1 ]
      then
        echo -e "${CYellow} Ping Lo:${CWhite}${InvGreen}$PINGLOW${CClear}${CYellow} Hi:${CWhite}${InvRed}$PINGHIGH${CClear}${CYellow} ms | Load: ${InvBlue} $VPNLOAD% ${CClear}${CYellow} | Cfg: ${InvBlue}$RANDOMMETHOD${CClear}"

        # Display the high/low ping times, and for non-NordVPN/SurfShark/PerfectPrivacy customers, whether Skynet update is enabled.
        elif [ $UpdateSkynet -eq 0 ]
        then
          echo -e "${CYellow} Ping Lo:${CWhite}${InvGreen}$PINGLOW${CClear}${CYellow} Hi:${CWhite}${InvRed}$PINGHIGH${CClear}${CYellow} ms | Cfg: ${InvBlue}$RANDOMMETHOD${CClear}"
        else
          echo -e "${CYellow} Ping Lo:${CWhite}${InvGreen}$PINGLOW${CClear}${CYellow} Hi:${CWhite}${InvRed}$PINGHIGH${CClear}${CYellow} ms | Skynet: ${InvBlue}[Y]${CClear}${CYellow} | Cfg: ${InvBlue}$RANDOMMETHOD${CClear}"
    fi

    # Display some general OpenVPN connection specific Stats
    vpncrypto=$($timeoutcmd$timeoutsec nvram get vpn_client"$CURRCLNT"_crypt)
    vpndigest=$($timeoutcmd$timeoutsec nvram get vpn_client"$CURRCLNT"_digest)
    vpnport=$($timeoutcmd$timeoutsec nvram get vpn_client"$CURRCLNT"_port)
    vpnproto=$($timeoutcmd$timeoutsec nvram get vpn_client"$CURRCLNT"_proto)

    if [ -z "$vpncrypto" ]; then vpncrypto=""; elif [ $vpncrypto == "tcp-client" ]; then vpncrypto="tcp"; fi
    echo -e "${CYellow} Proto: ${InvBlue}$vpnproto${CClear}${CYellow} | Port: ${InvBlue}$vpnport${CClear}${CYellow} | Crypto: ${InvBlue}$vpncrypto${CClear}${CYellow} | AuthDigest: ${InvBlue}$vpndigest${CClear}"

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

    # Modify the amount of time for the calculation to be the Interval + Time to check for NordVPN Load + Time to check for WAN connectivity
    INTERVALTIMEMOD=$(($INTERVAL + $LOAD_ELAPSED_TIME + $WAN_ELAPSED_TIME))

    # Results are further divided by the timer/interval to give Megabits/sec
    rxmbrate=$(awk -v rb=$diffrxbytes -v intv=$INTERVALTIMEMOD 'BEGIN{printf "%0.2f\n", rb/intv}')
    txmbrate=$(awk -v tb=$difftxbytes -v intv=$INTERVALTIMEMOD 'BEGIN{printf "%0.2f\n", tb/intv}')

    # Total bytes sent/received are divided to give total TX/RX Gigabytes
    rxgbytes=$(awk -v rx=$rxbytes -v gb=1073741824 'BEGIN{printf "%0.2f\n", rx/gb}')
    txgbytes=$(awk -v tx=$txbytes -v gb=1073741824 'BEGIN{printf "%0.2f\n", tx/gb}')

    # If stats are just fresh due to a start or reset, then wait until stats are there to display
    # NOTE: after extensive testing, it seems that the RX and TX values are reversed in the OpenVPN status file, so I am reversing these below
    # NOTE2: This is by design... not a clumsy coding mistake!  :)

    if [ "$oldrxbytes" == "0" ] || [ "$oldtxbytes" == "0" ]
      then
        # Still gathering stats
        echo -e "${CYellow} [Gathering VPN RX and TX Stats]... | Ttl RX:${InvBlue}$txgbytes GB${CClear} ${CYellow}TX:${InvBlue}$rxgbytes GB${CClear}"
      else
        # Display current avg rx/tx rates and total rx/tx bytes for active VPN tunnel.
        echo -e "${CYellow} Avg RX:${InvBlue}$txmbrate Mbps${CClear}${CYellow} TX:${InvBlue}$rxmbrate Mbps${CClear}${CYellow} | Ttl RX:${InvBlue}$txgbytes GB${CClear} ${CYellow}TX:${InvBlue}$rxgbytes GB${CClear}"
    fi

    #VPN Traffic Measurement assignment of newest bytes to old counter before timer kicks off again
    oldrxbytes=$newrxbytes
    oldtxbytes=$newtxbytes

  else

    echo ""
    checkwan Loop # Check the WAN connectivity to determine if we need to keep looping until WAN connection is re-established

  fi

  # -------------------------------------------------------------------------------------------------------------------------
  # Check for 4 major reset scenarios:
  # (1) Lost connection,
  # (2) Multiple connections,
  # (3) High VPN Server Load, or
  # (4) High Ping
  # (5) VPN Client identified with a lower ping than the current connection
  # ...and reset the VPN connection
  # -------------------------------------------------------------------------------------------------------------------------

  # If STATUS remains 0 then we've lost our connection, reset the VPN
  if [ $STATUS -eq 0 ]; then
      echo -e "\n${CRed} Connection has failed, VPNMON-R2 is executing VPN Reset${CClear}\n"
      echo -e "$(date) - VPNMON-R2 ----------> ERROR: Connection failed - Executing VPN Reset" >> $LOGFILE

      vpnreset

      SKIPPROGRESS=1

      echo -e "$(date) - VPNMON-R2 - Resuming normal operations" >> $LOGFILE
      echo -e "$(date +%s)" > $RSTFILE
      START=$(cat $RSTFILE)
      PINGLOW=0 # Reset ping time history variables
      PINGHIGH=0
      ICANHAZIP=""
      oldrxbytes=0 # Reset Stats
      oldtxbytes=0
      newrxbytes=0
      newtxbytes=0
  fi

  # If VPNCLCNT is greater than 1 there are multiple connections running, reset the VPN
  if [ $VPNCLCNT -gt 1 ]; then
      echo -e "\n${CRed} Multiple VPN Client Connections detected, VPNMON-R2 is executing VPN Reset${CClear}\n"
      echo -e "$(date) - VPNMON-R2 ----------> ERROR: Multiple VPN Client Connections detected - Executing VPN Reset" >> $LOGFILE

      vpnreset

      SKIPPROGRESS=1

      echo -e "$(date) - VPNMON-R2 - Resuming normal operations" >> $LOGFILE
      echo -e "$(date +%s)" > $RSTFILE
      START=$(cat $RSTFILE)
      PINGLOW=0 # Reset ping time history variables
      PINGHIGH=0
      ICANHAZIP=""
      oldrxbytes=0 # Reset Stats
      oldtxbytes=0
      newrxbytes=0
      newtxbytes=0
  fi

  # If the NordVPN/SurfShark/PP Server load is greater than the set variable, reset the VPN and hopefully find a better server
  if [ $NordVPNLoadReset -le $VPNLOAD ] || [ $SurfSharkLoadReset -le $VPNLOAD ] || [ $PPLoadReset -le $VPNLOAD ]; then

      if [ $UseNordVPN -eq 1 ];then
        echo -e "\n${CRed} NordVPN Server Load is higher than $NordVPNLoadReset %, VPNMON-R2 is executing VPN Reset${CClear}\n"
        echo -e "$(date) - VPNMON-R2 ----------> WARNING: NordVPN Server Load > $NordVPNLoadReset% - Executing VPN Reset" >> $LOGFILE
      fi

      if [ $UseSurfShark -eq 1 ];then
        echo -e "\n${CRed} SurfShark Server Load is higher than $SurfSharkLoadReset %, VPNMON-R2 is executing VPN Reset${CClear}\n"
        echo -e "$(date) - VPNMON-R2 ----------> WARNING: SurfShark Server Load > $SurfSharkLoadReset% - Executing VPN Reset" >> $LOGFILE
      fi

      if [ $UsePP -eq 1 ];then
        echo -e "\n${CRed} Perfect Privacy Server Load is higher than $PPLoadReset %, VPNMON-R2 is executing VPN Reset${CClear}\n"
        echo -e "$(date) - VPNMON-R2 ----------> WARNING: Perfect Privacy Server Load > $PPLoadReset% - Executing VPN Reset" >> $LOGFILE
      fi

      vpnreset

      SKIPPROGRESS=1

      echo -e "$(date) - VPNMON-R2 - Resuming normal operations" >> $LOGFILE
      echo -e "$(date +%s)" > $RSTFILE
      START=$(cat $RSTFILE)
      PINGLOW=0 # Reset ping time history variables
      PINGHIGH=0
      ICANHAZIP=""
      oldrxbytes=0 # Reset Stats
      oldtxbytes=0
      newrxbytes=0
      newtxbytes=0
  fi

  # If the AVGPING average ping across the tunnel is greater than the set variable, reset the VPN and hopefully land on a server with lesser ping times
  if [ ${AVGPING%.*} -gt $MINPING ]; then
    echo -e "\n${CRed} Average PING across VPN tunnel is higher than $MINPING ms, VPNMON-R2 is executing VPN Reset${CClear}\n"
    echo -e "$(date) - VPNMON-R2 ----------> WARNING: AVG PING across VPN tunnel > $MINPING ms - Executing VPN Reset" >> $LOGFILE

    vpnreset

    SKIPPROGRESS=1

    echo -e "$(date) - VPNMON-R2 - Resuming normal operations" >> $LOGFILE
    echo -e "$(date +%s)" > $RSTFILE
    START=$(cat $RSTFILE)
    PINGLOW=0 # Reset ping time history variables
    PINGHIGH=0
    ICANHAZIP=""
    oldrxbytes=0 # Reset Stats
    oldtxbytes=0
    newrxbytes=0
    newtxbytes=0
  fi

  # If a different VPN slot has a lower ping than the current connection, then don't randomize and reset it to that VPN slot with lowest ping value
  if [ $USELOWESTSLOT == "1" ]; then
    if [ $LOWEST != $CURRCLNT ]; then

      LOWPINGCOUNT=$(($LOWPINGCOUNT+1))

      if [ $LOWPINGCOUNT -le $PINGCHANCES ]; then
        echo -e "${CRed} WARNING:${CYellow} Switching to faster ${InvBlue}VPN$LOWEST Client${CClear}${CYellow} after $(($PINGCHANCES-$LOWPINGCOUNT)) more chances"
      else
        echo -e "$(date) - VPNMON-R2 ----------> WARNING: Switching to faster VPN$LOWEST Client - Executing VPN Reset" >> $LOGFILE

        vpnresetlowestping

        SKIPPROGRESS=1
        LOWPINGCOUNT=0

        echo -e "$(date) - VPNMON-R2 - Resuming normal operations" >> $LOGFILE
        echo -e "$(date +%s)" > $RSTFILE
        START=$(cat $RSTFILE)
        PINGLOW=0 # Reset ping time history variables
        PINGHIGH=0
        ICANHAZIP=""
        oldrxbytes=0 # Reset Stats
        oldtxbytes=0
        newrxbytes=0
        newtxbytes=0
      fi
    else
      LOWPINGCOUNT=0
    fi
  fi

  # If a force reset command has been received by the UI, then go through a regular reset
  if [ $FORCEDRESET == "1" ]; then
    echo -e "\n${CRed} Forced reset captured through UI, VPNMON-R2 is executing VPN Reset${CClear}\n"
    echo -e "$(date) - VPNMON-R2 ----------> WARNING: Forced reset captured through UI - Executing VPN Reset" >> $LOGFILE

        vpnreset

        SKIPPROGRESS=1
        FORCEDRESET=0

        echo -e "$(date) - VPNMON-R2 - Resuming normal operations" >> $LOGFILE
        echo -e "$(date +%s)" > $RSTFILE
        START=$(cat $RSTFILE)
        PINGLOW=0 # Reset ping time history variables
        PINGHIGH=0
        ICANHAZIP=""
        oldrxbytes=0 # Reset Stats
        oldtxbytes=0
        newrxbytes=0
        newtxbytes=0
  fi

  # Provide a progressbar to show script activity
  if [ $SKIPPROGRESS == "0" ]; then
    echo ""
    i=0
    while [ $i -le $INTERVAL ]
    do
        preparebar 51 "|"
        progressbar $i $INTERVAL
        #sleep 1
        i=$(($i+1))
    done
  fi

  SKIPPROGRESS=0

  # VPN Traffic Measurement after timer
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
