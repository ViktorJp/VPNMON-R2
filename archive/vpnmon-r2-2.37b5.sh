#!/bin/sh

# VPNMON-R2 v2.37b5 (VPNMON-R2.SH) is an all-in-one script that is optimized for NordVPN, SurfShark VPN and Perfect Privacy
# VPN services. It can also compliment @JackYaz's VPNMGR program to maintain a NordVPN/PIA/WeVPN setup, and is able to
# function perfectly in a standalone environment with your own personal VPN service. This script will check the health of
# (up to) 5 VPN connections on a regular interval to see if one is connected, and sends a ping to a host of your choice
# through the active connection. If it finds that connection has been lost, it will execute a series of commands that will
# kill all VPN clients, will optionally whitelist all NordVPN/PerfectPrivacy VPN servers in the Skynet Firewall, and
# randomly picks one of your (up to) 5 VPN Clients to connect to. One of VPNMON-R2's unique features is called
# "SuperRandom", where it will randomly assign VPN endpoints for a random county (or your choice) to your VPN slots, and
# randomly connect to one of these. It will now also test your WAN connection, and put itself into standby until the WAN
# is restored before reconnecting your VPN connections.

# -------------------------------------------------------------------------------------------------------------------------
# Usage and configuration Guide - *UPDATED*
# -------------------------------------------------------------------------------------------------------------------------
# All previous user-selectable options are now available through the Configuration Utility.  You may access and run this
# utility by running "vpnmon-r2 -setup".  Once configured, a "vpnmon-r2.cfg" file will be written to your
# /jffs/addons/vpnmon-r2.d/ folder containing the options you have selected. Once everything looks good, you are able to
# run VPNMON-R2 for under normal monitoring conditions using this command: "vpnmon-r2 -monitor". Please note this change
# for any current automations you may have in place.  To easily view the log file, enter: "vpnmon-r2 -log".  You will be
# prompted as new updates become available going forward with v1.2.  Use "vpnmon-r2 -update" to update the script. If
# you want to learn about other functions, use "vpnmon-r2 -h or -help".

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
Version="2.37b5"                                    # Current version of VPNMON-R2
Beta=1                                              # Beta Testmode on/off
DLVersion="0.0"                                     # Current version of VPNMON-R2 from source repository
LOCKFILE="/jffs/scripts/VRSTLock.txt"               # Predefined lockfile that VPNMON-R2 creates when it resets the VPN so
                                                    # that VPNMON-R2 does not interfere during an external reset
RSTFILE="/jffs/addons/vpnmon-r2.d/vpnmon-rst.log"   # Logfile containing the last date/time a VPN reset was performed. Else,
                                                    # the latest date/time that VPNMON-R2 restarted will be shown.
LOGFILE="/jffs/addons/vpnmon-r2.d/vpnmon-r2.log"    # Logfile path/name that captures important date/time events - change
APPPATH="/jffs/scripts/vpnmon-r2.sh"                # Path to the location of vpnmon-r2.sh
CFGPATH="/jffs/addons/vpnmon-r2.d/vpnmon-r2.cfg"    # Path to the location of vpnmon-r2.cfg
DLVERPATH="/jffs/addons/vpnmon-r2.d/version.txt"    # Path to downloaded version from the source repository
YAZFI_CONFIG_PATH="/jffs/addons/YazFi.d/config"     # Path to the YazFi guest network(s) config file
APPSTATUS="/jffs/addons/vpnmon-r2.d/appstatus.txt"  # Path to the current status of VPNMON-R2
LockFound=0                                         # Lockfile variable for VPN resets
PauseLockFound=0                                    # Lockfile variable for pause and resumes
StopLockFound=0                                     # Lockfile variable for stops
WAN1OverrideLock=0                                  # Lockfile variable for WAN1 vpn connection overrides
NewScreen=0                                         # Screen variable to determine if it's new or reused
connState="2"                                       # Status = 2 means VPN is connected, 1 = connecting, 0 = not connected
BASE=1                                              # Random numbers start at BASE up to N, ie. 1..3
STATUS=0                                            # Tracks whether or not a ping was successful
VPNCLCNT=0                                          # Tracks to make sure there are not multiple connections running
CURRCLNT=0                                          # Tracks which VPN client is currently active
CNT=0                                               # Counter
FromUI=0                                            # Tracks selections made from the UI
AVGPING=0                                           # Average ping value
MINPING=100                                         # Minimum ping value in ms before a reset takes place
USELOWESTSLOT=1                                     # Option to select either random VPN slot connections, or using the one
                                                    # with the lowest PING
FORCEDRESET=0                                       # Variable tracks whether a forced reset is initiated through the UI
LOWPINGCOUNT=0                                      # Counter for the number of tries before switching to lower ping server
PINGCHANCES=5                                       # Number of chances your current connection gets before reconnecting to
IGNOREHIGHPING=0                                    # Ignore high ping rule if running on WAN1 failover mode faster server
RecommendedServer=0                                 # Tracks NordVPN Closest/lowest latency Recommended Server Option
WAN1Override=1                                      # Tracks WAN1 Overrides preventing VPN connections while WAN1 is active
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
WAN0IP="Unassigned"                                 # Tracking WAN IP for city location display
WAN1IP="Unassigned"                                 # Tracking WAN IP for city location display
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

UseWeVPN=0                                          # Variables for WeVPN
WeVPNMultipleCountries=0
WeVPNCountry="USA"
WeVPNCountry2=""
WeVPNCountry3=""
WeVPNSuperRandom=0
WeVPNLoadReset=50

# Color variables
CBlack="\e[1;30m"
InvBlack="\e[1;40m"
CRed="\e[1;31m"
InvRed="\e[1;41m"
CGreen="\e[1;32m"
InvGreen="\e[1;42m"
CDkGray="\e[1;90m"
InvDkGray="\e[1;100m"
InvLtGray="\e[1;47m"
CYellow="\e[1;33m"
InvYellow="\e[1;43m"
CBlue="\e[1;34m"
InvBlue="\e[1;44m"
CMagenta="\e[1;35m"
CCyan="\e[1;36m"
InvCyan="\e[1;46m"
CWhite="\e[1;37m"
InvWhite="\e[1;107m"
CClear="\e[0m"

# -------------------------------------------------------------------------------------------------------------------------
# Functions
# -------------------------------------------------------------------------------------------------------------------------

# Logo is a function that displays the VPNMON-R2 script name in a cool ASCII font
logo () {
  echo -e "${CYellow}   _    ______  _   ____  _______  _   __      ____ ___  "
  echo -e "  | |  / / __ \/ | / /  |/  / __ \/ | / /     / __ \__ \  ${CGreen}v$Version${CYellow}"
  echo -e "  | | / / /_/ /  |/ / /|_/ / / / /  |/ /_____/ /_/ /_/ / "
  echo -e "  | |/ / ____/ /|  / /  / / /_/ / /|  /_____/ _, _/ __/  "
  echo -e "  |___/_/   /_/ |_/_/  /_/\____/_/ |_/     /_/ |_/____/  "
  echo ""
}

# -------------------------------------------------------------------------------------------------------------------------

# Promptyn is a function that helps return a 0 or 1 from a Y/N question from the configuration utility.
promptYesn () {   # Enter defaults Yes
  while true; do
    read -p " [Y/n]? " yn
      case $yn in
        [Yy] ) echo -e "${CGreen} Using: Yes${CClear}";return 0 ;;
        [Nn] ) echo -e "${CGreen} Using: No${CClear}";return 1 ;;
        "" ) echo -e "${CGreen} Using: Yes${CClear}";return 0 ;;
        * ) echo -e "\n Please answer y or n, or Enter to accept default value.";;
      esac
  done
}

promptyNo () {   # Enter defaults No
  while true; do
    read -p " [y/N]? " yn
      case $yn in
        [Yy] ) echo -e "${CGreen} Using: Yes${CClear}";return 0 ;;
        [Nn] ) echo -e "${CGreen} Using: No${CClear}";return 1 ;;
        "" ) echo -e "${CGreen} Using: No${CClear}";return 1 ;;
        * ) echo -e "\n Please answer y or n, or Enter to accept default value.";;
      esac
  done
}

promptyn () {   # No defaults, just y or n
  while true; do
    read -p " [y/n]? " -n 1 -r yn
      case "${yn}" in
        [Yy]* ) return 0 ;;
        [Nn]* ) return 1 ;;
        * ) echo -e "\n Please answer y or n.";;
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
      printf "\r $s"
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

    if [ $progr -le 60 ]; then
      printf "${CGreen}\r [%.${barch}s%.${barsp}s]${CClear} ${CWhite}${InvDkGray}${i}s / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
    elif [ $progr -gt 60 ] && [ $progr -le 85 ]; then
      printf "${CYellow}\r [%.${barch}s%.${barsp}s]${CClear} ${CWhite}${InvDkGray}${i}s / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
    else
      printf "${CRed}\r [%.${barch}s%.${barsp}s]${CClear} ${CWhite}${InvDkGray}${i}s / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
    fi
  fi

  # Borrowed this wonderful keypress capturing mechanism from @Eibgrad... thank you! :)
  key_press=''; read -rsn1 -t 1 key_press < "$(tty 0>&2)"

  if [ $key_press ]; then
      case $key_press in
          [Ss]) FromUI=1; (vsetup); source $CFGPATH; echo -e "${CGreen} [Returning to the Main UI momentarily]                                    "; sleep 1; FromUI=0; i=$INTERVAL;;
          [Rr]) echo -e "${CGreen} [Reset Queued]                                                            "; sleep 1; FORCEDRESET=1; i=$INTERVAL; resetcheck;;
          [Bb]) (bossmode);;
          'e')  # Exit gracefully
                echo -e "${CClear}"
                  { echo 'EXITED'
                    echo $LastSlotUsed
                  } > $APPSTATUS
                exit 0
                ;;
      esac
  fi
}

# -------------------------------------------------------------------------------------------------------------------------

# bossmode is a function that immediately switches your screen to a word processing screen in case your boss comes around
# the corner, so it looks like you're actually doing work instead of staring at the VPNMON-R2 UI. ;)  Please note: VPNMON-R2
# is in a paused state when you enter Boss-Mode until you exit with an 'e'
bossmode() {
  clear
  echo -e "${InvCyan}                                    ${CRed}WordStar ${CBlack}C:\ASUS\MERLINFW.WS          [1]  |${CClear}"
  echo -e "${InvGreen}                 ${CBlack}<B><K>249       Insert   P1   L4   V10.00\"  C13  H1.25\"       +${CClear}"
  echo -e "${InvDkGray} ${InvCyan}${CBlack}MS Body Copy            ${InvDkGray} ${InvCyan}COURIER PC 12     ${InvDkGray} ${InvCyan} B ${InvDkGray} ${InvCyan} I ${InvDkGray} ${InvCyan} U ${InvDkGray} ${InvCyan}<*>${InvDkGray} ${InvWhite} L ${InvDkGray} ${InvCyan} C ${InvDkGray} ${InvCyan} R ${InvDkGray} ${InvCyan} J ${InvDkGray} ${InvCyan}|1${InvDkGray} ${CClear}"
  echo -e "${InvBlack}${CWhite}                                                                               |${CClear}"
  echo -e "${InvBlack}${CWhite}                A S U S W R T - M E R L I N   P R O J E C T                    ${InvLtGray} ${CClear}"
  echo -e "${InvBlack}${CCyan}                      by${CWhite} Eric Sauvageau ${CCyan} aka ${CWhite} RMerlin                          ${InvDkGray} ${CClear}"
  echo -e "${InvBlack}                                                                               ${InvDkGray} ${CClear}"
  echo -e "${InvBlack}            ${CCyan}\"A brief stroll through the history of the project...\"             ${InvDkGray} ${CClear}"
  echo -e "${InvBlack}${CWhite}                                                                               |${CClear}"
  echo -e "${InvBlack}${CWhite}==============================================================================W ${CClear}"
  echo -e "${InvBlack}${CCyan}     ***About***                                                               ${CWhite}|${CClear}"
  echo -e "${InvBlack}${CCyan}     Asuswrt-Merlin is an alternative, customized version of that firmware.    ${InvDkGray} ${CClear}"
  echo -e "${InvBlack}${CCyan}Developed by Eric Sauvageau, its primary goals are to enhance the existing     ${InvDkGray} ${CClear}"
  echo -e "${InvBlack}${CCyan}firmware without bringing any radical changes, and to fix some of the known    ${InvDkGray} ${CClear}"
  echo -e "${InvBlack}${CCyan}issues and limitations, while maintaining the same level of performance as the ${InvDkGray} ${CClear}"
  echo -e "${InvBlack}${CCyan}original firmware. This means Asuswrt-Merlin retains full support for NAT      ${InvDkGray} ${CClear}"
  echo -e "${InvBlack}${CCyan}acceleration (sometimes referred to as \"hardware acceleration\"), enhanced      ${InvDkGray} ${CClear}"
  echo -e "${InvBlack}${CCyan}NTFS performance (through the proprietary #drivers used by Asus from either    ${InvDkGray} ${CClear}"
  echo -e "${InvBlack}${CCyan}Paragon or Tuxera), and the Asus exclusive features such as AiCloud or the     ${InvDkGray} ${CClear}"
  echo -e "${InvBlack}${CCyan}Trend Micro-powered AiProtection.  New feature addition is very low on the     ${InvDkGray} ${CClear}"
  echo -e "${InvBlack}${CCyan}list of priorities for for this project.                                       ${InvDkGray} ${CClear}"
  echo -e "${InvBlack}${CCyan}                                                                               ${InvDkGray} ${CClear}"
  echo -e "${InvBlack}${CCyan}     ***AddOns***                                                              ${InvDkGray} ${CClear}"
  echo -e "${InvGreen}${CBlack}Asuswrt-Merlin has a rich ecosystem that consists of third party developed add-${InvDkGray} ${CClear}"
  echo -e "${InvGreen}${CBlack}ons, which can enhance the router with features like ad blocking or connection ${InvDkGray} ${CClear}"
  echo -e "${InvGreen}${CBlack}monitoring.${InvBlack}${CCyan} You find more info in the AddOns support forum at SNBForums.       ${InvDkGray} ${CClear}"
  echo -e "${InvBlack}${CCyan}                                                                               ${InvDkGray} ${CClear}"
  echo -e "${InvBlack}${CCyan}     ***Features***                                                            ${InvDkGray} ${CClear}"
  echo -e "${InvBlack}${CCyan}With a few rare exceptions, Asuswrt-Merlin retains the features from the       ${InvDkGray} ${CClear}"
  echo -e "${InvBlack}${CCyan}original stock Asus firmware. In addition, the following features have been    ${InvDkGray} ${CClear}"
  echo -e "${InvBlack}${CCyan}added or enhanced:                                                             ${CWhite}|${CClear}"

  while true; do
    key_press=''; read -rsn1 -t 1 key_press < "$(tty 0>&2)"

    if [ $key_press ]; then
        case $key_press in
            [Ee]) echo -e "${InvBlack}${CCyan} [The boss is gone!  Stealthily returning to VPNMON-R2...]"; echo -e "${CClear}"; exit 0;;
        esac
    fi
  done
}

# -------------------------------------------------------------------------------------------------------------------------

# Trimlogs is a function that does exactly what you think it does - it, uh... trims the logs. LOL
trimlogs() {

  if [ "$TRIMLOGS" == "1" ]
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
# FnLastSlotUsed is a function that determines lastslot used for roundrobin and appstatus.txt reporting
FnLastSlotUsed() {

  LastSlotUsed=$(cat $APPSTATUS | sed -n '2p') 2>&1

  if [ -z $LastSlotUsed ]; then LastSlotUsed=$N; fi

  if [ $N == "1" ]; then
    NextSlotUsed=1
  fi

  if [ $N == "2" ]; then
    if [ "$LastSlotUsed" == "1" ]; then
      NextSlotUsed=2
    elif [ "$LastSlotUsed" == "2" ]; then
      NextSlotUsed=1
    fi
  fi

  if [ $N == "3" ]; then
    if [ "$LastSlotUsed" == "1" ]; then
      NextSlotUsed=2
    elif [ "$LastSlotUsed" == "2" ]; then
      NextSlotUsed=3
    elif [ "$LastSlotUsed" == "3" ]; then
      NextSlotUsed=1
    fi
  fi

  if [ $N == "4" ]; then
    if [ "$LastSlotUsed" == "1" ]; then
      NextSlotUsed=2
    elif [ "$LastSlotUsed" == "2" ]; then
      NextSlotUsed=3
    elif [ "$LastSlotUsed" == "3" ]; then
      NextSlotUsed=4
    elif [ "$LastSlotUsed" == "4" ]; then
      NextSlotUsed=1
    fi
  fi

  if [ $N == "5" ]; then
    if [ "$LastSlotUsed" == "1" ]; then
      NextSlotUsed=2
    elif [ "$LastSlotUsed" == "2" ]; then
      NextSlotUsed=3
    elif [ "$LastSlotUsed" == "3" ]; then
      NextSlotUsed=4
    elif [ "$LastSlotUsed" == "4" ]; then
      NextSlotUsed=5
    elif [ "$LastSlotUsed" == "5" ]; then
      NextSlotUsed=1
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

# Separated these out to get the ifname for a dual-wan/failover situation where both WAN connections are on
get_wan_setting0() {
  local varname varval
  varname="${1}"
  prefixes="wan0_"

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

# Separated these out to get the ifname for a dual-wan/failover situation where both WAN connections are on
get_wan_setting1() {
  local varname varval
  varname="${1}"
  prefixes="wan1_"

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

  # Download the latest version file from the source repository
  curl --silent --retry 3 "https://raw.githubusercontent.com/ViktorJp/VPNMON-R2/master/version.txt" -o "/jffs/addons/vpnmon-r2.d/version.txt"

  if [ -f $DLVERPATH ]
    then
      # Read in its contents for the current version file
      DLVersion=$(cat $DLVERPATH)

      # Compare the new version with the old version and log it
      if [ "$Beta" == "1" ]; then   # Check if Dev/Beta Mode is enabled and disable notification message
        UpdateNotify=0
      elif [ "$DLVersion" != "$Version" ]; then
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
  if [ "$1" == "Loop" ]
  then
    printf "\r${InvYellow} ${CClear}${CYellow} [Checking WAN Connectivity]..."
  elif [ "$1" = "Reset" ]
  then
    printf "${CYellow}\r [Checking WAN Connectivity]..."
  fi

  #Run main checkwan loop
  while true; do

    # Start a timer to see how long this takes to add to the TX/RX Calculations
    WAN_START_TIME=$(date +%s)
    #DUALWANMODE=$($timeoutcmd$timeoutsec nvram get wans_mode)

    # Check the actual WAN State from NVRAM before running connectivity test, or insert itself into loop after failing an SSL handshake test
    if [ "$($timeoutcmd$timeoutsec nvram get wan0_state_t)" -eq 2 ] || [ "$($timeoutcmd$timeoutsec nvram get wan1_state_t)" -eq 2 ]
      then

        # Test the active WAN connection using 443 and verifying a handshake... if this fails, then the WAN connection is most likely down... or Google is down ;)
        if ($timeoutcmd$timeoutlng nc -w3 $testssl 443 >/dev/null 2>&1 && echo | $timeoutcmd$timeoutlng openssl s_client -connect $testssl:443 >/dev/null 2>&1 |awk 'handshake && $1 == "Verification" { if ($2=="OK") exit; exit 1 } $1 $2 == "SSLhandshake" { handshake = 1 }') >/dev/null 2>&1
          then
            if [ "$1" == "Loop" ]
            then
              printf "\r${InvGreen} ${CClear}${CGreen} [Checking WAN Connectivity]...ACTIVE"
              sleep 1
              printf "\33[2K\r"
            elif [ "$1" = "Reset" ]
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
      else
        wandownbreakertrip=1
        echo -e "$(date) - VPNMON-R2 ----------> ERROR: WAN CONNECTIVITY ISSUE DETECTED" >> $LOGFILE
    fi

    if [ "$wandownbreakertrip" == "1" ]
      then
        # The WAN is most likely down, and keep looping through until NVRAM reports that it's back up

        while [ "$wandownbreakertrip" == "1" ]; do

          if [ "$RESETSWITCH" == "1" ] || [ -f "$LOCKFILE" ]
            then
              echo ""
              echo -e "${CRed} ERROR: WAN DOWN... VPN Reset is terminating."
              echo -e "$(date) - VPNMON-R2 ----------> ERROR: WAN CONNECTIVITY ISSUE DETECTED. VPN RESET TERMINATED." >> $LOGFILE
              RESETSWITCH=0
              rm $LOCKFILE >/dev/null 2>&1
              sleep 2
              clear
          fi

          # Preemptively kill all the VPN Clients incase they're trying to reconnect on their own

          i=0
          while [ $i -ne $N ]
            do
              i=$(($i+1))
              service stop_vpnclient$i >/dev/null 2>&1
          done

          # Continue to test for WAN connectivity while in this loop. If it comes back up, break out of the loop and reset VPN
          if [ "$($timeoutcmd$timeoutsec nvram get wan0_state_t)" -ne 2 ] && [ "$($timeoutcmd$timeoutsec nvram get wan1_state_t)" -ne 2 ]
            then
              # Continue to loop and retest the WAN every 15 seconds
              SPIN=15
              echo -e "$(date) - VPNMON-R2 ----------> ERROR: WAN DOWN" >> $LOGFILE
              clear
              logo
                echo -e "${CRed} ---------------------> ERROR: WAN DOWN <---------------------"
                echo ""
                echo -e "${CRed} VPNMON-R2 is unable to detect a stable WAN connection. Please"
                echo -e "${CRed} check with your ISP, or reset your modem to re-establish a"
                echo -e "${CRed} stable connection.${CClear}\n"
                spinner
                wandownbreakertrip=1
            else
              wandownbreakertrip=2
              break
          fi
        done

      fi

      # If the WAN was down, and now it has just reset, then run a VPN Reset, and try to establish a new VPN connection
      if [ "$wandownbreakertrip" == "2" ]
        then
          echo -e "$(date) - VPNMON-R2 - WAN Link Detected -- Trying to reconnect/Reset VPN" >> $LOGFILE
          wandownbreakertrip=0
          vpnresettripped=1
          clear
          logo
          echo -e "${CRed} ---------------------> ERROR: WAN DOWN <---------------------"
          echo ""
          echo -e "${CGreen} WAN Link/Modem Detected... waiting 60 seconds to reconnect"
          echo -e "${CGreen} and for general connectivity to stabilize."
          echo ""
          SPIN=60
          spinner
          echo -e "$(date +%s)" > $RSTFILE
          START=$(cat $RSTFILE)
          echo ""
          vpnreset
      fi

  done
}

# -------------------------------------------------------------------------------------------------------------------------
# resetcheck tests for 5 major reset scenarios:
# (1) Lost connection,
# (2) Multiple connections,
# (3) High VPN Server Load,
# (4) High Ping,
# (5) VPN Client identified with a lower ping than the current connection
# (6) Force reset through the UI
# ...and reset the VPN connection
# -------------------------------------------------------------------------------------------------------------------------
resetcheck () {

# If STATUS remains 0 then we've lost our connection, reset the VPN
if [ $STATUS -eq 0 ]; then
    clear
    logo
    echo -e "\n${CRed} VPN$CURRCLNT Connection has failed. Executing VPN Reset${CClear}\n"
    echo -e "$(date) - VPNMON-R2 ----------> ERROR: VPN$CURRCLNT Connection failed - Executing VPN Reset" >> $LOGFILE

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
    clear
    logo
    echo -e "\n${CRed} Multiple VPN Client Connections detected. Executing VPN Reset${CClear}\n"
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

  clear
  logo

  if [ $UseNordVPN -eq 1 ];then
    echo -e "\n${CRed} NordVPN Server Load is higher than $NordVPNLoadReset %. Executing VPN Reset."
    echo -e " VPNMON-R2 is executing VPN Reset${CClear}\n"
    echo -e "$(date) - VPNMON-R2 ----------> WARNING: NordVPN Server Load > $NordVPNLoadReset% - Executing VPN Reset" >> $LOGFILE
  fi

  if [ $UseSurfShark -eq 1 ];then
    echo -e "\n${CRed} SurfShark Server Load is higher than $SurfSharkLoadReset %. Executing VPN Reset."
    echo -e " VPNMON-R2 is executing VPN Reset${CClear}\n"
    echo -e "$(date) - VPNMON-R2 ----------> WARNING: SurfShark Server Load > $SurfSharkLoadReset% - Executing VPN Reset" >> $LOGFILE
  fi

  if [ $UsePP -eq 1 ];then
    echo -e "\n${CRed} Perfect Privacy Server Load is higher than $PPLoadReset %. Executing VPN Reset."
    echo -e " VPNMON-R2 is executing VPN Reset${CClear}\n"
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
if [ "${AVGPING%.*}" -gt "$MINPING" ] && [ "$IGNOREHIGHPING" == "0" ]; then
  clear
  logo
  echo -e "\n${CRed} Average PING $AVGPING ms across VPN tunnel $CURRCLNT is > $MINPING ms. Executing VPN Reset${CClear}\n"
  echo -e "$(date) - VPNMON-R2 ----------> WARNING: Average PING of $AVGPING ms across VPN tunnel $CURRCLNT > $MINPING ms - Executing VPN Reset" >> $LOGFILE

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
else
  IGNOREHIGHPING=0
fi

# If a different VPN slot has a lower ping than the current connection, then don't randomize and reset it to that VPN slot with lowest ping value
if [ "$USELOWESTSLOT" == "1" ]; then
  if [ "$LOWEST" != "$CURRCLNT" ]; then

    LOWPINGCOUNT=$(($LOWPINGCOUNT+1))

    if [ $LOWPINGCOUNT -le $PINGCHANCES ]; then
      echo -e "${InvRed} ${CClear}${CRed} WARNING:${CYellow} Switching to faster ${InvDkGray}${CWhite}VPN$LOWEST Client${CClear}${CYellow} after $(($PINGCHANCES-$LOWPINGCOUNT)) more chances"
    else
      clear
      logo
      echo -e "\n${CRed} Switching to faster VPN$LOWEST Client with PING $LOWESTPING ms. Executing VPN Reset${CClear}\n"
      echo -e "$(date) - VPNMON-R2 ----------> WARNING: Switching to faster VPN$LOWEST Client with PING $LOWESTPING ms- Executing VPN Reset" >> $LOGFILE

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
if [ "$FORCEDRESET" == "1" ]; then
  clear
  logo
  echo -e "\n${CRed} Forced reset captured through UI, VPNMON-R2 is executing VPN Reset${CClear}\n"
  echo -e "$(date) - VPNMON-R2 ----------> INFO: Forced reset captured through UI - Executing VPN Reset" >> $LOGFILE

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
}

# -------------------------------------------------------------------------------------------------------------------------

# vpnresetlowestping is a function that resets the VPN connection based on lowest ping.
vpnresetlowestping() {

  if [ "$USELOWESTSLOT" == "1" ]; then

    # Start the VPN reset process
      echo -e "$(date) - VPNMON-R2 - Executing VPN Reset to Slot with Lowest PING" >> $LOGFILE

    # Reset the WAN/VPN IP/Locations
      WAN0IP="Unassigned"
      WAN1IP="Unassigned"
      VPNIP="Unassigned"

    # Kill all current VPN client sessions
      echo ""
      printf "${CGreen}\r [Killing all VPN Client Connections]                          "
      i=0
      while [ $i -ne $N ]
        do
          i=$(($i+1))
          service stop_vpnclient$i >/dev/null 2>&1
      done

    # Wait for confirmation that all VPN client slots are at 0 (disconnected)
      vpncount=0
      i=0
      while [ $i -ne $N ]
        do
          state1=$($timeoutcmd$timeoutsec nvram get vpn_client1_state)
          state2=$($timeoutcmd$timeoutsec nvram get vpn_client2_state)
          state3=$($timeoutcmd$timeoutsec nvram get vpn_client3_state)
          state4=$($timeoutcmd$timeoutsec nvram get vpn_client4_state)
          state5=$($timeoutcmd$timeoutsec nvram get vpn_client5_state)

          printf "${CGreen}\r [Confirming VPN Clients Disconnected]... 1:$state1 2:$state2 3:$state3 4:$state4 5:$state5     "
          sleep 1
          i=$(($i+1))
          if [ $((state$i)) -ne 0 ]; then
            printf "${CGreen}\r [Retrying Kill Command on all VPN Client Connections]...         "
            service stop_vpnclient$i >/dev/null 2>&1
            sleep 1
            i=0
          fi
      done

      echo -e "$(date) - VPNMON-R2 - Killed all VPN Client Connections" >> $LOGFILE

      # Check the WAN state before continuing
        printf "${CGreen}\r                                                               "
        checkwan Reset

      # Reset VPN connection to one with lowest PING
        echo ""
        service start_vpnclient$LOWEST >/dev/null 2>&1
        logger -t VPN Client$LOWEST "Active" >/dev/null 2>&1
        printf "${CGreen}\r [VPN$LOWEST Client ON]                                        "
        echo -e "$(date) - VPNMON-R2 - VPN$LOWEST Client ON - Lowest PING of $N VPN slots" >> $LOGFILE
        sleep 2
        echo ""
        { echo 'NORMAL'
          echo $LOWEST
        } > $APPSTATUS
        CURRCLNT=$LOWEST

      # Reset the VPN Director Rules
        printf "${CGreen}\r                                                               "
        printf "${CGreen}\r [Restart VPN Director Rules]                                  "
        service restart_vpnrouting0 >/dev/null 2>&1
        sleep 2

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
        if [ "$vpnresettripped" == "1" ]
          then
            vpnresettripped=0
            sh /jffs/scripts/vpnmon-r2.sh -monitor
        fi
  fi
}

# -------------------------------------------------------------------------------------------------------------------------

# VPNReset is a function based on my VPNON.SH script to kill connections and reconnect to a clean VPN state
vpnreset() {

  # Load the latest config file values
    source $CFGPATH

  # Create a rudimentary lockfile so that VPNMON-R2 doesn't interfere during the reset
    echo -n > $LOCKFILE

  # Start the VPN reset process
    echo -e "$(date) - VPNMON-R2 - Executing VPN Reset" >> $LOGFILE

  # Reset the WAN/VPN IP/Locations
    WAN0IP="Unassigned"
    WAN1IP="Unassigned"
    VPNIP="Unassigned"

  # Kill all current VPN client sessions
    printf "${CGreen}\r [Killing all VPN Client Connections]...                          "
    i=0
    while [ $i -ne $N ]
      do
        i=$(($i+1))
        service stop_vpnclient$i >/dev/null 2>&1
    done

  # Wait for confirmation that all VPN client slots are at 0 (disconnected)

      i=0
      while [ $i -ne $N ]
        do
          state1=$($timeoutcmd$timeoutsec nvram get vpn_client1_state)
          state2=$($timeoutcmd$timeoutsec nvram get vpn_client2_state)
          state3=$($timeoutcmd$timeoutsec nvram get vpn_client3_state)
          state4=$($timeoutcmd$timeoutsec nvram get vpn_client4_state)
          state5=$($timeoutcmd$timeoutsec nvram get vpn_client5_state)

          printf "${CGreen}\r [Confirming VPN Clients Disconnected]... 1:$state1 2:$state2 3:$state3 4:$state4 5:$state5     "
          sleep 1
          i=$(($i+1))
          if [ $((state$i)) -ne 0 ]; then
            printf "${CGreen}\r [Retrying Kill Command on all VPN Client Connections]...         "
            service stop_vpnclient$i >/dev/null 2>&1
            sleep 1
            i=0
          fi
      done

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

  # Determine if multiple WeVPN countries need to be considered, and pick a random one
    if [ $WeVPNMultipleCountries -eq 1 ]
    then

      # Determine how many countries we're dealing with
      if [ -z "$WeVPNCountry2" ] || [ "$WeVPNCountry2" == "0" ]
      then
            COUNTRYTOTAL2=0
      else
            COUNTRYTOTAL2=1
      fi

      if [ -z "$WeVPNCountry3" ] || [ "$WeVPNCountry3" == "0" ]
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
              WeVPNRandomCountry=$WeVPNCountry
          ;;

          2)
              WeVPNRandomCountry=$WeVPNCountry2
          ;;

          3)
              WeVPNRandomCountry=$WeVPNCountry3
          ;;

        esac
        echo ""
        printf "${CGreen}\r                                                               "
        printf "${CGreen}\r [Random WeVPN Multi-Country selected: $WeVPNRandomCountry]    "
        echo -e "$(date) - VPNMON-R2 - Randomly selected WeVPN Country: $WeVPNRandomCountry" >> $LOGFILE
        sleep 1
    else
      WeVPNRandomCountry=$WeVPNCountry
    fi

  # Export NordVPN/PerfectPrivacy IPs via API into a txt file, and import them into Skynet
    if [ $UpdateSkynet -eq 1 ]
    then

      if [ $UseNordVPN -eq 1 ]
      then

        printf "${CGreen}\r                                                               "
        printf "${CGreen}\r [Reaching out to NordVPN API to download Server IPs]          "
        sleep 1

        svrcount=0
        while [ $svrcount -ne 60 ]
          do
            svrcount=$(($svrcount+1))
            #curl --silent --retry 3 "https://api.nordvpn.com/v1/servers?limit=16384" | jq --raw-output '.[] | select(.locations[].country.name == "'"$NordVPNRandomCountry"'") | .station' > /jffs/scripts/NordVPN.txt
            NORDLINES="curl --silent --retry 3 https://api.nordvpn.com/v1/servers?limit=16384 | jq --raw-output '.[] | select(.locations[].country.name == \"$NordVPNRandomCountry\") | .station' > /jffs/scripts/NordVPN.txt"
            NORDLINES="$(eval $NORDLINES 2>/dev/null)"; if echo $NORDLINES | grep -qoE '\berror.*\b'; then printf "${CRed}\r [Error Occurred]"; sleep 1; fi
            LINES=$(cat /jffs/scripts/NordVPN.txt | wc -l) >/dev/null 2>&1 #Check to see how many lines/server IPs are in this file

            if [ $LINES -ge 1 ]; then printf "${CGreen}\r [NordVPN Server List Successfully Downloaded]                          "; echo ""; sleep 1; break; fi
            if [ $svrcount -eq 1 ]; then echo ""; fi
            printf "${CRed}\r [Connectivity Issue: Retrying... $svrcount/60]                          "
            sleep 1

            if [ $svrcount -eq 60 ]; then
              echo ""
              echo -e "\n${CRed} Error: Unable to reach NordVPN API! Check NordVPN service or"
              echo -e " Country Name specified in the configuration.${CClear}"
              echo -e "$(date) - VPNMON-R2 ----------> ERROR: Unable to reach NordVPN API!" >> $LOGFILE
              sleep 1
              break
            fi
        done

        if [ $LINES -eq 0 ] # If there are no lines, error out
        then
          echo -e "\n${CRed} Error: NordVPN.txt VPN Server list is blank! Skipping import into "
          echo -e " Skynet Firewall.\n${CClear}"
          echo -e "$(date) - VPNMON-R2 ----------> ERROR: NordVPN.txt VPN Server list is blank! Skipping Skynet Firewall import." >> $LOGFILE
        else
          printf "${CGreen}\r                                                               "
          printf "${CGreen}\r [Updating Skynet whitelist with NordVPN Server IPs]           "
          sleep 1

          firewall import whitelist /jffs/scripts/NordVPN.txt "NordVPN - $NordVPNRandomCountry" >/dev/null 2>&1

          printf "${CGreen}\r                                                               "
          printf "${CGreen}\r [Letting Skynet import and settle for 15 seconds]             "
          sleep 15

          echo -e "$(date) - VPNMON-R2 - Updated Skynet Whitelist" >> $LOGFILE
        fi
      fi

      if [ $UsePP -eq 1 ]
      then

        svrcount=0
        while [ $svrcount -ne 60 ]
          do
            svrcount=$(($svrcount+1))
            #curl --silent --retry 3 "https://www.perfect-privacy.com/api/serverips" > /jffs/scripts/ppips.txt
            PPLINES="curl --silent --retry 3 https://www.perfect-privacy.com/api/serverips > /jffs/scripts/ppips.txt"
            PPLINES="$(eval $PPLINES 2>/dev/null)"; if echo $PPLINES | grep -qoE '\berror.*\b'; then printf "${CRed}\r [Error Occurred]"; sleep 1; fi
            awk -F' ' '{print $2}' /jffs/scripts/ppips.txt > /jffs/scripts/ppipscln.txt 2>&1
            sed "s/,/\n/g" /jffs/scripts/ppipscln.txt > /jffs/scripts/ppipslst.txt 2>&1
            LINES=$(cat /jffs/scripts/ppipslst.txt | wc -l) >/dev/null 2>&1  #Check to see how many lines/server IPs are in this file

            if [ $LINES -ge 1 ]; then printf "${CGreen}\r [Perfect Privacy Server List Successfully Downloaded]                          "; echo ""; sleep 1; break; fi
            if [ $svrcount -eq 1 ]; then echo ""; fi
            printf "${CRed}\r [Connectivity Issue: Retrying... $svrcount/60]                          "
            sleep 1

            if [ $svrcount -eq 60 ]; then
              echo -e "\n${CRed} Error: Unable to reach Perfect Privacy API! Check PP service or"
              echo -e " Country Name specified in the configuration.${CClear}"
              echo -e "$(date) - VPNMON-R2 ----------> ERROR: Unable to reach Perfect Privacy API!" >> $LOGFILE
              break
            fi
        done

        if [ $LINES -eq 0 ] # If there are no lines, error out
        then
          echo -e "\n${CRed} Error: ppipslst.txt VPN Server list is blank! Skipping import into Skynet Firewall.\n${CClear}"
          echo -e "$(date) - VPNMON-R2 ----------> ERROR: ppipslst.txt VPN Server list is blank! Skipping import into Skynet Firewall." >> $LOGFILE
        else
          printf "${CGreen}\r                                                               "
          printf "${CGreen}\r [Updating Skynet whitelist with Perfect Privacy Server IPs]   "
          sleep 1

          firewall import whitelist /jffs/scripts/ppipslst.txt "Perfect Privacy VPN" >/dev/null 2>&1

          printf "${CGreen}\r                                                               "
          printf "${CGreen}\r [Letting Skynet import and settle for 15 seconds]             "
          sleep 15

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
        LINES=$(cat /jffs/scripts/NordVPN.txt | wc -l) >/dev/null 2>&1 # Check to see how many lines/server IPs are in this file

        if [ $LINES -eq 0 ] # If there are no lines, error out
        then
          echo -e "\n${CRed} Error: NordVPN.txt VPN Server list is blank! Skipping SuperRandom "
          echo -e " assignment process.\n${CClear}"
          echo -e "$(date) - VPNMON-R2 ----------> ERROR: NordVPN.txt VPN Server list is blank! Skipping SuperRandom assignment process." >> $LOGFILE
        else
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
              RNDVPNCITY="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$RNDVPNIP | jq --raw-output .city"
              RNDVPNCITY="$(eval $RNDVPNCITY)"; if echo $RNDVPNCITY | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then RNDVPNCITY="$RNDVPNIP"; fi
              nvram set vpn_client"$i"_addr="$RNDVPNIP"
              nvram set vpn_client"$i"_desc="NordVPN - $RNDVPNCITY"
              echo -e "${CCyan}  VPN$i Slot - SuperRandom IP: $RNDVPNIP - City: $RNDVPNCITY${CClear}"
              sleep 1
          done
          #echo ""
          echo -e "$(date) - VPNMON-R2 - Refreshed VPN Slots 1 - $N from $LINES SuperRandom NordVPN Server Locations" >> $LOGFILE
        fi

      else

        # NordVPN.txt must not exist and/or UpdateSkynet is turned off, so run API to get full server list from NordVPN

        printf "${CGreen}\r                                                               "
        printf "${CGreen}\r [Reaching out to NordVPN API to download Server IPs]          "
        sleep 1

        svrcount=0
        while [ $svrcount -ne 60 ]
          do
            svrcount=$(($svrcount+1))
            #curl --silent --retry 3 "https://api.nordvpn.com/v1/servers?limit=16384" | jq --raw-output '.[] | select(.locations[].country.name == "'"$NordVPNRandomCountry"'") | .station' > /jffs/scripts/NordVPN.txt
            NORDLINES="curl --silent --retry 3 "https://api.nordvpn.com/v1/servers?limit=16384" | jq --raw-output '.[] | select(.locations[].country.name == \"$NordVPNRandomCountry\") | .station' > /jffs/scripts/NordVPN.txt"
            NORDLINES="$(eval $NORDLINES 2>/dev/null)"; if echo $NORDLINES | grep -qoE '\berror.*\b'; then printf "${CRed}\r [Error Occurred]"; sleep 1; fi
            LINES=$(cat /jffs/scripts/NordVPN.txt | wc -l) >/dev/null 2>&1 #Check to see how many lines/server IPs are in this file

            if [ $LINES -ge 1 ]; then printf "${CGreen}\r [NordVPN Server List Successfully Downloaded]                          "; echo ""; sleep 1; break; fi
            if [ $svrcount -eq 1 ]; then echo ""; fi
            printf "${CRed}\r [Connectivity Issue: Retrying... $svrcount/60]                          "
            sleep 1

            if [ $svrcount -eq 60 ]; then
              echo ""
              echo -e "\n${CRed} Error: Unable to reach NordVPN API! Check NordVPN service or"
              echo -e " Country Name specified in the configuration.${CClear}"
              echo -e "$(date) - VPNMON-R2 ----------> ERROR: Unable to reach NordVPN API! Check NordVPN service or config's Country Name." >> $LOGFILE
              break
            fi
        done

        if [ $LINES -eq 0 ] #If there are no lines, error out
        then
          echo -e "\n${CRed} Error: NordVPN.txt VPN Server list is blank! Skipping SuperRandom"
          echo -e " assignment process.${CClear}"
          echo -e "$(date) - VPNMON-R2 ----------> ERROR: NordVPN.txt VPN Server list is blank! Skipping SuperRandom assignment process" >> $LOGFILE
          sleep 1
        else
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
              RNDVPNCITY="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$RNDVPNIP | jq --raw-output .city"
              RNDVPNCITY="$(eval $RNDVPNCITY)"; if echo $RNDVPNCITY | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then RNDVPNCITY="$RNDVPNIP"; fi
              nvram set vpn_client"$i"_addr="$RNDVPNIP"
              nvram set vpn_client"$i"_desc="NordVPN - $RNDVPNCITY"
              echo -e "${CCyan}  VPN$i Slot - SuperRandom IP: $RNDVPNIP - City: $RNDVPNCITY${CClear}"
              sleep 1
          done
          #echo ""
          echo -e "$(date) - VPNMON-R2 - Refreshed VPN Slots 1 - $N from $LINES SuperRandom NordVPN Server Locations" >> $LOGFILE
        fi
      fi
    fi

    if [ $UseSurfShark -eq 1 ]
    then
      # Randomly select VPN Client slots against entire field of available SurfShark server IPs for selected country
      if [ $SurfSharkSuperRandom -eq 1 ]
      then
        UpdateVPNMGR=0 # Failsafe to make sure VPNMGR doesn't overwrite values written by the SuperRandom function

        printf "${CGreen}\r                                                               "
        printf "${CGreen}\r [Reaching out to SurfShark API to download Server IPs]          "
        sleep 1

        svrcount=0
        while [ $svrcount -ne 60 ]
          do
            svrcount=$(($svrcount+1))
            # Run SurfShark API to get full server list from SurfShark
            #curl --silent --retry 3 "https://api.surfshark.com/v3/server/clusters" | jq --raw-output '.[] | select(.country == "'"$SurfSharkRandomCountry"'") | .connectionName' > /jffs/scripts/surfshark.txt
            SURFLINES="curl --silent --retry 3 https://api.surfshark.com/v3/server/clusters | jq --raw-output '.[] | select(.country == \"$SurfSharkRandomCountry\") | .connectionName' > /jffs/scripts/surfshark.txt"
            SURFLINES="$(eval $SURFLINES 2>/dev/null)"; if echo $SURFLINES | grep -qoE '\berror.*\b'; then printf "${CRed}\r [Error Occurred]"; sleep 1; fi
            LINES=$(cat /jffs/scripts/surfshark.txt | wc -l) >/dev/null 2>&1 #Check to see how many lines are in this file

            if [ $LINES -ge 1 ]; then printf "${CGreen}\r [SurfShark Server List Successfully Downloaded]                          "; echo ""; sleep 1; break; fi
            if [ $svrcount -eq 1 ]; then echo ""; fi
            printf "${CRed}\r [Connectivity Issue: Retrying... $svrcount/60]                          "
            sleep 1

            if [ $svrcount -eq 60 ]; then
              echo -e "\n${CRed} Error: Unable to reach SurfShark API! Check SurfShark service or config's Country Name.\n${CClear}"
              echo -e "$(date) - VPNMON-R2 ----------> ERROR: Unable to reach SurfShark API! Check SurfShark service or config's Country Name." >> $LOGFILE
              break
            fi
        done

        if [ $LINES -eq 0 ] #If there are no lines, error out
        then
          echo -e "\n${CRed} Error: surfshark.txt VPN Serverlist is blank! Skipping SuperRandom "
          echo -e " assignment process.\n${CClear}"
          echo -e "$(date) - VPNMON-R2 ----------> ERROR: surfshark.txt VPN Server list is blank! Skipping SuperRandom assignment process." >> $LOGFILE
          sleep 1
        else
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
              RNDVPNCITY="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$RNDVPNIP | jq --raw-output .city"
              RNDVPNCITY="$(eval $RNDVPNCITY)"; if echo $RNDVPNCITY | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then RNDVPNCITY="$RNDVPNIP"; fi
              nvram set vpn_client"$i"_addr="$RNDVPNHOST"
              nvram set vpn_client"$i"_desc="SurfShark - $RNDVPNCITY"
              echo -e "${CCyan}  VPN$i Slot - SuperRandom Host: $RNDVPNHOST - City: $RNDVPNCITY${CClear}"
              sleep 1
          done
          #echo ""
          echo -e "$(date) - VPNMON-R2 - Refreshed VPN Slots 1 - $N from $LINES SuperRandom SurfShark Server Locations" >> $LOGFILE
        fi
      fi
    fi

    if [ $UsePP -eq 1 ]
      then
      # Randomly select VPN Client slots against entire field of available Perfect Privacy server IPs for selected country
      if [ $PPSuperRandom -eq 1 ]
      then
        UpdateVPNMGR=0 # Failsafe to make sure VPNMGR doesn't overwrite values written by the SuperRandom function

        svrcount=0
        while [ $svrcount -ne 60 ]
          do
            svrcount=$(($svrcount+1))
            # Run Perfect Privacy API to get full server list from Perfect Privacy VPN
            #curl --silent --retry 3 "https://www.perfect-privacy.com/api/serverlocations.json" | jq -r 'path(.[] | select(.country =="'"$PPRandomCountry"'"))[0]' > /jffs/scripts/pp.txt
            PPLINES="curl --silent --retry 3 https://www.perfect-privacy.com/api/serverlocations.json | jq -r 'path(.[] | select(.country ==\"$PPRandomCountry\"))[0]' > /jffs/scripts/pp.txt"
            PPLINES="$(eval $PPLINES 2>/dev/null)"; if echo $PPLINES | grep -qoE '\berror.*\b'; then printf "${CRed}\r [Error Occurred]"; sleep 1; fi
            LINES=$(cat /jffs/scripts/pp.txt | wc -l) >/dev/null 2>&1 #Check to see how many linesare in this file

            if [ $LINES -ge 1 ]; then printf "${CGreen}\r [Perfect Privacy Server List Successfully Downloaded]                          "; echo ""; sleep 1; break; fi
            if [ $svrcount -eq 1 ]; then echo ""; fi
            printf "${CRed}\r [Connectivity Issue: Retrying... $svrcount/60]                          "
            sleep 1

            if [ $svrcount -eq 60 ]; then
              echo -e "\n${CRed} Error: Unable to reach Perfect Privacy API! Check Perfect Privacy"
              echo -e " service or Country Name specified in the configuration.\n${CClear}"
              echo -e "$(date) - VPNMON-R2 ----------> ERROR: Unable to reach Perfect Privacy API! Check Perfect Privacy service or config's Country Name." >> $LOGFILE
              break
            fi
        done

        if [ $LINES -eq 0 ] #If there are no lines, error out
        then
          echo -e "\n${CRed}Error: pp.txt VPN server list is blank! Skipping SuperRandom"
          echo -e " assignment process.\n${CClear}"
          echo -e "$(date) - VPNMON-R2 ----------> ERROR: pp.txt VPN server list is blank! Skipping SuperRandom assignment process." >> $LOGFILE
          sleep 1
        else
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
              RNDVPNCITY="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$RNDVPNIP | jq --raw-output .city"
              RNDVPNCITY="$(eval $RNDVPNCITY)"; if echo $RNDVPNCITY | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then RNDVPNCITY="$RNDVPNIP"; fi
              nvram set vpn_client"$i"_addr="$RNDVPNHOST"
              nvram set vpn_client"$i"_desc="Perfect Privacy - $RNDVPNCITY"
              echo -e "${CCyan}  VPN$i Slot - SuperRandom Host: $RNDVPNHOST - City: $RNDVPNCITY\n${CClear}"
              sleep 1
          done
          #echo ""
          echo -e "$(date) - VPNMON-R2 - Refreshed VPN Slots 1 - $N from $LINES SuperRandom Perfect Privacy Server Locations" >> $LOGFILE
        fi
      fi
    fi

    if [ $UseWeVPN -eq 1 ]
    then
      # Randomly select VPN Client slots against entire field of available WeVPN server IPs for selected country
      if [ $WeVPNSuperRandom -eq 1 ]
      then
        UpdateVPNMGR=0 # Failsafe to make sure VPNMGR doesn't overwrite values written by the SuperRandom function

        svrcount=0
        while [ $svrcount -ne 60 ]
          do
            svrcount=$(($svrcount+1))
            # Run WeVPN API to get full server list from WeVPN
            #curl --silent --retry 3 "https://client.wevpn.com/api/v3/locations" | jq --raw-output '.data[] | select(.country.name == "'"$WeVPNRandomCountry"'" ) | .hostname' > /jffs/scripts/wevpn.txt
            WELINES="curl --silent --retry 3 https://client.wevpn.com/api/v3/locations | jq --raw-output '.data[] | select(.country.name == \"$WeVPNRandomCountry\" ) | .hostname' > /jffs/scripts/wevpn.txt"
            WELINES="$(eval $WELINES 2>/dev/null)"; if echo $WELINES | grep -qoE '\berror.*\b'; then printf "${CRed}\r [Error Occurred]"; sleep 1; fi
            LINES=$(cat /jffs/scripts/wevpn.txt | wc -l) >/dev/null 2>&1 #Check to see how many lines are in this file

            if [ $LINES -ge 1 ]; then printf "${CGreen}\r [WeVPN Server List Successfully Downloaded]                          "; echo ""; sleep 1; break; fi
            if [ $svrcount -eq 1 ]; then echo ""; fi
            printf "${CRed}\r [Connectivity Issue: Retrying... $svrcount/60]                          "
            sleep 1

            if [ $svrcount -eq 60 ]; then
              echo -e "\n${CRed} Error: Unable to reach WeVPN API! Check WeVPN service or"
              echo -e " Country Name specified in the configuration.\n${CClear}"
              echo -e "$(date) - VPNMON-R2 ----------> ERROR: Unable to reach WeVPN API! Check WeVPN service or config's Country Name." >> $LOGFILE
              break
            fi
        done

        if [ $LINES -eq 0 ] #If there are no lines, error out
        then
          echo -e "\n${CRed} Error: wevpn.txt list is blank! Skipping SuperRandom"
          echo -e " assignment process.\n${CClear}"
          echo -e "$(date) - VPNMON-R2 ----------> ERROR: wevpn.txt list is blank! Skipping SuperRandom assignment process." >> $LOGFILE
          sleep 1
        else
          printf "${CGreen}\r                                                                 "
          printf "${CGreen}\r [Update VPN Slots 1-$N from $LINES SuperRandom WeVPN Hostnames] "
          sleep 1
          echo ""

          i=0
          while [ $i -ne $N ] #Assign SuperRandom hostnames/Descriptions to VPN Slots 1-N
            do
              i=$(($i+1))
              RANDOM=$(awk 'BEGIN {srand(); print int(32768 * rand())}')
              R_LINE=$(( RANDOM % LINES + 1 ))
              RNDVPNHOST=$(sed -n "${R_LINE}p" /jffs/scripts/wevpn.txt)
              RNDVPNIP=$(ping -q -c1 -n $RNDVPNHOST | head -n1 | sed "s/.*(\([0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\)).*/\1/g") > /dev/null 2>&1 #2>/dev/null
              RNDVPNCITY="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$RNDVPNIP | jq --raw-output .city"
              RNDVPNCITY="$(eval $RNDVPNCITY)"; if echo $RNDVPNCITY | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then RNDVPNCITY="$RNDVPNIP"; fi
              nvram set vpn_client"$i"_addr="$RNDVPNHOST"
              nvram set vpn_client"$i"_desc="WeVPN - $RNDVPNCITY"
              echo -e "${CCyan}  VPN$i Slot - SuperRandom Host: $RNDVPNHOST - City: $RNDVPNCITY${CClear}"
              sleep 1
          done
          #echo ""
          echo -e "$(date) - VPNMON-R2 - Refreshed VPN Slots 1 - $N from $LINES SuperRandom WeVPN Server Locations" >> $LOGFILE
        fi
      fi
    fi

    if [ $RecommendedServer == "1" ]; then
      UpdateVPNMGR=0 #Override vpnmgr if we're getting NordVPN Recommended Servers
      NordCountryID=$(curl --silent --retry 3 "https://api.nordvpn.com/v1/servers/countries" | jq --raw-output '.[] | select(.name == "'"$NordVPNRandomCountry"'") | [.name,.id] | "\(.[1])"')
      curl --silent --retry 3 "https://api.nordvpn.com/v1/servers/recommendations?filters\[country_id\]=$NordCountryID&limit=5" | jq --raw-output '.[].station' > /jffs/scripts/NordVPNRS.txt  #Extract all the closest recommended NordVPN servers to a text file
      LINES=$(cat /jffs/scripts/NordVPNRS.txt | wc -l) >/dev/null 2>&1 #Check to see how many lines/server IPs are in this file

      if [ $LINES -eq 0 ] #If there are no lines, error out
      then
        echo -e "\n${CRed} Error: NordVPNRS.txt recommended servers list is blank! Check"
        echo -e " NordVPN Service or Country Name specified in the configuration.${CClear}"
        echo -e "$(date) - VPNMON-R2 ----------> ERROR: NordVPNRS.txt recommended servers list is blank!" >> $LOGFILE
        sleep 3
        return
      fi

      printf "${CGreen}\r                                                               "
      printf "${CGreen}\r [Update VPN Slots 1-$N from $LINES Recommended NordVPN IPs]   "
      sleep 1
      echo ""

      i=0
      while [ $i -ne $N ] #Assign Recommended IPs/Descriptions to VPN Slots 1-N
        do
          i=$(($i+1))
          RECVPNIP=$(sed -n "${i}p" /jffs/scripts/NordVPNRS.txt)
          RECVPNCITY="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$RECVPNIP | jq --raw-output .city"
          RECVPNCITY="$(eval $RECVPNCITY)"; if echo $RECVPNCITY | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then RECVPNCITY="$RECVPNIP"; fi
          nvram set vpn_client"$i"_addr="$RECVPNIP"
          nvram set vpn_client"$i"_desc="NordVPN - $RECVPNCITY"
          echo -e "${CCyan}  VPN$i Slot - Recommended IP: $RECVPNIP - City: $RECVPNCITY${CClear}"
          sleep 1
      done
      #echo ""
      echo -e "$(date) - VPNMON-R2 - Refreshed VPN Slots 1 - $N from $LINES Recommended NordVPN Server Locations" >> $LOGFILE
    fi

  # Clean up API NordVPN Server Extracts
    if [ -f /jffs/scripts/NordVPN.txt ]
    then
      rm -f /jffs/scripts/NordVPN.txt  #Cleanup NordVPN temp files
      rm -f /jffs/scripts/NordVPNRS.txt
    fi

  # Clean up API SurfShark Server Extracts
    if [ -f /jffs/scripts/surfshark.txt ]
    then
      rm -f /jffs/scripts/surfshark.txt  #Cleanup Surfshark temp files
    fi

  # Clean up API Perfect Privacy Server Extracts
    if [ -f /jffs/scripts/pp.txt ] || [ -f /jffs/scripts/ppips.txt ]
    then
      rm -f /jffs/scripts/pp.txt  #Cleanup Perfect Privacy temp files
      rm -f /jffs/scripts/ppips.txt
      rm -f /jffs/scripts/ppipscln.txt
      rm -f /jffs/scripts/ppipslst.txt
    fi

  # Clean up API SurfShark Server Extracts
    if [ -f /jffs/scripts/wevpn.txt ]
    then
      rm -f /jffs/scripts/wevpn.txt  #Cleanup WeVPN temp files
    fi

  # Call VPNMGR functions to refresh server lists and save their results to the VPN client configs
    if [ $UpdateVPNMGR -eq 1 ]; then
      # Refresh VPNMGR cache, locations & servernames
      echo ""
      printf "${CGreen}\r                                                               "
      printf "${CGreen}\r [Refresh VPNMGRs NordVPN/PIA/WeVPN Server Locations]          "
      sh /jffs/scripts/service-event start vpnmgrrefreshcacheddata >/dev/null 2>&1
      sleep 10
      sh /jffs/scripts/service-event start vpnmgr >/dev/null 2>&1
      sleep 10
      echo -e "$(date) - VPNMON-R2 - Refreshed VPNMGR Server Locations and Hostnames" >> $LOGFILE
    fi

    if [ "$USELOWESTSLOT" == "0" ]; then

    # Pick a random VPN Client to connect to
      echo ""
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
      echo ""
      service start_vpnclient$option >/dev/null 2>&1
      logger -t VPN Client $option "Active"
      printf "${CGreen}\r                                                               "
      printf "${CGreen}\r [Random VPN$option Client ON]                                       "
      echo -e "$(date) - VPNMON-R2 - Randomly selected VPN$option Client ON" >> $LOGFILE
      sleep 2
      echo ""
      { echo 'NORMAL'
        echo $option
      } > $APPSTATUS
      CURRCLNT=$option

    elif [ "$USELOWESTSLOT" == "1" ]; then
      i=0
      WANIFNAME=$(get_wan_setting ifname)
      while [ $i -ne $N ] # Determine which connection has the fastest ping
        do
          i=$(($i+1))
          OFFLINEVPNIP=$($timeoutcmd$timeoutsec nvram get vpn_client"$i"_addr)
          DISCHOSTPING=$(ping -I $WANIFNAME -c 1 $OFFLINEVPNIP | awk -F'time=| ms' 'NF==3{print $(NF-1)}' | sort -rn) > /dev/null 2>&1 # Get ping stats
          testping=${DISCHOSTPING%.*}
          if [ -z "$DISCHOSTPING" ]; then DISCHOSTPING=99; testping=99; fi # On that rare occasion where it's unable to get the Ping time, assign 1

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
      printf "${CGreen}\r [Fastest PING VPN$LOWEST Client ON]                                 "
      service start_vpnclient$LOWEST >/dev/null 2>&1
      logger -t VPN Client $LOWEST "Active" >/dev/null 2>&1
      echo -e "$(date) - VPNMON-R2 - VPN$LOWEST Client ON - Lowest PING of $N VPN slots" >> $LOGFILE
      option=$LOWEST
      CURRCLNT=$LOWEST
      sleep 2
      echo ""
      { echo 'NORMAL'
        echo $LOWEST
      } > $APPSTATUS
      CURRCLNT=$LOWEST

    # Use a Round Robin configuration to pick the next VPN slot
    elif [ "$USELOWESTSLOT" == "2" ]; then

      FnLastSlotUsed

      # Start the selected VPN Client using Round Robin results
        echo ""
        service start_vpnclient$NextSlotUsed >/dev/null 2>&1
        logger -t VPN Client $NextSlotUsed "Active"
        LastSlotUsed=$NextSlotUsed
        printf "${CGreen}\r                                                               "
        printf "${CGreen}\r [Round Robin VPN$NextSlotUsed Client ON]                                  "
        echo -e "$(date) - VPNMON-R2 - Round-Robin selected VPN$NextSlotUsed Client ON" >> $LOGFILE
        sleep 2
        echo ""
        { echo 'NORMAL'
          echo $NextSlotUsed
        } > $APPSTATUS
        CURRCLNT=$NextSlotUsed

    fi

    # Reset the VPN Director Rules
    echo ""
    printf "${CGreen}\r                                                               "
    printf "${CGreen}\r [Restart VPN Director Rules]                                  "
    service restart_vpnrouting0 >/dev/null 2>&1
    sleep 2

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
          echo -e "\n${CRed} Error: YazFi config was not located or YazFi is not installed. Unable to Proceed.\n${CClear}"
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

    # Clean up lockfile
    rm $LOCKFILE >/dev/null 2>&1

    i=$INTERVAL # Skip the timer interval

    # Returning from a WAN Down situation or scheduled reset, restart VPNMON-R2 with -monitor switch, or return
    if [ "$RESETSWITCH" == "1" ]
      then
        RESETSWITCH=0
        return
    elif [ "$vpnresettripped" == "1" ]
      then
        vpnresettripped=0
        printf "${CGreen}\r [Reinitializing VPNMON-R2]...                                "
        sleep 2
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

  WANIFNAME=$(get_wan_setting ifname)

  # If the VPN slot is connected then proceed, else display it's disconnected
  if [ $VPNSTATE -eq $connState ]
  then
    while [ $CNT -lt $TRIES ]; do # Loop through number of tries
      ping -I $TUN -q -c 1 -W 2 $PINGHOST > /dev/null 2>&1 # First try pings
      RC=$?
      ICANHAZIP=$(curl --silent --fail --interface $TUN --request GET --url https://ipv4.icanhazip.com) # Grab the public IP of the VPN Connection
      IC=$?
      if [ $RC -eq 0 ] && [ $IC -eq 0 ]; then  # If both ping/curl come back successful, then proceed
        STATUS=1
        VPNCLCNT=$((VPNCLCNT+1))
        AVGPING=$(ping -I $TUN -c 1 $PINGHOST | awk -F'time=| ms' 'NF==3{print $(NF-1)}' | sort -rn) > /dev/null 2>&1 # Get ping stats

        if [ -z "$AVGPING" ]; then AVGPING=1; fi # On that rare occasion where it's unable to get the Ping time, assign 1

        if [ "$VPNIP" == "Unassigned" ]; then # The first time through, use API lookup to get exit VPN city and display
          VPNIP=$($timeoutcmd$timeoutsec nvram get vpn_client$1_addr)
          VPNCITY="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$ICANHAZIP | jq --raw-output .city"
          VPNCITY="$(eval $VPNCITY)"; if echo $VPNCITY | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then VPNCITY="$ICANHAZIP"; fi
          echo -e "$(date) - VPNMON-R2 - API call made to update VPN city to $VPNCITY" >> $LOGFILE
        fi

        CONNHOSTPING=$(ping -I $WANIFNAME -c 1 $VPNIP | awk -F'time=| ms' 'NF==3{print $(NF-1)}' | sort -rn) > /dev/null 2>&1 # Get ping stats
        testping=${CONNHOSTPING%.*}

        echo -e "${InvGreen} ${CClear}${CGreen}==VPN$1 Tunnel Active | ||${CWhite}${InvGreen} $AVGPING ms ${CClear}${CGreen}|| | ${CClear}${CGreen}Exit: ${CWhite}${InvDkGray}$VPNCITY${CClear}"
        CURRCLNT=$1
        LastSlotUsed=$1
          { echo 'NORMAL'
            echo $LastSlotUsed
          } > $APPSTATUS
        break
      else
        sleep 1 # Giving the VPN a chance to recover a certain number of times
        CNT=$((CNT+1))

        if [ $CNT -eq $TRIES ];then # But if it fails, report back that we have an issue requiring a VPN reset
          STATUS=0
          echo -e "${InvRed} ${CClear}${CRed}x-VPN$1 Ping/http failed${CClear}"
          echo -e "$(date) - VPNMON-R2 ----------> ERROR: VPN$1 Ping/HTTP response failed" >> $LOGFILE
        fi
      fi
    done
  else
    OFFLINEVPNIP=$($timeoutcmd$timeoutsec nvram get vpn_client$1_addr)
    DISCHOSTPING=$(ping -I $WANIFNAME -c 1 $OFFLINEVPNIP | awk -F'time=| ms' 'NF==3{print $(NF-1)}' | sort -rn) > /dev/null 2>&1 # Get ping stats
    testping=${DISCHOSTPING%.*}
    if [ -z "$DISCHOSTPING" ]; then # On that rare occasion where it's unable to get the Ping time, assign 99
      DISCHOSTPING=99
      testping=99
      echo -e "${CClear} - VPN$1 Disconnected  ${CRed}| ||  OFFLINE  || | ${CClear}"
    else
      echo -e "${CClear} - VPN$1 Disconnected  | || $DISCHOSTPING ms || | "
    fi
  fi

  if [ $1 -eq 1 ]; then
      LOWEST=$1
      LOWESTPING=${testping%.*}
    elif [ "${testping%.*}" -lt "${LOWESTPING%.*}" ]; then
      LOWEST=$1
      LOWESTPING=${testping%.*}
  fi

  if [ "$LOWESTPING" -eq 1 ]; then
    LOWEST=$CURRCLNT
  fi
}

# -------------------------------------------------------------------------------------------------------------------------

# wancheck is a function that checks each wan connection to see if its active, and performs a ping and a city lookup...
wancheck() {

  WANIF=$1
  WANIFNAME=$(get_wan_setting ifname)
  DUALWANMODE=$($timeoutcmd$timeoutsec nvram get wans_mode)

  # If WAN 0 or 1 is connected, then proceed, else display that it's inactive
  if [ "$WANIF" == "0" ]; then
    if [ "$($timeoutcmd$timeoutsec nvram get wan0_state_t)" -eq 2 ]
      then
        # Call the get_wan_setting function courtesy of @dave14305 and using this interface name to ping and get a city name from
        WAN0IFNAME=$(get_wan_setting0 ifname)

        # Backup Interface Retrieval method courtesy of @SomewhereOverTheRainbow's excellent coding skills:
        #WANIFNAME=$(ip r | grep default | grep -oE "\b($(nvram get wan_ifname)|$(nvram get wan0_ifname)|$(nvram get wan1_ifname)|$(nvram get wan_pppoe_ifname)|$(nvram get wan0_pppoe_ifname)|$(nvram get wan1_pppoe_ifname))\b")

        # Ping through the WAN interface
        if [ "$WANIFNAME" == "$WAN0IFNAME" ] || [ "$DUALWANMODE" == "lb" ]; then
          WAN0PING=$(ping -I $WAN0IFNAME -c 1 $PINGHOST | awk -F'time=| ms' 'NF==3{print $(NF-1)}' | sort -rn) > /dev/null 2>&1
        else
          WAN0PING="DW-FO"
        fi

        if [ -z "$WAN0PING" ]; then WAN0PING=1; fi # On that rare occasion where it's unable to get the Ping time, assign 1

        # Get the public IP of the WAN, determine the city from it, and display it on screen
        if [ "$WAN0IP" == "Unassigned" ]; then
          WAN0IP=$(curl --silent --fail --interface $WAN0IFNAME --request GET --url https://ipv4.icanhazip.com)
          WAN0CITY="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$WAN0IP | jq --raw-output .city"
          WAN0CITY="$(eval $WAN0CITY)"; if echo $WAN0CITY | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then WAN0CITY="$WAN0IP"; fi
          echo -e "$(date) - VPNMON-R2 - API call made to update WAN0 city to $WAN0CITY" >> $LOGFILE
        fi
        #WAN0CITY="Your City"
        if [ $WAN0PING == "DW-FO" ]; then
          echo -e "${InvGreen} ${CClear}${CGreen}==WAN0 $WAN0IFNAME Active | ||${CWhite}${InvGreen} FAILOVER ${CClear}${CGreen}|| | ${CClear}${CGreen}Exit: ${CWhite}${InvDkGray}$WAN0CITY${CClear}"
        else
          echo -e "${InvGreen} ${CClear}${CGreen}==WAN0 $WAN0IFNAME Active | ||${CWhite}${InvGreen} $WAN0PING ms ${CClear}${CGreen}|| | ${CClear}${CGreen}Exit: ${CWhite}${InvDkGray}$WAN0CITY${CClear}"
        fi

      else
        echo -e "${CClear} - WAN0 Port Inactive"
    fi
  fi

  if [ "$WANIF" == "1" ]; then
    if [ "$($timeoutcmd$timeoutsec nvram get wan1_state_t)" -eq 2 ]
      then
        # Call the get_wan_setting function courtesy of @dave14305 and using this interface name to ping and get a city name from
        WAN1IFNAME=$(get_wan_setting1 ifname)

        # Backup Interface Retrieval method courtesy of @SomewhereOverTheRainbow's excellent coding skills:
        #WANIFNAME=$(ip r | grep default | grep -oE "\b($(nvram get wan_ifname)|$(nvram get wan0_ifname)|$(nvram get wan1_ifname)|$(nvram get wan_pppoe_ifname)|$(nvram get wan0_pppoe_ifname)|$(nvram get wan1_pppoe_ifname))\b")

        # Ping through the WAN interface
        if [ "$WANIFNAME" == "$WAN1IFNAME" ] || [ "$DUALWANMODE" == "lb" ]; then
          WAN1PING=$(ping -I $WAN1IFNAME -c 1 $PINGHOST | awk -F'time=| ms' 'NF==3{print $(NF-1)}' | sort -rn) > /dev/null 2>&1
        else
          WAN1PING="DW-FO"
        fi

        if [ -z "$WAN1PING" ]; then WAN1PING=1; fi # On that rare occasion where it's unable to get the Ping time, assign 1

        # Get the public IP of the WAN, determine the city from it, and display it on screen
        if [ "$WAN1IP" == "Unassigned" ]; then
          WAN1IP=$(curl --silent --fail --interface $WAN1IFNAME --request GET --url https://ipv4.icanhazip.com)
          WAN1CITY="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$WAN1IP | jq --raw-output .city"
          WAN1CITY="$(eval $WAN1CITY)"; if echo $WAN1CITY | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then WAN1CITY="$WAN1IP"; fi
          echo -e "$(date) - VPNMON-R2 - API call made to update WAN city to $WAN1CITY" >> $LOGFILE
        fi
        #WAN1CITY="Your City"
        if [ $WAN1PING == "DW-FO" ]; then
          echo -e "${InvGreen} ${CClear}${CGreen}==WAN1 $WAN1IFNAME Active | ||${CWhite}${InvGreen} FAILOVER ${CClear}${CGreen}|| | ${CClear}${CGreen}Exit: ${CWhite}${InvDkGray}$WAN1CITY${CClear}"
        else
          echo -e "${InvGreen} ${CClear}${CGreen}==WAN1 $WAN1IFNAME Active | ||${CWhite}${InvGreen} $WAN1PING ms ${CClear}${CGreen}|| | ${CClear}${CGreen}Exit: ${CWhite}${InvDkGray}$WAN1CITY${CClear}"
          IGNOREHIGHPING=1
        fi

      else
        echo -e "${CClear} - WAN1 Port Inactive"
    fi
  fi
}

# -------------------------------------------------------------------------------------------------------------------------

lockcheck () {
  # Testing to see if VPNMON-R2 external reset is currently running, and if so, hold off until it finishes
  LockFound=0
  while [ -f "$LOCKFILE" ]; do
    # clear screen
    clear
    SPIN=15
    logo
    echo -e "${CGreen} ---------> NOTICE: VPN RESET CURRENTLY IN-PROGRESS <---------"
    echo ""
    echo -e "${CGreen} VPNMON-R2 is currently performing an external scheduled reset"
    echo -e "${CGreen} of the VPN through the means of the '-reset' commandline"
    echo -e "${CGreen} option or scheduled CRON job."
    echo ""
    echo -e "${CGreen} [Retrying to resume normal operations every $SPIN seconds]...${CClear}\n"
    echo -e "$(date +%s)" > $RSTFILE
    START=$(cat $RSTFILE)
    spinner
    LockFound=1

    # Reset the VPN IP/Locations and othe variables
    i=$INTERVAL
    WAN0IP="Unassigned" # Look for an updated WAN IP/Location
    WAN1IP="Unassigned" # Look for an updated WAN IP/Location
    VPNIP="Unassigned" # Look for a new VPN IP/Location
    ICANHAZIP="" # Reset Public VPN IP
    PINGLOW=0 # Reset ping time history variables
    PINGHIGH=0
    oldrxbytes=0 # Reset Stats
    oldtxbytes=0
    newrxbytes=0
    newtxbytes=0
  done

  if [ ! -f "$LOCKFILE" ] && [ "$LockFound" == "1" ]; then
    #reset the script
    sh $APPPATH -monitor
  fi

  PauseLockFound=0
  if [ -f $APPSTATUS ]; then
    STATE=$(cat $APPSTATUS | sed -n '1p')
    while [ $STATE == "PAUSED" ]; do
      # clear screen
      clear
      SPIN=15
      logo
      echo -e "${CGreen} -----------> NOTICE: VPNMON-R2 OPERATIONS PAUSED <-----------"
      echo ""
      echo -e "${CGreen} VPNMON-R2 is currently operating in a PAUSED state. Please use"
      echo -e "${CGreen} the 'vpnmon-r2 -resume' commandline to return to a NORMAL"
      echo -e "${CGreen} operations mode."
      echo ""
      echo -e "${CGreen} [Retrying to resume normal operations every $SPIN seconds]...${CClear}\n"
      echo -e "$(date +%s)" > $RSTFILE
      START=$(cat $RSTFILE)
      STATE=$(cat $APPSTATUS | sed -n '1p')
      spinner
      PauseLockFound=1

      # Reset the VPN IP/Locations and othe variables
      i=$INTERVAL
      WAN0IP="Unassigned" # Look for an updated WAN IP/Location
      WAN1IP="Unassigned" # Look for an updated WAN IP/Location
      VPNIP="Unassigned" # Look for a new VPN IP/Location
      ICANHAZIP="" # Reset Public VPN IP
      PINGLOW=0 # Reset ping time history variables
      PINGHIGH=0
      oldrxbytes=0 # Reset Stats
      oldtxbytes=0
      newrxbytes=0
      newtxbytes=0
    done
  fi

  if [ "$PauseLockFound" == "1" ]; then
    #reset the script
    sh $APPPATH -monitor
  fi

  StopLockFound=0
  if [ -f $APPSTATUS ]; then
    STATE=$(cat $APPSTATUS | sed -n '1p')
    while [ $STATE == "STOPPED" ] || [ $STATE == "FAILOVER" ] ; do
      # clear screen
      clear
      SPIN=15
      logo
      echo -e "${CGreen} -----------> NOTICE: VPNMON-R2 OPERATIONS STOPPED <-----------"
      echo ""
      echo -e "${CGreen} VPNMON-R2 is currently operating in a STOPPED state due to a"
      echo -e "${CGreen} WAN Failover or other external commandline event. All VPN"
      echo -e "${CGreen} Connections will be stopped while in this state. Please use"
      echo -e "${CGreen} the 'vpnmon-r2 -resume' commandline or fail back to the"
      echo -e "${CGreen} proper WAN interface to return to a NORMAL operations mode."
      echo ""
      echo -e "${CGreen} STATUS: ${CCyan}$STATE${CClear}"
      echo ""
      # Wait for confirmation that all VPN client slots are at 0 (disconnected)
        i=0
        while [ $i -ne $N ]
          do
            state1=$($timeoutcmd$timeoutsec nvram get vpn_client1_state)
            state2=$($timeoutcmd$timeoutsec nvram get vpn_client2_state)
            state3=$($timeoutcmd$timeoutsec nvram get vpn_client3_state)
            state4=$($timeoutcmd$timeoutsec nvram get vpn_client4_state)
            state5=$($timeoutcmd$timeoutsec nvram get vpn_client5_state)

            printf "${CCyan}\r [Confirming VPN Clients Disconnected]... 1:$state1 2:$state2 3:$state3 4:$state4 5:$state5 "
            sleep 1
            i=$(($i+1))
            if [ $((state$i)) -ne 0 ]; then
              printf "${CCyan}\r [Retrying Kill Command on all VPN Client Connections]...       ${CClear}\n"
              echo ""
              service stop_vpnclient$i >/dev/null 2>&1
              sleep 1
              i=0
            fi
        done

      echo ""
      echo ""
      echo -e "${CGreen} [Retrying to resume normal operations every $SPIN seconds]...${CClear}\n"
      echo -e "$(date +%s)" > $RSTFILE
      START=$(cat $RSTFILE)
      STATE=$(cat $APPSTATUS | sed -n '1p')
      spinner
      StopLockFound=1

      # Reset the VPN IP/Locations and othe variables
      i=$INTERVAL
      WAN0IP="Unassigned" # Look for an updated WAN IP/Location
      WAN1IP="Unassigned" # Look for an updated WAN IP/Location
      VPNIP="Unassigned" # Look for a new VPN IP/Location
      ICANHAZIP="" # Reset Public VPN IP
      PINGLOW=0 # Reset ping time history variables
      PINGHIGH=0
      oldrxbytes=0 # Reset Stats
      oldtxbytes=0
      newrxbytes=0
      newtxbytes=0
    done
  fi

  if [ "$StopLockFound" == "1" ]; then
    #reset the script and restart the same last known good VPN client
    LASTSLOT=$(cat $APPSTATUS | sed -n '2p') 2>&1
    printf "${CGreen}\r [Attempting restart of last known good VPN$LASTSLOT client]...${CClear}\n"
    service start_vpnclient$LASTSLOT >/dev/null 2>&1
    sleep 5
    ResVPNState=$($timeoutcmd$timeoutsec nvram get vpn_client${LASTSLOT}_state)

    i=0
    while [ $ResVPNState -ne 2 ]; do
      i=$(($i+1))

      if [ $i -eq 60 ]; then
        printf "${CRed}\r [Second attempt to restart last known good VPN$LASTSLOT client]...            ${CClear}\n"
        service stop_vpnclient$LASTSLOT >/dev/null 2>&1
        sleep 5
        service start_vpnclient$LASTSLOT >/dev/null 2>&1
        sleep 5
      fi

      if [ $i -eq 120 ]; then
        printf "${CRed}\r [Unable to restart of last known good VPN$LASTSLOT client]...${CClear}\n    "
        sleep 2
        printf "${CGreen}\r [VPN Reset Initiating]...                                                   "
        service stop_vpnclient$LASTSLOT >/dev/null 2>&1
        sleep 5
        break
      fi

      ResVPNState=$($timeoutcmd$timeoutsec nvram get vpn_client${LASTSLOT}_state)
      sleep 1

    done

    sh $APPPATH -monitor

  fi

  WAN1OverrideLock=0
  WAN0PrimaryCheck=$($timeoutcmd$timeoutsec nvram get wan0_primary)
  while [ $WAN1Override == "0" ] && [ $WAN0PrimaryCheck -eq 0 ]
    do
      # clear screen
      if [ -f $APPSTATUS ]; then
        STATE=$(cat $APPSTATUS | sed -n '1p')
      fi
      clear
      SPIN=15
      logo
      echo -e "${CGreen} -----------> NOTICE: WAN1 OVERRIDE - VPN STOPPED <-----------"
      echo ""
      echo -e "${CGreen} VPNMON-R2 is currently operating in a STOPPED state due to"
      echo -e "${CGreen} WAN1 being overridden. VPN Connections will be stopped while"
      echo -e "${CGreen} in this state. Checking WAN0 state every $SPIN seconds to return"
      echo -e "${CGreen} to normal operations mode."
      echo ""
      echo -e "${CGreen} STATUS: ${CCyan}$STATE${CClear}"
      echo ""
      # Wait for confirmation that all VPN client slots are at 0 (disconnected)
        i=0
        while [ $i -ne $N ]
          do
            state1=$($timeoutcmd$timeoutsec nvram get vpn_client1_state)
            state2=$($timeoutcmd$timeoutsec nvram get vpn_client2_state)
            state3=$($timeoutcmd$timeoutsec nvram get vpn_client3_state)
            state4=$($timeoutcmd$timeoutsec nvram get vpn_client4_state)
            state5=$($timeoutcmd$timeoutsec nvram get vpn_client5_state)

            printf "${CCyan}\r [Confirming VPN Clients Disconnected]... 1:$state1 2:$state2 3:$state3 4:$state4 5:$state5 "
            sleep 1
            i=$(($i+1))
            if [ $((state$i)) -ne 0 ]; then
              printf "${CCyan}\r [Retrying Kill Command on all VPN Client Connections]...       ${CClear}\n"
              service stop_vpnclient$i >/dev/null 2>&1
              sleep 1
              i=0
            fi
        done

      echo ""
      echo ""
      echo -e "${CGreen} [Retrying to resume normal operations every $SPIN seconds]...${CClear}\n"

      { echo 'STOPPED'
        echo $LASTSLOT
      } > $APPSTATUS

      WAN0PrimaryCheck=$($timeoutcmd$timeoutsec nvram get wan0_primary)

      echo -e "$(date +%s)" > $RSTFILE
      START=$(cat $RSTFILE)
      spinner
      WAN1OverrideLock=1

      # Reset the VPN IP/Locations and othe variables
      i=$INTERVAL
      WAN0IP="Unassigned" # Look for an updated WAN IP/Location
      WAN1IP="Unassigned" # Look for an updated WAN IP/Location
      VPNIP="Unassigned" # Look for a new VPN IP/Location
      ICANHAZIP="" # Reset Public VPN IP
      PINGLOW=0 # Reset ping time history variables
      PINGHIGH=0
      oldrxbytes=0 # Reset Stats
      oldtxbytes=0
      newrxbytes=0
      newtxbytes=0
  done

  if [ "$WAN1OverrideLock" == "1" ]; then
    #reset the script
    sh $APPPATH -monitor
  fi

}

# -------------------------------------------------------------------------------------------------------------------------

# vconfig is a function that steps you through the configuration items for a new or existing setup of VPNMON-R2...
vconfig () {
  clear
  if [ -f $CFGPATH ]; then #Making sure file exists before proceeding
    source $CFGPATH

    while true; do
      clear
      logo
      echo -e "${CGreen} ----------------------------------------------------------------"
      echo -e "${CGreen} Configuration Utility Options"
      echo -e "${CGreen} ----------------------------------------------------------------"
      echo -e " ${InvDkGray}${CWhite}  1 ${CClear}${CCyan}: Ping Retries Before Reset?    :"${CGreen}$TRIES
      echo -e " ${InvDkGray}${CWhite}  2 ${CClear}${CCyan}: Timer Interval to Check VPN?  :"${CGreen}$INTERVAL
      echo -e " ${InvDkGray}${CWhite}  3 ${CClear}${CCyan}: Host IP to PING against?      :"${CGreen}$PINGHOST
      echo -en " ${InvDkGray}${CWhite}  4 ${CClear}${CCyan}: Update VPNMGR?                :"${CGreen};
        if [ "$UpdateVPNMGR" == "0" ]; then
          printf "No"; printf "%s\n";
        else printf "Yes"; printf "%s\n"; fi

      echo -en " ${InvDkGray}${CWhite}  5 ${CClear}${CCyan}: How VPN Slots are Chosen?     :"${CGreen};
        if [ "$USELOWESTSLOT" == "0" ]; then
          printf "Random"; ODISABLED="${CDkGray}"; ODISABLED2="${CDkGray}"; printf "%s\n";
        elif [ "$USELOWESTSLOT" == "1" ]; then
          printf "Lowest PING"; ODISABLED="${CCyan}"; ODISABLED2="${CGreen}"; printf "%s\n";
        elif [ "$USELOWESTSLOT" == "2" ]; then
          printf "Round Robin"; ODISABLED="${CDkGray}"; ODISABLED2="${CDkGray}"; printf "%s\n";
        fi
      echo -e " ${InvDkGray}${CWhite}  |-${CClear}$ODISABLED-  Chances before Reset?        :"$ODISABLED2$PINGCHANCES

      echo -en " ${InvDkGray}${CWhite}  6 ${CClear}${CCyan}: Current VPN Provider?         :"${CGreen};
        if [ "$UseNordVPN" == "1" ]; then
          printf "NordVPN"; ODISABLED="${CCyan}"; ODISABLED2="${CGreen}"; printf "%s\n";
        elif [ "$UseSurfShark" == "1" ]; then
          printf "SurfShark"; ODISABLED="${CCyan}"; ODISABLED2="${CGreen}"; printf "%s\n";
        elif [ "$UsePP" == "1" ]; then
          printf "PerfectPrivacy"; ODISABLED="${CCyan}"; ODISABLED2="${CGreen}"; printf "%s\n";
        elif [ "$UseWeVPN" == "1" ]; then
          printf "WeVPN"; ODISABLED="${CCyan}"; ODISABLED2="${CGreen}"; printf "%s\n";
        else
          printf "Other"; ODISABLED="${CDkGray}"; ODISABLED2="${CDkGray}"; printf "%s\n"
        fi

      echo -en " ${InvDkGray}${CWhite}  |-${CClear}$ODISABLED-  Enable SuperRandom?          :"$ODISABLED2
      if [ "$UseNordVPN" == "1" ] && [ "$NordVPNSuperRandom" == "0" ]; then
        printf "No"; printf "%s\n";
      elif [ "$UseNordVPN" == "1" ] && [ "$NordVPNSuperRandom" == "1" ]; then
        printf "Yes"; printf "%s\n";
      elif [ "$UseSurfShark" == "1" ] && [ "$SurfSharkSuperRandom" == "0" ]; then
        printf "No"; printf "%s\n";
      elif [ "$UseSurfShark" == "1" ] && [ "$SurfSharkSuperRandom" == "1" ]; then
        printf "Yes"; printf "%s\n";
      elif [ "$UsePP" == "1" ] && [ "$PPSuperRandom" == "0" ]; then
        printf "No"; printf "%s\n";
      elif [ "$UsePP" == "1" ] && [ "$PPSuperRandom" == "1" ]; then
        printf "Yes"; printf "%s\n";
      elif [ "$UseWeVPN" == "1" ] && [ "$WeVPNSuperRandom" == "0" ]; then
        printf "No"; printf "%s\n";
      elif [ "$UseWeVPN" == "1" ] && [ "$WeVPNSuperRandom" == "1" ]; then
        printf "Yes"; printf "%s\n";
      else
        printf "No"; printf "%s\n";
      fi

      echo -en " ${InvDkGray}${CWhite}  |-${CClear}$ODISABLED-  VPN Country (Multi?)         :"$ODISABLED2
      if [ "$UseNordVPN" == "1" ]; then
        if [ "$NordVPNCountry2" != "0" ] && [ "$NordVPNCountry3" == "0" ]; then
          printf "$NordVPNCountry, $NordVPNCountry2"; printf "%s\n";
        elif [ "$NordVPNCountry2" == "0" ] && [ "$NordVPNCountry3" != "0" ]; then
          printf "$NordVPNCountry, $NordVPNCountry3"; printf "%s\n";
        elif [ "$NordVPNCountry2" != "0" ] && [ "$NordVPNCountry3" != "0" ]; then
          printf "$NordVPNCountry, $NordVPNCountry2, $NordVPNCountry3"; printf "%s\n";
        else
          printf "$NordVPNCountry"; printf "%s\n";
        fi
      elif [ "$UseSurfShark" == "1" ]; then
        if [ "$SurfSharkCountry2" != "0" ] && [ "$SurfSharkCountry3" == "0" ]; then
          printf "$SurfSharkCountry, $SurfSharkCountry2"; printf "%s\n";
        elif [ "$SurfSharkCountry2" == "0" ] && [ "$SurfSharkCountry3" != "0" ]; then
          printf "$SurfSharkCountry, $SurfSharkCountry3"; printf "%s\n";
        elif [ "$SurfSharkCountry2" != "0" ] && [ "$SurfSharkCountry3" != "0" ]; then
          printf "$SurfSharkCountry, $SurfSharkCountry2, $SurfSharkCountry3"; printf "%s\n";
        else
          printf "$SurfSharkCountry"; printf "%s\n";
        fi
      elif [ "$UsePP" == "1" ]; then
        if [ "$PPCountry2" != "0" ] && [ "$PPCountry3" == "0" ]; then
          printf "$PPCountry, $PPCountry2"; printf "%s\n";
        elif [ "$PPCountry2" == "0" ] && [ "$PPCountry3" != "0" ]; then
          printf "$PPCountry, $PPCountry3"; printf "%s\n";
        elif [ "$PPCountry2" != "0" ] && [ "$PPCountry3" != "0" ]; then
          printf "$PPCountry, $PPCountry2, $PPCountry3"; printf "%s\n";
        else
          printf "$PPCountry"; printf "%s\n";
        fi
      elif [ "$UseWeVPN" == "1" ]; then
        if [ "$WeVPNCountry2" != "0" ] && [ "$WeVPNCountry3" == "0" ]; then
          printf "$WeVPNCountry, $WeVPNCountry2"; printf "%s\n";
        elif [ "$WeVPNCountry2" == "0" ] && [ "$WeVPNCountry3" != "0" ]; then
          printf "$WeVPNCountry, $WeVPNCountry3"; printf "%s\n";
        elif [ "$WeVPNCountry2" != "0" ] && [ "$WeVPNCountry3" != "0" ]; then
          printf "$WeVPNCountry, $WeVPNCountry2, $WeVPNCountry3"; printf "%s\n";
        else
          printf "$WeVPNCountry"; printf "%s\n";
        fi
      else
        printf "None"; printf "%s\n";
      fi

      if [ "$UseWeVPN" == "1" ]; then
        echo -en " ${InvDkGray}${CWhite}  |-${CClear}${CDkGray}-  % Server Load Threshold?     :"${CDkGray}
      else
        echo -en " ${InvDkGray}${CWhite}  |-${CClear}$ODISABLED-  % Server Load Threshold?     :"$ODISABLED2
      fi
      if [ "$UseNordVPN" == "1" ]; then
        printf "$NordVPNLoadReset"; printf "%s\n";
      elif [ "$UseSurfShark" == "1" ]; then
        printf "$SurfSharkLoadReset"; printf "%s\n";
      elif [ "$UsePP" == "1" ]; then
        printf "$PPLoadReset"; printf "%s\n";
      else
        printf "No"; printf "%s\n";
      fi

      if [ "$UseSurfShark" == "1" ] || [ "$UseWeVPN" == "1" ]; then
        echo -en " ${InvDkGray}${CWhite}  |-${CClear}${CDkGray}-  Update Skynet?               :"${CDkGray}
      else
        echo -en " ${InvDkGray}${CWhite}  |-${CClear}$ODISABLED-  Update Skynet?               :"$ODISABLED2
      fi
      if [ "$UpdateSkynet" == "0" ]; then
        printf "No"; printf "%s\n";
      else printf "Yes"; printf "%s\n";
      fi

      if [ "$UseNordVPN" == "1" ]; then
        echo -en " ${InvDkGray}${CWhite}  |-${CClear}$ODISABLED-  Use Recommended Server(s)?   :"$ODISABLED2
      else
        echo -en " ${InvDkGray}${CWhite}  |-${CClear}${CDkGray}-  Use Recommended Server(s)?   :"${CDkGray}
      fi
      if [ "$RecommendedServer" == "0" ]; then
        printf "No"; printf "%s\n";
      else printf "Yes"; printf "%s\n";
      fi

      echo -en " ${InvDkGray}${CWhite}  7 ${CClear}${CCyan}: Perform Daily VPN Reset?      :"${CGreen};
        if [ "$ResetOption" == "0" ]; then
          printf "No"; ODISABLED="${CDkGray}"; ODISABLED2="${CDkGray}"; printf "%s\n";
        else printf "Yes"; ODISABLED="${CCyan}"; ODISABLED2="${CGreen}"; printf "%s\n"; fi
      echo -e " ${InvDkGray}${CWhite}  |-${CClear}$ODISABLED-  Daily Reset Time?            :"$ODISABLED2$DailyResetTime

      echo -e " ${InvDkGray}${CWhite}  8 ${CClear}${CCyan}: Minimum PING Before Reset?    :"${CGreen}$MINPING
      echo -e " ${InvDkGray}${CWhite}  9 ${CClear}${CCyan}: VPN Client Slots Configured?  :"${CGreen}$N
      echo -en " ${InvDkGray}${CWhite} 10 ${CClear}${CCyan}: Show Near-Realtime Stats?     :"${CGreen}
      if [ "$SHOWSTATS" == "0" ]; then
        printf "No"; printf "%s\n";
      else printf "Yes"; printf "%s\n";
      fi

      echo -e " ${InvDkGray}${CWhite} 11 ${CClear}${CCyan}: Delay Script Startup?         :"${CGreen}$DelayStartup
      echo -en " ${InvDkGray}${CWhite} 12 ${CClear}${CCyan}: Trim Logs Daily?              :"${CGreen};
        if [ "$TRIMLOGS" == "0" ]; then
          printf "No"; ODISABLED="${CDkGray}"; ODISABLED2="${CDkGray}"; printf "%s\n";
        else printf "Yes"; ODISABLED="${CCyan}"; ODISABLED2="${CGreen}"; printf "%s\n"; fi
      echo -e " ${InvDkGray}${CWhite}  |-${CClear}$ODISABLED-  Max Log File Size?           :"$ODISABLED2$MAXLOGSIZE

      echo -en " ${InvDkGray}${CWhite} 13 ${CClear}${CCyan}: Sync Current VPN with Yazfi?  :"${CGreen};
        if [ "$SyncYazFi" == "0" ]; then
          printf "No"; ODISABLED="${CDkGray}"; ODISABLED2="${CDkGray}"; printf "%s\n";
        else printf "Yes"; ODISABLED="${CCyan}"; ODISABLED2="${CGreen}"; printf "%s\n"; fi

      if [ $YF24GN1 == "1" ]; then YF24GN1Disp="${CGreen}Y${CClear}"; else YF24GN1Disp="${CRed}N${CClear}"; fi
      if [ $YF24GN2 == "1" ]; then YF24GN2Disp="${CGreen}Y${CClear}"; else YF24GN2Disp="${CRed}N${CClear}"; fi
      if [ $YF24GN3 == "1" ]; then YF24GN3Disp="${CGreen}Y${CClear}"; else YF24GN3Disp="${CRed}N${CClear}"; fi
      if [ $YF5GN1 == "1" ]; then YF5GN1Disp="${CGreen}Y${CClear}"; else YF5GN1Disp="${CRed}N${CClear}"; fi
      if [ $YF5GN2 == "1" ]; then YF5GN2Disp="${CGreen}Y${CClear}"; else YF5GN2Disp="${CRed}N${CClear}"; fi
      if [ $YF5GN3 == "1" ]; then YF5GN3Disp="${CGreen}Y${CClear}"; else YF5GN3Disp="${CRed}N${CClear}"; fi
      if [ $YF52GN1 == "1" ]; then YF52GN1Disp="${CGreen}Y${CClear}"; else YF52GN1Disp="${CRed}N${CClear}"; fi
      if [ $YF52GN2 == "1" ]; then YF52GN2Disp="${CGreen}Y${CClear}"; else YF52GN2Disp="${CRed}N${CClear}"; fi
      if [ $YF52GN3 == "1" ]; then YF52GN3Disp="${CGreen}Y${CClear}"; else YF52GN3Disp="${CRed}N${CClear}"; fi

      echo -en " ${InvDkGray}${CWhite}  |-${CClear}$ODISABLED-  YazFi Slots 1-9 Synced       :"$ODISABLED2
        if [ "$SyncYazFi" == "0" ]; then
          printf "Disabled"; ODISABLED="${CDkGray}"; ODISABLED2="${CDkGray}"; printf "%s\n";
        else printf "$YF24GN1Disp$YF24GN2Disp$YF24GN3Disp$YF5GN1Disp$YF5GN2Disp$YF5GN3Disp$YF52GN1Disp$YF52GN2Disp$YF52GN3Disp"; ODISABLED="${CCyan}"; ODISABLED2="${CGreen}"; printf "%s\n"; fi
      echo -en " ${InvDkGray}${CWhite} 14 ${CClear}${CCyan}: Allow WAN1 VPN Connections?   :"${CGreen};
        if [ "$WAN1Override" == "0" ]; then
          printf "No"; printf "%s\n";
        else printf "Yes"; printf "%s\n"; fi
      echo -e " ${InvDkGray}${CWhite}  | ${CClear}"
      echo -e " ${InvDkGray}${CWhite}  s ${CClear}${CCyan}: Save & Exit"
      echo -e " ${InvDkGray}${CWhite}  e ${CClear}${CCyan}: Exit & Discard Changes"
      echo -e "${CGreen} ----------------------------------------------------------------"
      echo ""
      printf " Selection: "
      read -r ConfigSelection

      # Execute chosen selections
          case "$ConfigSelection" in

            1) # -----------------------------------------------------------------------------------------
               echo ""
               echo -e "${CCyan} 1. How many times would you like a ping to retry your VPN tunnel before"
               echo -e "${CCyan} resetting? ${CYellow}(Default = 3)${CClear}"
               read -p ' Ping Retries (#): ' TRIES1
               if [ "$TRIES1" == "" ] || [ -z "$TRIES1" ]; then TRIES=3; else TRIES="$TRIES1"; fi # Using default value on enter keypress
            ;;

            2) # -----------------------------------------------------------------------------------------
               echo ""
               echo -e "${CCyan} 2. What interval (in seconds) would you like to check your VPN tunnel"
               echo -e "${CCyan} to ensure the connection is healthy? ${CYellow}(Default = 60)${CClear}"
               read -p ' Interval (seconds): ' INTERVAL1
               if [ -z "$INTERVAL1" ]; then INTERVAL=60; else INTERVAL=$INTERVAL1; fi # Using default value on enter keypress
            ;;

            3) # -----------------------------------------------------------------------------------------
               echo ""
               echo -e "${CCyan} 3. What host IP would you like to ping to determine the health of your "
               echo -e "${CCyan} VPN tunnel? ${CYellow}(Default = 8.8.8.8)${CClear}"
               read -p ' Host IP: ' PINGHOST1
               if [ -z "$PINGHOST1" ]; then PINGHOST="8.8.8.8"; else PINGHOST=$PINGHOST1; fi # Using default value on enter keypress
            ;;

            4) # -----------------------------------------------------------------------------------------
               echo ""
               echo -e "${CCyan} 4. Would you like to update VPNMGR? (Note: must be already installed "
               echo -e "${CCyan} and you must be a NordVPN/PIA/WeVPN subscriber) ${CYellow}(No=0, Yes=1)${CClear}"
               echo -e "${CYellow} (Default = 0)${CClear}"
                  while true; do
                    read -p " Update VPNMGR? (0/1): " UpdateVPNMGR1
                      case $UpdateVPNMGR1 in
                        [0] ) UpdateVPNMGR=0;break ;;
                        [1] ) UpdateVPNMGR=1;break ;;
                        "" ) echo -e "\n Please answer 0 or 1" ;;
                        * ) echo -e "\n Please answer 0 or 1" ;;
                      esac
                  done
            ;;

            5) # -----------------------------------------------------------------------------------------
               echo ""
               echo -e "${CCyan} 5. In what manner should VPNMON-R2 activate a selected VPN slot?"
               echo -e "${CCyan} There are 3 options to consider: ${CYellow}Random, Lowest PING, or Round-"
               echo -e "${CYellow} Robin.${CCyan} The 'Random' option will randomly pick one of your configured"
               echo -e "${CCyan} VPN slots to connect to, while the 'Lowest PING' option will"
               echo -e "${CCyan} continually test each of your VPN slots through each interval to"
               echo -e "${CCyan} see which one has the lowest PING, which most likely will be your"
               echo -e "${CCyan} fastest connection, and will always force a connection to it. The"
               echo -e "${CCyan} 'Round Robin' option will connect to the next VPN slot in line,"
               echo -e "${CCyan} so if VPN Slot #1 was in use, it will connect to VPN Slot #2 next."
               echo -e "${CYellow} (Random=0, Lowest PING=1, Round Robin=2) (Default = 0)${CClear}"
                  while true; do
                    read -p " Random, Lowest PING or Round-Robin? (0/1/2): " USELOWESTSLOT1
                      case $USELOWESTSLOT1 in
                        [0] ) USELOWESTSLOT=0;break ;;
                        [1] ) USELOWESTSLOT=1;break ;;
                        [2] ) USELOWESTSLOT=2;break ;;
                        "" ) echo -e "\n Please answer 0, 1 or 2" ;;
                        * ) echo -e "\n Please answer 0, 1 or 2" ;;
                      esac
                  done
               # -----------------------------------------------------------------------------------------
               if [ "$USELOWESTSLOT" == "1" ]; then
                 echo ""
                 echo -e "${CCyan} 5a. When using the 'Lowest PING' method, there is a greater chance that"
                 echo -e "${CCyan} your connections will reset at a higher rate, due to competing servers"
                 echo -e "${CCyan} giving slighly lower pings. To combat this, a counter is available to"
                 echo -e "${CCyan} help give your connection a chance to recover and regain its status as"
                 echo -e "${CCyan} the connection with the lowest ping.  How many chances would you like"
                 echo -e "${CCyan} to give your connection before reconnecting to a faster VPN server?"
                 echo -e "${CYellow} (Default = 5)${CClear}"
                 read -p ' Number of Chances?: ' PINGCHANCES1
                 if [ -z "$PINGCHANCES1" ]; then PINGCHANCES=5; else PINGCHANCES=$PINGCHANCES1; fi # Using default value on enter keypress
               else
                 PINGCHANCES=5
              fi
            ;;

            6) # -----------------------------------------------------------------------------------------
               echo ""
               echo -e "${CCyan} 6. Which service is your default VPN Provider? ${CYellow}(NordVPN = 1,"
               echo -e "${CYellow} Surfshark = 2, Perfect Privacy = 3, WeVPN = 4, Other = 5)"
               echo -e "${CYellow} (Default = Other)${CClear}"
               while true; do
                read -p " VPN Provider (1/2/3/4/5): " VPNProvider1
                  case $VPNProvider1 in
                    [1] ) VPNProvider=1; break ;;
                    [2] ) VPNProvider=2; break ;;
                    [3] ) VPNProvider=3; break ;;
                    [4] ) VPNProvider=4; break ;;
                    [5] ) VPNProvider=5; break ;;
                    "" ) echo -e "\n Please answer 1/2/3/4/5";;
                    * ) echo -e "\n Please answer 1/2/3/4/5";;
                  esac
               done

            # -----------------------------------------------------------------------------------------
            # NordVPN Logic
            # -----------------------------------------------------------------------------------------

            if [ "$VPNProvider" == "1" ]; then # NordVPN
              UseNordVPN=1

              echo ""
              echo -e "${CCyan} 6a. Would you like to use the NordVPN SuperRandom functionality? NOTE:"
              echo -e "${CCyan} Choosing this option will prevent you from using NordVPN Recommended"
              echo -e "${CCyan} Server functionality, and will instead pick random servers within the"
              echo -e "${CCyan} country of your choice, without regard to distance or latency."
              echo -e "${CYellow} (No=0, Yes=1) (Default = 0)${CClear}"
              while true; do
                read -p " Use SuperRandom? (0/1): " NordVPNSuperRandom1
                  case $NordVPNSuperRandom1 in
                    [0] ) NordVPNSuperRandom=0; break ;;
                    [1] ) NordVPNSuperRandom=1; break ;;
                    "" ) echo -e "\n Please answer 0 or 1";;
                    * ) echo -e "\n Please answer 0 or 1";;
                  esac
              done
              RecommendedServer=0
              # -----------------------------------------------------------------------------------------
              echo ""
              echo -e "${CCyan} 6b. What Country is your country of origin for NordVPN? ${CYellow}(Default = "
              echo -e "${CYellow} United States). NOTE: Country names must be spelled correctly as below!"
              echo -e "${CCyan} Valid country names as follows: Albania, Argentina, Australia, Austria,"
              echo -e "${CCyan} Belgium, Bosnia and Herzegovina, Brazil, Bulgaria, Canada, Chile,"
              echo -e "${CCyan} Costa Rica, Croatia, Cyprus, Czech Republic, Denmark, Estonia, Finland,"
              echo -e "${CCyan} France, Georgia, Germany, Greece, Hong Kong, Hungary, Iceland, Indonesia,"
              echo -e "${CCyan} Ireland, Israel, Italy, Japan, Latvia, Lithuania, Luxembourg, Malaysia,"
              echo -e "${CCyan} Mexico, Moldova, Netherlands, New Zealand, North Macedonia, Norway, Poland,"
              echo -e "${CCyan} Portugal, Romania, Serbia, Singapore, Slovakia, Slovenia, South Africa,"
              echo -e "${CCyan} South Korea, Spain, Sweden, Switzerland, Taiwan, Thailand, Turkey, Ukraine,"
              echo -e "${CCyan} United Arab Emirates, United Kingdom, United States, Vietnam.${CClear}"
              read -p " NordVPN Country: " NordVPNCountry1
              if [ -z "$NordVPNCountry1" ]; then NordVPNCountry="United States"; else NordVPNCountry=$NordVPNCountry1; fi # Using default value on enter keypress
              # -----------------------------------------------------------------------------------------
              if [ "$NordVPNSuperRandom" == "1" ]; then
                echo ""
                echo -e "${CCyan} 6c. Would you like to randomize connections across multiple countries?"
                echo -e "${CCyan} NOTE: A maximum of 2 additional country names can be added. (Total of 3)"
                echo -e "${CYellow} (No=0, Yes=1) (Default = 0)${CClear}"
                while true; do
                  read -p " Use Multiple Countries? (0/1): " NordVPNMultipleCountries1
                    case $NordVPNMultipleCountries1 in
                      [0] ) NordVPNMultipleCountries=0; break ;;
                      [1] ) NordVPNMultipleCountries=1; break ;;
                      "" ) echo -e "\n Please answer 0 or 1";;
                      * ) echo -e "\n Please answer 0 or 1";;
                    esac
                done

                if [ "$NordVPNMultipleCountries" == "1" ]; then
                    echo -e "${CCyan}"
                    read -p "$(echo -e " Enter Country #2 (Use 0 for blank) (Default = 0): ${CClear}")" NordVPNCountry21
                    if [ -z "$NordVPNCountry21" ]; then NordVPNCountry2=0; else NordVPNCountry2="$NordVPNCountry21"; fi
                    echo -e "${CCyan}"
                    read -p "$(echo -e " Enter Country #3 (Use 0 for blank) (Default = 0): ${CClear}")" NordVPNCountry31
                    if [ -z "$NordVPNCountry31" ]; then NordVPNCountry3=0; else NordVPNCountry3="$NordVPNCountry31"; fi
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
              echo -e "${CCyan} 6d. At what % VPN server load would you like to reconnect to a different"
              echo -e "${CCyan} NordVPN Server? ${CYellow}(Default = 50)${CClear}"
              read -p " % Server Load Threshold: " NordVPNLoadReset1
              if [ -z "$NordVPNLoadReset1" ]; then NordVPNLoadReset=50; else NordVPNLoadReset=$NordVPNLoadReset1; fi # Using default value on enter keypress
              # -----------------------------------------------------------------------------------------
              echo ""
              echo -e "${CCyan} 6e. Would you like to whitelist NordVPN servers in the Skynet Firewall?"
              echo -e "${CYellow} (No=0, Yes=1) (Default = 0)${CClear}"
              while true; do
                read -p " Update Skynet? (0/1): " UpdateSkynet1
                  case $UpdateSkynet1 in
                    [0] ) UpdateSkynet=0; break ;;
                    [1] ) UpdateSkynet=1; break ;;
                    "" ) echo -e "\n Please answer 0 or 1";;
                    * ) echo -e "\n Please answer 0 or 1";;
                  esac
              done
              # -----------------------------------------------------------------------------------------
              if [ $NordVPNSuperRandom == "0" ]; then
                echo ""
                echo -e "${CCyan} 6f. Would you like to use NordVPN Recommended Servers? Note: Choosing"
                echo -e "${CCyan} this option will configure your VPN slots with servers that are the"
                echo -e "${CCyan} closest to your WAN location exit, and have the lowest latency/load."
                echo -e "${CCyan} This is the same function your NordVPN mobile/pc app has when chosing"
                echo -e "${CCyan} the default recommended server. This option will override your choices"
                echo -e "${CCyan} you may have selected for SuperRandom and multiple countries. This"
                echo -e "${CCyan} is a NordVPN feature only."
                echo -e "${CYellow} (No=0, Yes=1) (Default = 0)${CClear}"
                while true; do
                  read -p " Use Recommended NordVPN Server(s)? (0/1): " RecommendedServer1
                    case $RecommendedServer1 in
                      [0] ) RecommendedServer=0; break ;;
                      [1] ) RecommendedServer=1; break ;;
                      "" ) echo -e "\n Please answer 0 or 1";;
                      * ) echo -e "\n Please answer 0 or 1";;
                    esac
                done
                NordVPNSuperRandom=0
                NordVPNMultipleCountries=0
              fi
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
              RecommendedServer=0
            fi

            # -----------------------------------------------------------------------------------------
            # Surfshark Logic
            # -----------------------------------------------------------------------------------------

            if [ "$VPNProvider" == "2" ]; then # Surfshark
              UseSurfShark=1

              echo ""
              echo -e "${CCyan} 6a. Would you like to use the SurfShark SuperRandom functionality?"
              echo -e "${CYellow} (No=0, Yes=1) (Default = 0)${CClear}"
              while true; do
                read -p " Use SuperRandom? (0/1): " SurfSharkSuperRandom1
                  case $SurfSharkSuperRandom1 in
                    [0] ) SurfSharkSuperRandom=0; break ;;
                    [1] ) SurfSharkSuperRandom=1; break ;;
                    "" ) echo -e "\n Please answer 0 or 1";;
                    * ) echo -e "\n Please answer 0 or 1";;
                  esac
              done
              # -----------------------------------------------------------------------------------------
              echo ""
              echo -e "${CCyan} 6b. What Country is your country of origin for SurfShark? ${CYellow}(Default = "
              echo -e "${CYellow} United States). NOTE: Country names must be spelled correctly as below!"
              echo -e "${CCyan} Valid country names as follows: Albania, Algeria, Andorra, Argentina,"
              echo -e "${CCyan} Armenia, Australia, Austria, Azerbaijan, Bahamas, Belgium Belize Bhutan,"
              echo -e "${CCyan} Bolivia, Bosnia and Herzegovina, Brazil, Brunei, Bulgaria, Canada, Chile,"
              echo -e "${CCyan} Colombia, Combodia, Costa Rica, Croatia, Cyprus, Czech Republic, Denmark,"
              echo -e "${CCyan} Ecuador, Egypt, Estonia, Finland, France, Georgia, Germany, Greece,"
              echo -e "${CCyan} Hong Kong, Hungary, Iceland, India, Indonesia, Ireland, Israel, Italy, Japan,"
              echo -e "${CCyan} Kazakhstan, Laos, Latvia, Liechtenstein, Lithuania, Luxembourg, Malaysia,"
              echo -e "${CCyan} Malta, Marocco, Mexico, Moldova, Monaco, Mongolia, Montenegro, Myanmar,"
              echo -e "${CCyan} Nepal, Netherlands, New Zealand, Nigeria, North Macedonia, Norway, Panama,"
              echo -e "${CCyan} Paraguay, Peru, Philippines, Poland, Portugal, Romania, Serbia, Singapore,"
              echo -e "${CCyan} Slovakia, Slovenia, South Africa, South Korea, Spain, Sri Lanka, Sweden,"
              echo -e "${CCyan} Switzerland, Taiwan, Thailand, Turkey, Ukraine, United Arab Emirates,"
              echo -e "${CCyan} United Kingdom, United States, Uruguay, Uzbekistan, Venezuela, Vietnam${CClear}"
              read -p " SurfShark Country: " SurfSharkCountry1
              if [ -z "$SurfSharkCountry1" ]; then SurfSharkCountry="United States"; else SurfSharkCountry=$SurfSharkCountry1; fi # Using default value on enter keypress
              # -----------------------------------------------------------------------------------------
              if [ "$SurfSharkSuperRandom" == "1" ]; then
                echo ""
                echo -e "${CCyan} 6c. Would you like to randomize connections across multiple countries?"
                echo -e "${CCyan} NOTE: A maximum of 2 additional country names can be added. (Total of 3)"
                echo -e "${CYellow} (No=0, Yes=1) (Default = 0)${CClear}"
                while true; do
                  read -p " Use Multiple Countries? (0/1): " SurfSharkMultipleCountries1
                    case $SurfSharkMultipleCountries1 in
                      [0] ) SurfSharkMultipleCountries=0; break ;;
                      [1] ) SurfSharkMultipleCountries=1; break ;;
                      "" ) echo -e "\n Please answer 0 or 1";;
                      * ) echo -e "\n Please answer 0 or 1";;
                    esac
                done

                if [ "$SurfSharkMultipleCountries" == "1" ]; then
                    echo -e "${CCyan}"
                    read -p "$(echo -e " Enter Country #2 (Use 0 for blank) (Default = 0): ${CClear}")" SurfSharkCountry21
                    if [ -z "$SurfSharkCountry21" ]; then SurfSharkCountry2=0; else SurfSharkCountry2="$SurfSharkCountry21"; fi
                    echo -e "${CCyan}"
                    read -p "$(echo -e " Enter Country #3 (Use 0 for blank) (Default = 0): ${CClear}")" SurfSharkCountry31
                    if [ -z "$SurfSharkCountry31" ]; then SurfSharkCountry3=0; else SurfSharkCountry3="$SurfSharkCountry31"; fi
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
              echo -e "${CCyan} 6d. At what % VPN server load would you like to reconnect to a different"
              echo -e "${CCyan} SurfShark Server? ${CYellow}(Default = 50)${CClear}"
              read -p " % Server Load Threshold: " SurfSharkLoadReset1
              if [ -z "$SurfSharkLoadReset1" ]; then SurfSharkLoadReset=50; else SurfSharkLoadReset=$SurfSharkLoadReset1; fi # Using default value on enter keypress
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

            if [ "$VPNProvider" == "3" ]; then # Perfect Privacy
              UsePP=1

              echo ""
              echo -e "${CCyan} 6a. Would you like to use the Perfect Privacy SuperRandom functionality?"
              echo -e "${CYellow} (No=0, Yes=1) (Default = 0)${CClear}"
              while true; do
                read -p " Use SuperRandom? (0/1): " PPSuperRandom1
                  case $PPSuperRandom1 in
                    [0] ) PPSuperRandom=0; break ;;
                    [1] ) PPSuperRandom=1; break ;;
                    "" ) echo -e "\n Please answer 0 or 1";;
                    * ) echo -e "\n Please answer 0 or 1";;
                  esac
              done
              # -----------------------------------------------------------------------------------------
              echo ""
              echo -e "${CCyan} 6b. What Country is your country of origin for Perfect Privacy? ${CYellow}(Default = "
              echo -e "${CYellow} U.S.A.). NOTE: Country names must be spelled correctly as below!"
              echo -e "${CCyan} Valid country names as follows: Australia, Austria, Canada, China,"
              echo -e "${CCyan} Czech Republic, Denmark, France, Germany, Iceland, Israel, Italy,"
              echo -e "${CCyan} Japan, Latvia, Netherlands, Norway, Poland, Romania, Russia, Serbia,"
              echo -e "${CCyan} Singapore, Spain, Sweden, Switzerland, Turkey, U.S.A., United Kingdom${CClear}"
              read -p " Perfect Privacy Country: " PPCountry1
              if [ -z "$PPCountry1" ]; then PPCountry="U.S.A."; else PPCountry=$PPCountry1; fi # Using default value on enter keypress
              # -----------------------------------------------------------------------------------------
              if [ "$PPSuperRandom" == "1" ]; then
                echo ""
                echo -e "${CCyan} 6c. Would you like to randomize connections across multiple countries?"
                echo -e "${CCyan} NOTE: A maximum of 2 additional country names can be added. (Total of 3)"
                echo -e "${CYellow} (No=0, Yes=1) (Default = 0)${CClear}"
                while true; do
                  read -p " Use Multiple Countries? (0/1): " PPMultipleCountries1
                    case $PPMultipleCountries1 in
                      [0] ) PPMultipleCountries=0; break ;;
                      [1] ) PPMultipleCountries=1; break ;;
                      "" ) echo -e "\n Please answer 0 or 1";;
                      * ) echo -e "\n Please answer 0 or 1";;
                    esac
                done
                if [ "$PPMultipleCountries" == "1" ]; then
                    echo -e "${CCyan}"
                    read -p "$(echo -e " Enter Country #2 (Use 0 for blank) (Default = 0): ${CClear}")" PPCountry21
                    if [ -z "$PPCountry21" ]; then PPCountry2=0; else PPCountry2="$PPCountry21"; fi
                    echo -e "${CCyan}"
                    read -p "$(echo -e " Enter Country #3 (Use 0 for blank) (Default = 0): ${CClear}")" PPCountry31
                    if [ -z "$PPCountry31" ]; then PPCountry3=0; else PPCountry3="$PPCountry31"; fi
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
              echo -e "${CCyan} 6d. At what VPN server load would you like to reconnect to a different"
              echo -e "${CCyan} Perfect Privacy Server? ${CYellow}(Default = 50)${CClear}"
              read -p " % Server Load Threshold: " PPLoadReset1
              if [ -z "$PPLoadReset1" ]; then PPLoadReset=50; else PPLoadReset=$PPLoadReset1; fi # Using default value on enter keypress
              # -----------------------------------------------------------------------------------------
              echo ""
              echo -e "${CCyan} 6e. Would you like to whitelist Perfect Privacy VPN servers in the Skynet"
              echo -e "${CCyan} Firewall? ${CYellow}(No=0, Yes=1) (Default = 0)${CClear}"
              while true; do
                read -p " Update Skynet? (0/1): " UpdateSkynet1
                  case $UpdateSkynet1 in
                    [0] ) UpdateSkynet=0; break ;;
                    [1] ) UpdateSkynet=1; break ;;
                    "" ) echo -e "\n Please answer 0 or 1";;
                    * ) echo -e "\n Please answer 0 or 1";;
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
            # WeVPN Logic
            # -----------------------------------------------------------------------------------------

            if [ "$VPNProvider" == "4" ]; then # WeVPN
              UseWeVPN=1
              WeVPNLoadReset=50

              echo ""
              echo -e "${CCyan} 6a. Would you like to use the WeVPN SuperRandom functionality?"
              echo -e "${CYellow} (No=0, Yes=1) (Default = 0)${CClear}"
              while true; do
                read -p " Use SuperRandom? (0/1): " WeVPNSuperRandom1
                  case $WeVPNSuperRandom1 in
                    [0] ) WeVPNSuperRandom=0; break ;;
                    [1] ) WeVPNSuperRandom=1; break ;;
                    "" ) echo -e "\n Please answer 0 or 1";;
                    * ) echo -e "\n Please answer 0 or 1";;
                  esac
              done
              # -----------------------------------------------------------------------------------------
              echo ""
              echo -e "${CCyan} 6b. What Country is your country of origin for SurfShark? ${CYellow}(Default = "
              echo -e "${CYellow} USA). NOTE: Country names must be spelled correctly as below!"
              echo -e "${CCyan} Valid country names as follows: Australia, Austria, Belgium, Brazil,"
              echo -e "${CCyan} Bulgaria, Canada, Czech Republic, Denmark, Egypt, Estonia, Finland,"
              echo -e "${CCyan} France, Germany, Greece, Hong Kong, Hungary, Iceland, India, Indonesia,"
              echo -e "${CCyan} Ireland, Israel, Italy, Japan, Luxembourg, Malaysia, Mexico, Netherlands,"
              echo -e "${CCyan} New Zealand, Nigeria, Norway, Philippines, Poland, Portugal, Romania,"
              echo -e "${CCyan} Russia, Serbia, Singapore, South Africa, South Korea, Spain, Sweden,"
              echo -e "${CCyan} Switzerland, Taiwan, Turkey, UAE, UK, Ukraine, USA, Vietnam${CClear}"
              read -p " WeVPN Country: " WeVPNCountry1
              if [ -z "$WeVPNCountry1" ]; then WeVPNCountry="USA"; else WeVPNCountry=$WeVPNCountry1; fi # Using default value on enter keypress
              # -----------------------------------------------------------------------------------------
              if [ "$WeVPNSuperRandom" == "1" ]; then
                echo ""
                echo -e "${CCyan} 6c. Would you like to randomize connections across multiple countries?"
                echo -e "${CCyan} NOTE: A maximum of 2 additional country names can be added. (Total of 3)"
                echo -e "${CYellow} (No=0, Yes=1) (Default = 0)${CClear}"
                while true; do
                  read -p " Use Multiple Countries? (0/1): " WeVPNMultipleCountries1
                    case $WeVPNMultipleCountries1 in
                      [0] ) WeVPNMultipleCountries=0; break ;;
                      [1] ) WeVPNMultipleCountries=1; break ;;
                      "" ) echo -e "\n Please answer 0 or 1";;
                      * ) echo -e "\n Please answer 0 or 1";;
                    esac
                done

                if [ "$WeVPNMultipleCountries" == "1" ]; then
                    echo -e "${CCyan}"
                    read -p "$(echo -e " Enter Country #2 (Use 0 for blank) (Default = 0): ${CClear}")" WeVPNCountry21
                    if [ -z "$WeVPNCountry21" ]; then WeVPNCountry2=0; else WeVPNCountry2="$WeVPNCountry21"; fi
                    echo -e "${CCyan}"
                    read -p "$(echo -e " Enter Country #3 (Use 0 for blank) (Default = 0): ${CClear}")" WeVPNCountry31
                    if [ -z "$WeVPNCountry31" ]; then WeVPNCountry3=0; else WeVPNCountry3="$WeVPNCountry31"; fi
                else
                  WeVPNMultipleCountries=0
                  WeVPNCountry2=0
                  WeVPNCountry3=0
                fi
              else
                WeVPNMultipleCountries=0
                WeVPNCountry2=0
                WeVPNCountry3=0
              fi
              # -----------------------------------------------------------------------------------------
            else
              UseWeVPN=0
              WeVPNSuperRandom=0
              WeVPNMultipleCountries=0
              WeVPNCountry="USA"
              WeVPNCountry2=0
              WeVPNCountry3=0
              WeVPNLoadReset=50
            fi

            # -----------------------------------------------------------------------------------------
            # VPN Service Not Listed Logic
            # -----------------------------------------------------------------------------------------

            if [ "$VPNProvider" == "5" ]; then # Not Listed
              UseNordVPN=0
              NordVPNSuperRandom=0
              NordVPNMultipleCountries=0
              NordVPNCountry="United States"
              NordVPNCountry2=0
              NordVPNCountry3=0
              NordVPNLoadReset=50
              UpdateSkynet=0
              RecommendedServer=0

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

              UseWeVPN=0
              WeVPNSuperRandom=0
              WeVPNMultipleCountries=0
              WeVPNCountry="USA"
              WeVPNCountry2=0
              WeVPNCountry3=0
              WeVPNLoadReset=50
            fi
          ;;

          7) # -----------------------------------------------------------------------------------------
             echo ""
             echo -e "${CCyan} 7. Would you like to reset your VPN connection to a random VPN client"
             echo -e "${CCyan} slot daily? ${CYellow}(No=0, Yes=1) (Default = 1)${CClear}"
             while true; do
               read -p " Reset Daily? (0/1): " ResetOption1
                 case $ResetOption1 in
                   [0] ) ResetOption=0; break ;;
                   [1] ) ResetOption=1; break ;;
                   "" ) echo -e "\n Please answer 0 or 1";;
                   * ) echo -e "\n Please answer 0 or 1";;
                 esac
             done
             # -----------------------------------------------------------------------------------------
             if [ "$ResetOption" == "1" ]; then
               echo ""
               echo -e "${CCyan} 7a. What time would you like to reset your connection?"
               echo -e "${CYellow} (Default = 01:00)${CClear}"
               read -p " Reset Time (in HH:MM 24h): " DailyResetTime1
               if [ -z "$DailyResetTime1" ]; then DailyResetTime="01:00"; else DailyResetTime=$DailyResetTime1; fi # Using default value on enter keypress
             else
               ResetOption=0
               DailyResetTime="01:00"
             fi
          ;;

          8) # -----------------------------------------------------------------------------------------
             echo ""
             echo -e "${CCyan} 8. What is the minimum acceptable PING value in milliseconds across"
             echo -e "${CCyan} your VPN tunnel before VPNMON-R2 resets the connection in search for"
             echo -e "${CCyan} a faster/lower PING server? ${CYellow}(Default = 100)${CClear}"
             read -p " Minimum PING (in ms): " MINPING1
             if [ -z "$MINPING1" ]; then MINPING=100; else MINPING=$MINPING1; fi # Using default value on enter keypress
          ;;

          9) # -----------------------------------------------------------------------------------------
             echo ""
             echo -e "${CCyan} 9. How many VPN client slots do you have properly configured? Please"
             echo -e "${CCyan} note: VPN client slots MUST be in sequential order, starting from 1"
             echo -e "${CCyan} through 5. (Example: if you are using slots 1, 2 and 3, but 4 and 5"
             echo -e "${CCyan} are disabled, you would enter 3. ${CYellow}(Default = 5)${CClear}"
             read -p " VPN Clients: " N1
             if [ -z "$N1" ]; then N=5; else N=$N1; fi # Using default value on enter keypress
          ;;

          10) # -----------------------------------------------------------------------------------------
              echo ""
              echo -e "${CCyan} 10. Would you like to show near-realtime VPN bandwidth stats on the UI?"
              echo -e "${CYellow} (No=0, Yes=1) (Default = 0)${CClear}"
              while true; do
                read -p " Show Stats? (0/1): " SHOWSTATS1
                  case $SHOWSTATS1 in
                    [0] ) SHOWSTATS=0; break ;;
                    [1] ) SHOWSTATS=1; break ;;
                    "" ) echo -e "\n Please answer 0 or 1";;
                    * ) echo -e "\n Please answer 0 or 1";;
                  esac
              done
          ;;

          11) # -----------------------------------------------------------------------------------------
              echo ""
              echo -e "${CCyan} 11. How many seconds would you like to delay start-up of VPNMON-R2 in"
              echo -e "${CCyan} order to provide more stability among other competing start-up scripts"
              echo -e "${CCyan} during a reboot? NOTE: VPNMON-R2 itself does not auto-start on a reboot,"
              echo -e "${CCyan} and leaves that method up to you. ${CYellow}(Default = 0)${CClear}"
              read -p " Delay Startup (seconds): " DelayStartup1
              if [ -z "$DelayStartup1" ]; then DelayStartup=0; else DelayStartup=$DelayStartup1; fi # Using default value on enter keypress
          ;;

          12) # -----------------------------------------------------------------------------------------
              echo ""
              echo -e "${CCyan} 12. Would you like to trim your log file when your VPN connection resets?"
              echo -e "${CYellow} (No=0, Yes=1) (Default = $TRIMLOGS)${CClear}"
              while true; do
                read -p " Trim Logs? (0/1): " TRIMLOGS1
                  case $TRIMLOGS1 in
                    [0] ) TRIMLOGS=0; break ;;
                    [1] ) TRIMLOGS=1; break ;;
                    "" ) echo -e "\n Please answer 0 or 1";;
                    * ) echo -e "\n Please answer 0 or 1";;
                  esac
              done
              # -----------------------------------------------------------------------------------------
              if [ "$TRIMLOGS" == "1" ]; then
                  echo ""
                echo -e "${CCyan} 12a. How large would you like your log file to grow (in # of lines)?"
                echo -e "${CCyan} This option will automatically trim your log after each VPN reset."
                echo -e "${CYellow} (Default = 1000 lines)${CClear}"
                read -p " Log file size (in # of lines): " MAXLOGSIZE1
                if [ -z "$MAXLOGSIZE1" ]; then MAXLOGSIZE=1000; else MAXLOGSIZE=$MAXLOGSIZE1; fi # Using default value on enter keypress
              else
                TRIMLOGS=0
                MAXLOGSIZE=1000
              fi
          ;;

          13) # -----------------------------------------------------------------------------------------
              echo ""
              echo -e "${CCyan} 13. Would you like to sync the active VPN slot with YazFi?"
              echo -e "${CYellow} (No=0, Yes=1) (Default = 0)${CClear}"
              while true; do
                read -p " Sync YazFi? (0/1): " SyncYazFi1
                  case $SyncYazFi1 in
                    [0] ) SyncYazFi=0; break ;;
                    [1] ) SyncYazFi=1; break ;;
                    "" ) echo -e "\n Please answer 0 or 1";;
                    * ) echo -e "\n Please answer 0 or 1";;
                  esac
              done
              # -----------------------------------------------------------------------------------------
              if [ "$SyncYazFi" == "1" ]; then
                echo ""
                echo -e "${CCyan} 13a. Please indicate which of your YazFi guest network slots you want to"
                echo -e "${CCyan} sync with the active VPN slot?${CClear}"
                echo ""
                echo -e "${CYellow} Please use the corresponding () key to enable/disable sync for each slot:${CClear}"
                  if [ $YF24GN1 == "1" ]; then YF24GN1Disp="${CGreen}Y${CCyan}"; else YF24GN1Disp="${CRed}N${CCyan}"; fi
                  if [ $YF24GN2 == "1" ]; then YF24GN2Disp="${CGreen}Y${CCyan}"; else YF24GN2Disp="${CRed}N${CCyan}"; fi
                  if [ $YF24GN3 == "1" ]; then YF24GN3Disp="${CGreen}Y${CCyan}"; else YF24GN3Disp="${CRed}N${CCyan}"; fi
                  if [ $YF5GN1 == "1" ]; then YF5GN1Disp="${CGreen}Y${CCyan}"; else YF5GN1Disp="${CRed}N${CCyan}"; fi
                  if [ $YF5GN2 == "1" ]; then YF5GN2Disp="${CGreen}Y${CCyan}"; else YF5GN2Disp="${CRed}N${CCyan}"; fi
                  if [ $YF5GN3 == "1" ]; then YF5GN3Disp="${CGreen}Y${CCyan}"; else YF5GN3Disp="${CRed}N${CCyan}"; fi
                  if [ $YF52GN1 == "1" ]; then YF52GN1Disp="${CGreen}Y${CCyan}"; else YF52GN1Disp="${CRed}N${CCyan}"; fi
                  if [ $YF52GN2 == "1" ]; then YYF52GN2Disp="${CGreen}Y${CCyan}"; else YF52GN2Disp="${CRed}N${CCyan}"; fi
                  if [ $YF52GN3 == "1" ]; then YF52GN3Disp="${CGreen}Y${CCyan}"; else YF52GN3Disp="${CRed}N${CCyan}"; fi
                while true; do
                  echo ""
                  echo -e "${CCyan} 2.4Ghz Primary Guest Network ------- 1 ${CYellow}(1)${CClear} $YF24GN1Disp -- 2 ${CYellow}(2)${CClear} $YF24GN2Disp -- 3 ${CYellow}(3)${CClear} $YF24GN3Disp${CClear}"
                  echo -e "${CCyan} 5.0Ghz Primary Guest Network ------- 1 ${CYellow}(4)${CClear} $YF5GN1Disp -- 2 ${CYellow}(5)${CClear} $YF5GN2Disp -- 3 ${CYellow}(6)${CClear} $YF5GN3Disp${CClear}"
                  echo -e "${CCyan} 5.0Ghz Secondary Guest Network ----- 1 ${CYellow}(7)${CClear} $YF52GN1Disp -- 2 ${CYellow}(8)${CClear} $YF52GN2Disp -- 3 ${CYellow}(9)${CClear} $YF52GN3Disp${CClear}"
                  echo ""
                  read -p " Please select? (1-9, E=Exit): " SelectSlot
                    case $SelectSlot in
                      1) if [ $YF24GN1 == "0" ]; then YF24GN1=1; YF24GN1Disp="${CGreen}Y${CCyan}"; elif [ $YF24GN1 == "1" ]; then YF24GN1=0; YF24GN1Disp="${CRed}N${CCyan}"; fi;;
                      2) if [ $YF24GN2 == "0" ]; then YF24GN2=1; YF24GN2Disp="${CGreen}Y${CCyan}"; elif [ $YF24GN2 == "1" ]; then YF24GN2=0; YF24GN2Disp="${CRed}N${CCyan}"; fi;;
                      3) if [ $YF24GN3 == "0" ]; then YF24GN3=1; YF24GN3Disp="${CGreen}Y${CCyan}"; elif [ $YF24GN3 == "1" ]; then YF24GN3=0; YF24GN3Disp="${CRed}N${CCyan}"; fi;;
                      4) if [ $YF5GN1 == "0" ]; then YF5GN1=1; YF5GN1Disp="${CGreen}Y${CCyan}"; elif [ $YF5GN1 == "1" ]; then YF5GN1=0; YF5GN1Disp="${CRed}N${CCyan}"; fi;;
                      5) if [ $YF5GN2 == "0" ]; then YF5GN2=1; YF5GN2Disp="${CGreen}Y${CCyan}"; elif [ $YF5GN2 == "1" ]; then YF5GN2=0; YF5GN2Disp="${CRed}N${CCyan}"; fi;;
                      6) if [ $YF5GN3 == "0" ]; then YF5GN3=1; YF5GN3Disp="${CGreen}Y${CCyan}"; elif [ $YF5GN3 == "1" ]; then YF5GN3=0; YF5GN3Disp="${CRed}N${CCyan}"; fi;;
                      7) if [ $YF52GN1 == "0" ]; then YF52GN1=1; YF52GN1Disp="${CGreen}Y${CCyan}"; elif [ $YF52GN1 == "1" ]; then YF52GN1=0; YF52GN1Disp="${CRed}N${CCyan}"; fi;;
                      8) if [ $YF52GN2 == "0" ]; then YF52GN2=1; YF52GN2Disp="${CGreen}Y${CCyan}"; elif [ $YF52GN2 == "1" ]; then YF52GN2=0; YF52GN2Disp="${CRed}N${CCyan}"; fi;;
                      9) if [ $YF52GN3 == "0" ]; then YF52GN3=1; YF52GN3Disp="${CGreen}Y${CCyan}"; elif [ $YF52GN3 == "1" ]; then YF52GN3=0; YF52GN3Disp="${CRed}N${CCyan}"; fi;;
                      e) break;;
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
          ;;

          14) # -----------------------------------------------------------------------------------------
              echo ""
              echo -e "${CCyan} 14. For those with Dual-WAN configurations, would you like to allow VPN"
              echo -e "${CCyan} connections on WAN1 while WAN0 is down?"
              echo -e "${CYellow} (No=0, Yes=1) (Default = 1)${CClear}"
              while true; do
                read -p " Allow VPN on WAN1? (0/1): " WAN1Override1
                  case $WAN1Override1 in
                    [0] ) WAN1Override=0; break ;;
                    [1] ) WAN1Override=1; break ;;
                    "" ) echo -e "\n Please answer 0 or 1";;
                    * ) echo -e "\n Please answer 0 or 1";;
                  esac
              done
          ;;

          [Ss]) # -----------------------------------------------------------------------------------------
            echo ""
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
                echo 'RecommendedServer='$RecommendedServer
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
                echo 'UseWeVPN='$UseWeVPN
                echo 'WeVPNSuperRandom='$WeVPNSuperRandom
                echo 'WeVPNMultipleCountries='$WeVPNMultipleCountries
                echo 'WeVPNCountry="'"$WeVPNCountry"'"'
                echo 'WeVPNCountry2="'"$WeVPNCountry2"'"'
                echo 'WeVPNCountry3="'"$WeVPNCountry3"'"'
                echo 'WeVPNLoadReset='$WeVPNLoadReset
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
                echo 'WAN1Override='$WAN1Override
              } > $CFGPATH
            echo -e "${CCyan} Applying config changes to VPNMON-R2..."
            echo -e "$(date) - VPNMON-R2 - Successfully wrote a new config file" >> $LOGFILE
            sleep 3
            return
          ;;

          [Ee]) # -----------------------------------------------------------------------------------------
            return
          ;;

          esac
    done

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
      echo 'RecommendedServer=0'
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
      echo 'UseWeVPN=0'
      echo 'WeVPNSuperRandom=0'
      echo 'WeVPNMultipleCountries=0'
      echo 'WeVPNCountry="USA"'
      echo 'WeVPNCountry2=0'
      echo 'WeVPNCountry3=0'
      echo 'WeVPNLoadReset=50'
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
      echo 'WAN1Override=1'
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
  echo -e " Update Utility${CClear}"
  echo ""
  echo -e "${CCyan} Current Version: ${CYellow}$Version${CClear}"
  echo -e "${CCyan} Updated Version: ${CYellow}$DLVersion${CClear}"
  echo ""
  if [ "$Version" == "$DLVersion" ]
    then
      echo -e "${CCyan} You are on the latest version! Would you like to download anyways?${CClear}"
      echo -e "${CCyan} This will overwrite your local copy with the current build.${CClear}"
      if promptyn " (y/n): "; then
        echo ""
        echo -e "${CCyan} Downloading VPNMON-R2 ${CYellow}v$DLVersion${CClear}"
        curl --silent --retry 3 "https://raw.githubusercontent.com/ViktorJp/VPNMON-R2/master/vpnmon-r2-$DLVersion.sh" -o "/jffs/scripts/vpnmon-r2.sh" && chmod a+rx "/jffs/scripts/vpnmon-r2.sh"
        echo ""
        echo -e "${CCyan} Download successful!${CClear}"
        echo -e "$(date) - VPNMON-R2 - Successfully downloaded VPNMON-R2 v$DLVersion" >> $LOGFILE
        echo ""
        echo -e "${CYellow} Please exit, restart and configure new options using: 'vpnmon-r2 -config'.${CClear}"
        echo -e "${CYellow} NOTE: New features may have been added that require your input to take${CClear}"
        echo -e "${CYellow} advantage of its full functionality.${CClear}"
        echo ""
        read -rsp $' Press any key to continue...\n' -n1 key
        return
      else
        echo ""
        echo ""
        echo -e "${CGreen} Exiting Update Utility...${CClear}"
        sleep 1
        return
      fi
    else
      echo -e "${CCyan} There is a new version out there! Would you like to update?${CClear}"
      if promptyn " (y/n): "; then
        echo ""
        echo -e "${CCyan} Downloading VPNMON-R2 ${CYellow}v$DLVersion${CClear}"
        curl --silent --retry 3 "https://raw.githubusercontent.com/ViktorJp/VPNMON-R2/master/vpnmon-r2-$DLVersion.sh" -o "/jffs/scripts/vpnmon-r2.sh" && chmod a+rx "/jffs/scripts/vpnmon-r2.sh"
        echo ""
        echo -e "${CCyan} Download successful!${CClear}"
        echo -e "$(date) - VPNMON-R2 - Successfully updated VPNMON-R2 v$Version to v$DLVersion" >> $LOGFILE
        echo ""
        echo -e "${CYellow} Please exit, restart and configure new options using: 'vpnmon-r2 -config'.${CClear}"
        echo -e "${CYellow} NOTE: New features may have been added that require your input to take${CClear}"
        echo -e "${CYellow} advantage of its full functionality.${CClear}"
        echo ""
        read -rsp $' Press any key to continue...\n' -n1 key
        return
      else
        echo ""
        echo ""
        echo -e "${CGreen} Exiting Update Utility...${CClear}"
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
  echo -e " Uninstall Utility${CClear}"
  echo ""
  echo -e "${CCyan} You are about to uninstall VPNMON-R2!  This action is irreversible."
  echo -e "${CCyan} Do you wish to proceed?${CClear}"
  if promptyn " (y/n): "; then
    echo ""
    echo -e "\n${CCyan} Are you sure? Please type 'Y' to validate you want to proceed.${CClear}"
      if promptyn " (y/n): "; then
        clear
        rm -r /jffs/addons/vpnmon-r2.d
        rm /jffs/scripts/vpnmon-r2.sh
        echo ""
        echo -e "\n${CGreen} VPNMON-R2 has been uninstalled...${CClear}"
        echo ""
        exit 0
      else
        echo ""
        echo -e "\n${CGreen} Exiting Uninstall Utility...${CClear}"
        sleep 1
        return
      fi
  else
    echo ""
    echo -e "\n${CGreen} Exiting Uninstall Utility...${CClear}"
    sleep 1
    return
  fi
}

# -------------------------------------------------------------------------------------------------------------------------

# vlogs is a function that calls the nano text editor to view the VPNMON-R2 log file
vlogs() {

export TERM=linux
nano $LOGFILE

}

# -------------------------------------------------------------------------------------------------------------------------

# vsetup is a function that sets up and confiures VPNMON-R2 on your router...
vsetup () {

  # Check for and add an alias for VPNMON-R2
  if ! grep -F "sh /jffs/scripts/vpnmon-r2.sh" /jffs/configs/profile.add >/dev/null 2>/dev/null; then
		echo "alias vpnmon-r2=\"sh /jffs/scripts/vpnmon-r2.sh\" # VPNMON-R2" >> /jffs/configs/profile.add
  fi

  while true; do
    clear
    logo
    echo -e " Setup Utility${CClear}" # Provide main setup menu
    echo ""
    echo -e "${CGreen} ----------------------------------------------------------------"
    echo -e "${CGreen} Operations"
    echo -e "${CGreen} ----------------------------------------------------------------"
    echo -e " ${InvDkGray}${CWhite} sc ${CClear}${CCyan}: Setup and Configure VPNMON-R2"
    echo -e " ${InvDkGray}${CWhite} fr ${CClear}${CCyan}: Force Re-install Entware Dependencies"
    echo -e " ${InvDkGray}${CWhite} up ${CClear}${CCyan}: Check for latest updates"
    echo -e " ${InvDkGray}${CWhite} vl ${CClear}${CCyan}: View logs"
    echo -e " ${InvDkGray}${CWhite} un ${CClear}${CCyan}: Uninstall"
    echo -e " ${InvDkGray}${CWhite}  e ${CClear}${CCyan}: Exit"
    echo -e "${CGreen} ----------------------------------------------------------------"
    if [ "$FromUI" == "0" ]; then
      echo -e "${CGreen} Launch"
      echo -e "${CGreen} ----------------------------------------------------------------"
      echo -e " ${InvDkGray}${CWhite} m1 ${CClear}${CCyan}: Launch VPNMON-R2 into Normal Monitoring Mode"
      echo -e " ${InvDkGray}${CWhite} m2 ${CClear}${CCyan}: Launch VPNMON-R2 into Normal Monitoring Mode w/ Screen"
      echo -e "${CGreen} ----------------------------------------------------------------"
    fi
    echo ""
    printf " Selection: "
    read -r InstallSelection

    # Execute chosen selections
        case "$InstallSelection" in

          sc) # Check for existence of entware, and if so proceed and install the timeout package, then run vpnmon-r2 -config
            clear
            if [ -f "/opt/bin/timeout" ] && [ -f "/opt/sbin/screen" ] && [ -f "/opt/bin/jq" ]; then
              vconfig
            else
              logo
              echo -e "${CYellow} Installing VPNMON-R2 Dependencies...${CClear}"
              echo ""
              echo -e "${CCyan} VPNMON-R2 has some dependencies in order to function correctly, namely,${CClear}"
              echo -e "${CCyan} CoreUtils-Timeout, JQuery and the Screen utility. These utilities ${CClear}"
              echo -e "${CCyan} require you to have Entware already installed using the AMTM tool. If${CClear}"
              echo -e "${CCyan} Entware is present, the Timeout, JQ and Screen utilities will ${CClear}"
              echo -e "${CCyan} automatically be downloaded and installed during this setup process.${CClear}"
              echo ""
              echo -e "${CGreen} CoreUtils-Timeout${CCyan} is a utility that provides more stability for${CClear}"
              echo -e "${CCyan} certain routers (like the RT-AC86U) which has a tendency to randomly${CClear}"
              echo -e "${CCyan} hang scripts running on this router model.${CClear}"
              echo ""
              echo -e "${CGreen} Screen${CCyan} is a utility that allows you to run SSH scripts in a standalone${CClear}"
              echo -e "${CCyan} environment directly on the router itself, instead of running your${CClear}"
              echo -e "${CCyan} commands or a script from a network-attached SSH client. This can${CClear}"
              echo -e "${CCyan} provide greater stability due to it running on the router itself.${CClear}"
              echo ""
              echo -e "${CGreen} JQuery${CCyan} is a utility for querying data across the internet through the${CClear}"
              echo -e "${CCyan} the means of APIs for the purposes of interacting with the various VPN${CClear}"
              echo -e "${CCyan} providers to get a list of available VPN hosts in the selected country.${CClear}"
              echo ""
              [ -z "$(nvram get odmpid)" ] && RouterModel="$(nvram get productid)" || RouterModel="$(nvram get odmpid)" # Thanks @thelonelycoder for this logic
              echo -e "${CCyan} Your router model is: ${CYellow}$RouterModel"
              echo ""
              echo -e "${CCyan} Ready to install?${CClear}"
              if promptyn " (y/n): "
                then
                  if [ -d "/opt" ]; then # Does entware exist? If yes proceed, if no error out.
                    echo ""
                    echo -e "\n${CGreen} Updating Entware Packages...${CClear}"
                    echo ""
                    opkg update
                    echo ""
                    echo -e "${CGreen} Installing Entware CoreUtils-Timeout Package...${CClear}"
                    echo ""
                    opkg install coreutils-timeout
                    echo ""
                    echo -e "${CGreen} Installing Entware Screen Package...${CClear}"
                    echo ""
                    opkg install screen
                    echo ""
                    echo -e "${CGreen} Installing Entware JQuery Package...${CClear}"
                    echo ""
                    opkg install jq
                    echo ""
                    echo -e "${CGreen} Install completed...${CClear}"
                    echo ""
                    read -rsp $' Press any key to continue...\n' -n1 key
                    echo ""
                    echo -e "${CGreen} Executing Configuration Utility...${CClear}"
                    sleep 2
                    vconfig
                  else
                    clear
                    echo -e "${CGreen} ERROR: Entware was not found on this router...${CClear}"
                    echo -e "${CGreen} Please install Entware using the AMTM utility before proceeding...${CClear}"
                    echo ""
                    sleep 3
                  fi
                else
                  echo ""
                  echo -e "\n${CGreen} Executing Configuration Utility...${CClear}"
                  sleep 2
                  vconfig
              fi
            fi
          ;;


          fr) # Force re-install the CoreUtils timeout/screen package
            clear
            logo
            echo -e "${CYellow} Force Re-installing VPNMON-R2 Dependencies...${CClear}"
            echo ""
            echo -e "${CCyan} Would you like to re-install the CoreUtils-Timeout, JQuery and the${CClear}"
            echo -e "${CCyan} Screen utility? These utilities require you to have Entware already${CClear}"
            echo -e "${CCyan} installed using the AMTM tool. If Entware is present, the Timeout,${CClear}"
            echo -e "${CCyan} JQ, and Screen utilities will be uninstalled, downloaded and${CClear}"
            echo -e "${CCyan} re-installed during this setup process.${CClear}"
            echo ""
            echo -e "${CGreen} CoreUtils-Timeout${CCyan} is a utility that provides more stability for${CClear}"
            echo -e "${CCyan} certain routers (like the RT-AC86U) which has a tendency to randomly${CClear}"
            echo -e "${CCyan} hang scripts running on this router model.${CClear}"
            echo ""
            echo -e "${CGreen} Screen${CCyan} is a utility that allows you to run SSH scripts in a standalone${CClear}"
            echo -e "${CCyan} environment directly on the router itself, instead of running your${CClear}"
            echo -e "${CCyan} commands or a script from a network-attached SSH client. This can${CClear}"
            echo -e "${CCyan} provide greater stability due to it running on the router itself.${CClear}"
            echo ""
            echo -e "${CGreen} JQuery${CCyan} is a utility for querying data across the internet through the${CClear}"
            echo -e "${CCyan} the means of APIs for the purposes of interacting with the various VPN${CClear}"
            echo -e "${CCyan} providers to get a list of available VPN hosts in the selected country.${CClear}"
            echo ""
            [ -z "$(nvram get odmpid)" ] && RouterModel="$(nvram get productid)" || RouterModel="$(nvram get odmpid)" # Thanks @thelonelycoder for this logic
            echo -e "${CCyan} Your router model is: ${CYellow}$RouterModel"
            echo ""
            echo -e "${CCyan} Force Re-install?${CClear}"
            if promptyn " (y/n): "
              then
                if [ -d "/opt" ]; then # Does entware exist? If yes proceed, if no error out.
                  echo ""
                  echo -e "\n${CGreen} Updating Entware Packages...${CClear}"
                  echo ""
                  opkg update
                  echo ""
                  echo -e "${CGreen} Force Re-installing Entware CoreUtils-Timeout Package...${CClear}"
                  echo ""
                  opkg install --force-reinstall coreutils-timeout
                  echo ""
                  echo -e "${CGreen} Force Re-installing Entware Screen Package...${CClear}"
                  echo ""
                  opkg install --force-reinstall screen
                  echo ""
                  echo -e "${CGreen} Force Re-installing Entware JQuery Package...${CClear}"
                  echo ""
                  opkg install --force-reinstall jq
                  echo ""
                  echo -e "${CGreen} Re-install completed...${CClear}"
                  echo ""
                  read -rsp $' Press any key to continue...\n' -n1 key
                else
                  clear
                  echo -e "${CGreen} ERROR: Entware was not found on this router...${CClear}"
                  echo -e "${CGreen} Please install Entware using the AMTM utility before proceeding...${CClear}"
                  echo ""
                  sleep 3
                fi
            fi
          ;;

          up)
            echo ""
            vupdate
          ;;

          m1)
            echo ""
            echo -e "\n${CGreen} Launching VPNMON-R2 into Monitor Mode...${CClear}"
            sleep 2
            sh $APPPATH -monitor
          ;;

          m2)
            echo ""
            echo -e "\n${CGreen} Launching VPNMON-R2 into Monitor Mode with Screen Utility...${CClear}"
            sleep 2
            sh $APPPATH -screen
          ;;

          vl)
            echo ""
            vlogs
          ;;

          un)
            echo ""
            vuninstall
          ;;

          e)
            echo -e "${CClear}"
            exit 0
          ;;

          *)
            echo ""
            echo -e "${CRed} Invalid choice - Please enter a valid option...${CClear}"
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
      echo " VPNMON-R2 v$Version"
      echo ""
      echo " Exiting due to missing commandline options!"
      echo " (run 'vpnmon-r2 -h' for help)"
      echo ""
      echo -e "${CClear}"
      exit 0
  fi

  # Check and see if an invalid commandline option is being used
  if [ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "-config" ] || [ "$1" == "-monitor" ] || [ "$1" == "-log" ] || [ "$1" == "-update" ] || [ "$1" == "-setup" ] || [ "$1" == "-uninstall" ] || [ "$1" == "-screen" ] || [ "$1" == "-reset" ] || [ "$1" == "-pause" ] || [ "$1" == "-stop" ] || [ "$1" == "-resume" ] || [ "$1" == "-status" ] || [ "$1" == "-failover" ]
    then
      clear
    else
      clear
      echo ""
      echo " VPNMON-R2 v$Version"
      echo ""
      echo " Exiting due to invalid commandline options!"
      echo " (run 'vpnmon-r2 -h' for help)"
      echo ""
      echo -e "${CClear}"
      exit 0
  fi

  # Check to see if the help option is being called
  if [ "$1" == "-h" ] || [ "$1" == "-help" ]
    then
    clear
    echo ""
    echo " VPNMON-R2 v$Version Commandline Option Usage:"
    echo ""
    echo " vpnmon-r2 -h | -help"
    echo " vpnmon-r2 -log"
    echo " vpnmon-r2 -config"
    echo " vpnmon-r2 -update"
    echo " vpnmon-r2 -setup"
    echo " vpnmon-r2 -reset"
    echo " vpnmon-r2 -pause"
    echo " vpnmon-r2 -stop"
    echo " vpnmon-r2 -resume"
    echo " vpnmon-r2 -status"
    echo " vpnmon-r2 -failover"
    echo " vpnmon-r2 -uninstall"
    echo " vpnmon-r2 -screen"
    echo " vpnmon-r2 -monitor"
    echo ""
    echo " -h | -help (this output)"
    echo " -log (display the current log contents)"
    echo " -config (configuration utility)"
    echo " -update (script update utility)"
    echo " -setup (setup/dependencies utility)"
    echo " -reset (initiate a VPN reset)"
    echo " -pause (pauses all operations, vpn connection stay up)"
    echo " -stop (stops all operations, vpn connections go down)"
    echo " -resume (resumes normal operations)"
    echo " -status (displays current operating state)"
    echo " -failover (stops all operations during wan failover)"
    echo " -uninstall (uninstall utility)"
    echo " -screen (normal VPN monitoring using the screen utility)"
    echo " -monitor (normal VPN monitoring operations)"
    echo ""
    echo -e "${CClear}"
    exit 0
  fi

  # Check to see if the pause option is being called, and write a status file indicating "PAUSED"
  if [ "$1" == "-pause" ]
    then
      clear

      STATE=$(cat $APPSTATUS | sed -n '1p') 2>&1
      LASTSLOT=$(cat $APPSTATUS | sed -n '2p') 2>&1
      if [ -z $STATE ]; then STATE="UNKNOWN"; fi
      if [ -z $LASTSLOT ]; then LASTSLOT=$N; fi

      { echo 'PAUSED'
        echo $LASTSLOT
      } > $APPSTATUS

      echo ""
      echo -e "${CYellow} STATUS:${CClear}"
      echo -e "${CGreen} VPNMON-R2 is entering a ${CCyan}PAUSED ${CGreen}state...${CClear}"
      echo -e "${CGreen} Last known VPN Client slot used:${CCyan} $LASTSLOT ${CClear}"
      echo -e "${CGreen} Use ${CCyan}'vpnmon-r2 -resume'${CGreen} to return to normal operations.${CClear}"
      echo -e "$(date) - VPNMON-R2 ----------> INFO: Entering a PAUSED state" >> $LOGFILE
      echo ""
      exit 0
  fi

  # Check to see if the stop option is being called, and write a status file indicating "STOPPED"
  if [ "$1" == "-stop" ]
    then
      clear

      STATE=$(cat $APPSTATUS | sed -n '1p') 2>&1
      LASTSLOT=$(cat $APPSTATUS | sed -n '2p') 2>&1
      if [ -z $STATE ]; then STATE="UNKNOWN"; fi
      if [ -z $LASTSLOT ]; then LASTSLOT=$N; fi

      { echo 'STOPPED'
        echo $LASTSLOT
      } > $APPSTATUS

      echo ""
      echo -e "${CYellow} STATUS:${CClear}"
      echo -e "${CGreen} VPNMON-R2 is entering a ${CCyan}STOPPED ${CGreen}state...${CClear}"
      echo -e "${CGreen} Last known VPN Client slot used:${CCyan} $LASTSLOT ${CClear}"
      echo -e "${CGreen} Use ${CCyan}'vpnmon-r2 -resume'${CGreen} to return to normal operations.${CClear}"
      echo -e "$(date) - VPNMON-R2 ----------> INFO: Entering a STOPPED state" >> $LOGFILE
      echo ""
      exit 0
  fi

  # Check to see if the failover option is being called, and write a status file indicating "FAILOVER"
  if [ "$1" == "-failover" ]
    then
      clear

      STATE=$(cat $APPSTATUS | sed -n '1p') 2>&1
      LASTSLOT=$(cat $APPSTATUS | sed -n '2p') 2>&1
      if [ -z $STATE ]; then STATE="UNKNOWN"; fi
      if [ -z $LASTSLOT ]; then LASTSLOT=$N; fi

      if [ $STATE == "FAILOVER" ]; then
        { echo 'NORMAL'
          echo $LASTSLOT
        } > $APPSTATUS

        echo ""
        echo -e "${CYellow} STATUS:${CClear}"
        echo -e "${CGreen} VPNMON-R2 is returning to a ${CCyan}NORMAL ${CGreen}state from a FAILOVER...${CClear}"
        echo -e "${CGreen} Last known VPN Client slot used:${CCyan} $LASTSLOT ${CClear}"
        echo -e "$(date) - VPNMON-R2 ----------> INFO: Returning to a NORMAL state from a FAILOVER" >> $LOGFILE
        echo ""
        exit 0
      else
        { echo 'FAILOVER'
          echo $LASTSLOT
        } > $APPSTATUS

        echo ""
        echo -e "${CYellow} STATUS:${CClear}"
        echo -e "${CGreen} VPNMON-R2 is entering a ${CCyan}FAILOVER ${CGreen}state...${CClear}"
        echo -e "${CGreen} Last known VPN Client slot used:${CCyan} $LASTSLOT ${CClear}"
        echo -e "$(date) - VPNMON-R2 ----------> INFO: Entering a FAILOVER state" >> $LOGFILE
        echo ""
        exit 0
      fi
  fi

  # Check to see if the resume option is being called, and write a status file indicating "NORMAL"
  if [ "$1" == "-resume" ]
    then
      clear

      STATE=$(cat $APPSTATUS | sed -n '1p') 2>&1
      LASTSLOT=$(cat $APPSTATUS | sed -n '2p') 2>&1
      if [ -z $STATE ]; then STATE="UNKNOWN"; fi
      if [ -z $LASTSLOT ]; then LASTSLOT=$N; fi

      { echo 'RESUMING'
        echo $LASTSLOT
      } > $APPSTATUS

      echo ""
      echo -e "${CYellow} STATUS:${CClear}"
      echo -e "${CGreen} VPNMON-R2 is returning to a ${CCyan}NORMAL ${CGreen}operations state...${CClear}"
      echo -e "${CGreen} Last known VPN Client slot used:${CCyan} $LASTSLOT ${CClear}"
      echo -e "$(date) - VPNMON-R2 ----------> INFO: Returning to a NORMAL operations state" >> $LOGFILE
      echo ""
      exit 0
  fi

  # Check to see if the status option is being called, and indicate the current status
  if [ "$1" == "-status" ]
    then
      clear

      STATE=$(cat $APPSTATUS | sed -n '1p') 2>&1
      LASTSLOT=$(cat $APPSTATUS | sed -n '2p') 2>&1
      if [ -z $STATE ]; then STATE="UNKNOWN"; fi
      if [ -z $LASTSLOT ]; then LASTSLOT=$N; fi

      echo ""
      echo -e "${CYellow} STATUS:${CClear}"
      echo -e "${CGreen} VPNMON-R2 is currently in a ${CCyan}$STATE ${CGreen}state...${CClear}"
      echo -e "${CGreen} Last known VPN Client slot used:${CCyan} $LASTSLOT ${CClear}"
      echo -e "$(date) - VPNMON-R2 ----------> STATUS: $STATE -- SLOT: $LASTSLOT" >> $LOGFILE
      echo ""
      exit 0
  fi

  # Check to see if the log option is being called, and display through nano
  if [ "$1" == "-log" ]
    then
      vlogs
      exit 0
  fi

  # Check to see if the configuration option is being called, and run through setup utility
  if [ "$1" == "-config" ]
    then
      vconfig
      echo -e "${CClear}"
      exit 0
  fi

  # Check to see if the update option is being called
  if [ "$1" == "-update" ]
    then
      vupdate
      echo -e "${CClear}"
      exit 0
  fi

  # Check to see if the install option is being called
  if [ "$1" == "-setup" ]
    then
      vsetup
  fi

  # Check to see if the reset option is being called
  if [ "$1" == "-reset" ]
    then
      clear
      if [ -f $CFGPATH ] && [ -f "/opt/bin/timeout" ] && [ -f "/opt/sbin/screen" ] && [ -f "/opt/bin/jq" ]; then
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
      else
        echo -e "${CRed} Error: VPNMON-R2 is not configured.  Please run 'vpnmon-r2 -setup' to complete setup${CClear}"
        echo ""
        echo -e "$(date) - VPNMON-R2 ----------> ERROR: VPNMON-R2 is not configured. Please run the setup tool." >> $LOGFILE
        kill 0
      fi
      logo
      echo -e "${CRed} VPNMON-R2 is executing VPN Reset via Commandline Switch...${CClear}"
      echo -e "$(date) - VPNMON-R2 ----------> INFO: Executing VPN Reset via Commandline Switch" >> $LOGFILE
      echo ""
      RESETSWITCH=1
      vpnreset
      echo -e "${CClear}"
      exit 0
  fi

  # Check to see if the uninstall option is being called
  if [ "$1" == "-uninstall" ]
    then
      vuninstall
      echo -e "${CClear}"
      exit 0
  fi

  # Check to see if the screen option is being called and run operations normally using the screen utility
  if [ "$1" == "-screen" ]
    then
      screen -wipe >/dev/null 2>&1 # Kill any dead screen sessions
      sleep 1
      ScreenSess=$(screen -ls | grep "vpnmon-r2" | awk '{print $1}' | cut -d . -f 1)
      if [ -z $ScreenSess ]; then
        clear
        echo -e "${CGreen} Executing VPNMON-R2 v$Version using the SCREEN utility...${CClear}"
        echo ""
        echo -e "${CCyan} IMPORTANT:${CClear}"
        echo -e "${CCyan} In order to keep VPNMON-R2 running in the background,${CClear}"
        echo -e "${CCyan} properly exit the SCREEN session by using: CTRL-A + D${CClear}"
        echo ""
        screen -dmS "vpnmon-r2" $APPPATH -monitor
        sleep 2
        if [ ! -f /jffs/addons/vpnmon-r2.d/titanspeed.txt ]; then
          echo -e "${CGreen} Switching to the SCREEN session in T-5 sec...${CClear}"
          echo -e "${CClear}"
          SPIN=5
          spinner
        fi
        screen -r vpnmon-r2
        exit 0
      else
        clear
        if [ ! -f /jffs/addons/vpnmon-r2.d/titanspeed.txt ]; then
          echo -e "${CGreen} Connecting to existing VPNMON-R2 v$Version SCREEN session...${CClear}"
          echo ""
          echo -e "${CCyan} IMPORTANT:${CClear}"
          echo -e "${CCyan} In order to keep VPNMON-R2 running in the background,${CClear}"
          echo -e "${CCyan} properly exit the SCREEN session by using: CTRL-A + D${CClear}"
          echo ""
          echo -e "${CGreen} Switching to the SCREEN session in T-5 sec...${CClear}"
          echo -e "${CClear}"
          SPIN=5
          spinner
        fi
        screen -dr $ScreenSess
        exit 0
      fi
  fi

  # Check to see if the monitor option is being called and run operations normally
  if [ "$1" == "-monitor" ]
    then
      clear
      if [ -f $CFGPATH ] && [ -f "/opt/bin/timeout" ] && [ -f "/opt/sbin/screen" ] && [ -f "/opt/bin/jq" ]; then
        source $CFGPATH

          # Clean up lockfile
          rm $LOCKFILE >/dev/null 2>&1

          # Write Status file
          LASTSLOT=$(cat $APPSTATUS | sed -n '2p') 2>&1
          if [ -z $LASTSLOT ]; then LASTSLOT=$N; fi

          { echo 'NORMAL'
            echo $LASTSLOT
          } > $APPSTATUS

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

          if [ "$DelayStartup" != "0" ]
            then
              SPIN=$DelayStartup
              echo -e "${CGreen} Delaying VPNMON-R2 start-up for $DelayStartup seconds..."
              echo ""
              spinner
          fi

      else
        echo -e "${CRed} Error: VPNMON-R2 is not configured.  Please run 'vpnmon-r2 -setup'"
        echo -e "${CRed} to complete setup${CClear}"
        echo ""
        echo -e "$(date) - VPNMON-R2 ----------> ERROR: VPNMON-R2 is not configured. Please run the setup tool." >> $LOGFILE
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

  # Check for external commandline activity
  lockcheck

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
          echo -e "\n\n${CCyan} VPNMON-R2 is executing a scheduled VPN Reset${CClear}\n"
          echo -e "$(date) - VPNMON-R2 ----------> INFO: Executing scheduled VPN Reset" >> $LOGFILE

          vpnreset

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
  fi

  # Calculate days, hours, minutes and seconds between VPN resets
  END=$(date +%s)
  SDIFF=$((END-START))
  LASTVPNRESET=$(printf '%dd %02dh:%02dm:%02ds\n' $(($SDIFF/86400)) $(($SDIFF%86400/3600)) $(($SDIFF%3600/60)) $(($SDIFF%60)))

  # clear screen
  clear

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

  echo -e "${CGreen}/${CRed}General Info${CClear}${CGreen}\_____________________________________________________${CClear}"
  echo ""

  # Show the date and time and adjust the length of the line based on the number of chars in the timezone abbreviation
  tzone=$(date +%Z)
  tzonechars=$(echo ${#tzone})

  if [ $tzonechars = 1 ]; then dashes="---------";
  elif [ $tzonechars = 2 ]; then dashes="--------";
  elif [ $tzonechars = 3 ]; then dashes="-------";
  elif [ $tzonechars = 4 ]; then dashes="------";
  elif [ $tzonechars = 5 ]; then dashes="-----"; fi

  echo -e "${InvCyan} ${CClear}${CCyan} $(date)${CGreen} $dashes ${CGreen}Last Reset: ${CWhite}${InvDkGray}$LASTVPNRESET${CClear}"

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
  echo -e "${InvCyan} ${CClear}${CCyan} VPN State 1:$state1 2:$state2 3:$state3 4:$state4 5:$state5${CClear}${CGreen} --- ${CGreen}Public VPN IP: ${CWhite}${InvDkGray}$ICANHAZIP${CClear}"

  if [ $ResetOption -eq 1 ]
    then
      echo -e "${InvCyan} ${CClear}${CCyan} WAN State 0:$wstate0 1:$wstate1${CGreen} ----------------- ${CGreen}Sched Reset: ${CWhite}${InvDkGray}$ConvDailyResetTime${CClear}${CYellow} / ${CWhite}${InvDkGray}$INTERVAL Sec${CClear}"
    else
      echo -e "${InvCyan} ${CClear}${CCyan} WAN State 0:$wstate0 1:$wstate1${CGreen} -------------------- ${CGreen}Interval: ${CWhite}${InvDkGray}$INTERVAL Sec${CClear}"
  fi

  if [ -f /jffs/addons/killmon.d/killmon.cfg ]; then
    KILLMONSTATE=$(cat /jffs/addons/killmon.d/killmon.cfg | sed -n '1p' | cut -d '"' -f2) 2>&1
    KILLMONPROT=$(cat /jffs/addons/killmon.d/killmon.cfg | sed -n '2p' | cut -d '"' -f2) 2>&1
    KILLMONMODE=$(cat /jffs/addons/killmon.d/killmon.cfg | sed -n '3p' | cut -d '"' -f2) 2>&1
    KILLMON6STATE=$(cat /jffs/addons/killmon.d/killmon.cfg | sed -n '4p' | cut -d '"' -f2) 2>&1
    KILLMON6MODE=$(cat /jffs/addons/killmon.d/killmon.cfg | sed -n '5p' | cut -d '"' -f2) 2>&1

    if [ "$($timeoutcmd$timeoutsec nvram get ipv6_service)" = "disabled" ]; then
      ipv6service=0
    else
      ipv6service=1
    fi

    echo -e "${CGreen} _________________________${CClear}"
    echo -e "${CGreen}/${CRed}VPN Kill Switch (KILLMON)${CClear}${CGreen}\________________________________________${CClear}"
    echo ""

    if [ $ipv6service -eq 0 ]; then
      if [ "$KILLMONSTATE" == "ENABLED" ] && [ "$KILLMONPROT" == "ENABLED" ]; then
        echo -e "${InvGreen} ${CClear}${CGreen} Status IP4: ${CWhite}${InvGreen}$KILLMONSTATE${CClear}${CGreen} | Reboot Protection: ${CWhite}${InvGreen}$KILLMONPROT${CClear}"
      elif [ "$KILLMONSTATE" == "DISABLED" ] && [ "$KILLMONPROT" == "ENABLED" ]; then
        echo -e "${InvYellow} ${CClear}${CGreen} Status IP4: ${CWhite}${InvRed}$KILLMONSTATE${CClear}${CGreen} | Reboot Protection: ${CWhite}${InvGreen}$KILLMONPROT${CClear}"
      elif [ "$KILLMONSTATE" == "ENABLED" ] && [ "$KILLMONPROT" == "DISABLED" ]; then
        echo -e "${InvYellow} ${CClear}${CGreen} Status IP4: ${CWhite}${InvGreen}$KILLMONSTATE${CClear}${CGreen} | Reboot Protection: ${CWhite}${InvRed}$KILLMONPROT${CClear}"
      elif [ "$KILLMONSTATE" == "DISABLED" ] && [ "$KILLMONPROT" == "DISABLED" ]; then
        echo -e "${InvRed} ${CClear}${CGreen} Status IP4: ${CWhite}${InvRed}$KILLMONSTATE${CClear}${CGreen} | Reboot Protection: ${CWhite}${InvRed}$KILLMONPROT${CClear}"
      fi
    else
      if [ "$KILLMONSTATE" == "ENABLED" ] && [ "$KILLMON6STATE" == "ENABLED" ] && [ "$KILLMONPROT" == "ENABLED" ]; then
        echo -e "${InvGreen} ${CClear}${CGreen} Status IP4: ${CWhite}${InvGreen}$KILLMONSTATE${CClear}${CGreen} | IP6: ${CWhite}${InvGreen}$KILLMON6STATE${CClear}${CGreen} | Reboot Protection: ${CWhite}${InvGreen}$KILLMONPROT${CClear}"
      elif [ "$KILLMONSTATE" == "DISABLED" ] && [ "$KILLMON6STATE" == "ENABLED" ] && [ "$KILLMONPROT" == "ENABLED" ]; then
        echo -e "${InvYellow} ${CClear}${CGreen} Status IP4: ${CWhite}${InvRed}$KILLMONSTATE${CClear}${CGreen} | IP6: ${CWhite}${InvGreen}$KILLMON6STATE${CClear}${CGreen} | Reboot Protection: ${CWhite}${InvGreen}$KILLMONPROT${CClear}"
      elif [ "$KILLMONSTATE" == "ENABLED" ] && [ "$KILLMON6STATE" == "DISABLED" ] && [ "$KILLMONPROT" == "ENABLED" ]; then
        echo -e "${InvYellow} ${CClear}${CGreen} Status IP4: ${CWhite}${InvGreen}$KILLMONSTATE${CClear}${CGreen} | IP6: ${CWhite}${InvRed}$KILLMON6STATE${CClear}${CGreen} | Reboot Protection: ${CWhite}${InvGreen}$KILLMONPROT${CClear}"
      elif [ "$KILLMONSTATE" == "ENABLED" ] && [ "$KILLMON6STATE" == "ENABLED" ] && [ "$KILLMONPROT" == "DISABLED" ]; then
        echo -e "${InvYellow} ${CClear}${CGreen} Status IP4: ${CWhite}${InvGreen}$KILLMONSTATE${CClear}${CGreen} | IP6: ${CWhite}${InvGreen}$KILLMON6STATE${CClear}${CGreen} | Reboot Protection: ${CWhite}${InvRed}$KILLMONPROT${CClear}"
      elif [ "$KILLMONSTATE" == "DISABLED" ] && [ "$KILLMON6STATE" == "DISABLED" ] && [ "$KILLMONPROT" == "ENABLED" ]; then
        echo -e "${InvYellow} ${CClear}${CGreen} Status IP4: ${CWhite}${InvRed}$KILLMONSTATE${CClear}${CGreen} | IP6: ${CWhite}${InvRed}$KILLMON6STATE${CClear}${CGreen} | Reboot Protection: ${CWhite}${InvGreen}$KILLMONPROT${CClear}"
      elif [ "$KILLMONSTATE" == "ENABLED" ] && [ "$KILLMON6STATE" == "DISABLED" ] && [ "$KILLMONPROT" == "DISABLED" ]; then
        echo -e "${InvYellow} ${CClear}${CGreen} Status IP4: ${CWhite}${InvGreen}$KILLMONSTATE${CClear}${CGreen} | IP6: ${CWhite}${InvRed}$KILLMON6STATE${CClear}${CGreen} | Reboot Protection: ${CWhite}${InvRed}$KILLMONPROT${CClear}"
      elif [ "$KILLMONSTATE" == "DISABLED" ] && [ "$KILLMON6STATE" == "DISABLED" ] && [ "$KILLMONPROT" == "DISABLED" ]; then
        echo -e "${InvRed} ${CClear}${CGreen} Status IP4: ${CWhite}${InvRed}$KILLMONSTATE${CClear}${CGreen} | IP6: ${CWhite}${InvRed}$KILLMON6STATE${CClear}${CGreen} | Reboot Protection: ${CWhite}${InvRed}$KILLMONPROT${CClear}"
      fi
    fi

    if [ $ipv6service -eq 0 ]; then
      KILLMONRULESCHECK=$(iptables -L | grep -c "KILLMON")

      if [ "$KILLMONSTATE" == "ENABLED" ] && [ $KILLMONRULESCHECK -eq 0 ]; then
        echo -e "${InvRed} ${CClear}${CGreen} Mode IP4: ${CWhite}${InvDkGray}$KILLMONMODE${CClear}${CGreen} | Rules Integrity: ${CWhite}${InvRed}COMPROMISED${CClear}"
        echo -e "$(date) - VPNMON-R2 ----------> WARNING: KILLMON kill switch iptables rules are currently in a COMPROMISED state." >> $LOGFILE
      elif [ "$KILLMONSTATE" == "DISABLED" ] && [ $KILLMONRULESCHECK -eq 0 ]; then
          echo -e "${InvRed} ${CClear}${CGreen} Mode IP4: ${CWhite}${InvDkGray}$KILLMONMODE${CClear}${CGreen} | Rules Integrity: ${CWhite}${InvRed}COMPROMISED${CClear}"
          echo -e "$(date) - VPNMON-R2 ----------> WARNING: KILLMON kill switch iptables rules are currently in a COMPROMISED state." >> $LOGFILE
      else
        echo -e "${InvGreen} ${CClear}${CGreen} Mode IP4: ${CWhite}${InvDkGray}$KILLMONMODE${CClear}${CGreen} | Rules Integrity: ${CWhite}${InvGreen}NOMINAL${CClear}"
      fi
    else
      KILLMONRULESCHECK=$(iptables -L | grep -c "KILLMON")
      KILLMONRULES6CHECK=$(ip6tables -L | grep -c "KILLMON")

      if [ "$KILLMONSTATE" == "ENABLED" ] && [ $KILLMONRULESCHECK -eq 0 ] || [ "$KILLMON6STATE" == "ENABLED" ] && [ $KILLMONRULES6CHECK -eq 0 ]; then
        echo -e "${InvRed} ${CClear}${CGreen} Mode IP4: ${CWhite}${InvDkGray}$KILLMONMODE${CClear}${CGreen} | IP6: ${CWhite}${InvDkGray}$KILLMON6MODE${CClear}${CGreen} | Rules Integrity: ${CWhite}${InvRed}COMPROMISED${CClear}"
        echo -e "$(date) - VPNMON-R2 ----------> WARNING: KILLMON kill switch iptables rules are currently in a COMPROMISED state." >> $LOGFILE
      elif [ "$KILLMONSTATE" == "DISABLED" ] && [ $KILLMONRULESCHECK -eq 0 ] || [ "$KILLMON6STATE" == "DISABLED" ] && [ $KILLMONRULES6CHECK -eq 0 ]; then
        echo -e "${InvRed} ${CClear}${CGreen} Mode IP4: ${CWhite}${InvDkGray}$KILLMONMODE${CClear}${CGreen} | IP6: ${CWhite}${InvDkGray}$KILLMON6MODE${CClear}${CGreen} | Rules Integrity: ${CWhite}${InvRed}COMPROMISED${CClear}"
        echo -e "$(date) - VPNMON-R2 ----------> WARNING: KILLMON kill switch iptables rules are currently in a COMPROMISED state." >> $LOGFILE
      else
        echo -e "${InvGreen} ${CClear}${CGreen} Mode IP4: ${CWhite}${InvDkGray}$KILLMONMODE${CClear}${CGreen} | IP6: ${CWhite}${InvDkGray}$KILLMON6MODE${CClear}${CGreen} | Rules Integrity: ${CWhite}${InvGreen}NOMINAL${CClear}"
      fi
    fi

  fi

  echo -e "${CGreen} __________${CClear}"
  echo -e "${CGreen}/${CRed}Interfaces${CClear}${CGreen}\_______________________________________________________${CClear}"
  echo ""

  # Check for external commandline activity
  lockcheck

  # Check the WAN connectivity to determine if we need to keep looping until WAN connection is re-established
  checkwan Loop

  # Initialize timer to measure how long it takes to check the WAN & VPN interfaces
  VW_ELAPSED_TIME=0
  VW_START_TIME=$(date +%s)

  # Cycle through the WANCheck connection function to display ping/city info
  i=0
  for i in 0 1
    do
      wancheck $i
  done

  echo -e "${CGreen} ------------------------------------------------------------------${CClear}"

  # Check for external commandline activity
  lockcheck

  # Cycle through the CheckVPN connection function for N number of VPN Clients
  i=0
  while [ $i -ne $N ]
    do
      i=$(($i+1))
      checkvpn $i $((state$i))
  done

  # End the timer for the WAN & VPN interfaces
  VW_END_TIME=$(date +%s)
  VW_ELAPSED_TIME=$(( VW_END_TIME - VW_START_TIME ))

  # Determine whether to show all the stats based on user preference
  if [ "$SHOWSTATS" == "1" ]
    then

      echo -e "${CGreen} _________"
      echo -e "${CGreen}/${CRed}VPN Stats${CClear}${CGreen}\________________________________________________________${CClear}"
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
      elif [ $WeVPNSuperRandom -eq 1 ]
        then
          RANDOMMETHOD="WeVPN SuperRandom"
      else
        RANDOMMETHOD="Standard"
    fi

    # Initialize timer to measure how long it takes to grab the VPN server load
    LOAD_ELAPSED_TIME=0

    if [ $NordVPNSuperRandom -eq 1 ] || [ $UseNordVPN -eq 1 ]
      then
        # Get the NordVPN server load - thanks to @JackYaz for letting me borrow his code from VPNMGR to accomplish this! ;)
        LOAD_START_TIME=$(date +%s)
        printf "\r${InvYellow} ${CClear}${CYellow} [Checking NordVPN Server Load]..."

        loadcount=0
        while [ $loadcount -ne 60 ]
          do
            loadcount=$(($loadcount+1))
            #VPNLOAD=$(curl --silent --retry 3 "https://api.nordvpn.com/v1/servers?limit=16384" | jq '.[] | select(.station == "'"$VPNIP"'") | .load') >/dev/null 2>&1
            VPNLOAD="curl --silent --retry 3 https://api.nordvpn.com/v1/servers?limit=16384 | jq '.[] | select(.station == \"$VPNIP\") | .load' 2>&1"
            VPNLOAD="$(eval $VPNLOAD 2>/dev/null)"; if echo $VPNLOAD | grep -qoE '\berror.*\b'; then VPNLOAD=0; printf "${CRed}\r [API Error Occurred... retrying $loadcount/60]           "; sleep 1; fi

            if [ -z $VPNLOAD ]; then break; fi
            if [ $VPNLOAD -gt 0 ]; then break; fi
            sleep 1

            if [ $loadcount -eq 60 ]; then
              echo -e "\n${CRed} Error: Unable to reach NordVPN API! Load reading is not possible.\n${CClear}"
              echo -e "$(date) - VPNMON-R2 ----------> ERROR: Unable to reach NordVPN API! Load reading is not possible." >> $LOGFILE
              break
            fi
        done

        printf "\r"
        LOAD_END_TIME=$(date +%s)
        LOAD_ELAPSED_TIME=$(( LOAD_END_TIME - LOAD_START_TIME ))
    fi

    if [ $SurfSharkSuperRandom -eq 1 ] || [ $UseSurfShark -eq 1 ]
      then
        # Get the SurfShark server load - thanks to @JackYaz for letting me borrow his code from VPNMGR to accomplish this! ;)
        LOAD_START_TIME=$(date +%s)
        printf "\r${InvYellow} ${CClear}${CYellow}  [Checking SurfShark Server Load]..."

        loadcount=0
        while [ $loadcount -ne 60 ]
          do
            loadcount=$(($loadcount+1))
            #VPNLOAD=$(curl --silent --retry 3 "https://api.surfshark.com/v3/server/clusters" | jq --raw-output '.[] | select(.connectionName == "'"$VPNIP"'") | .load') >/dev/null 2>&1
            VPNLOAD="curl --silent --retry 3 https://api.surfshark.com/v3/server/clusters | jq --raw-output '.[] | select(.connectionName == \"$VPNIP\") | .load' >/dev/null 2>&1"
            VPNLOAD="$(eval $VPNLOAD 2>/dev/null)"; if echo $VPNLOAD | grep -qoE '\berror.*\b'; then VPNLOAD=0; printf "${CRed}\r [API Error Occurred... retrying $loadcount/60]           "; sleep 1; fi

            if [ -z $VPNLOAD ]; then break; fi
            if [ $VPNLOAD -gt 0 ]; then break; fi
            sleep 1

            if [ $loadcount -eq 60 ]; then
              echo -e "\n${CRed} Error: Unable to reach SurfShark API! Load reading is not possible.\n${CClear}"
              echo -e "$(date) - VPNMON-R2 ----------> ERROR: Unable to reach SurfShark API! Load reading is not possible." >> $LOGFILE
              break
            fi
        done

        printf "\r"
        LOAD_END_TIME=$(date +%s)
        LOAD_ELAPSED_TIME=$(( LOAD_END_TIME - LOAD_START_TIME ))
    fi

    if [ $PPSuperRandom -eq 1 ] || [ $UsePP -eq 1 ]
      then
        # Get the Perfect Privacy server load - thanks to @JackYaz for letting me borrow his code from VPNMGR to accomplish this! ;)
        LOAD_START_TIME=$(date +%s)
        printf "\r${InvYellow} ${CClear}${CYellow}  [Checking Perfect Privacy Server Load]..."

        loadcount=0
        while [ $loadcount -ne 60 ]
          do
            loadcount=$(($loadcount+1))
            #PPcurl=$(curl --silent --retry 3 "https://www.perfect-privacy.com/api/traffic.json") >/dev/null 2>&1
            PPcurl="curl --silent --retry 3 https://www.perfect-privacy.com/api/traffic.json >/dev/null 2>&1"
            PPcurl="$(eval $PPcurl 2>/dev/null)"; if echo $PPcurl | grep -qoE '\berror.*\b'; then PPcurl=0; printf "${CRed}\r [API Error Occurred... retrying $loadcount/60]           "; sleep 1; fi
            PP_in=$(echo $PPcurl | jq -r '."'"$VPNIP"'" | ."bandwidth_in"') 2>&1
            PP_out=$(echo $PPcurl | jq -r '."'"$VPNIP"'" | ."bandwidth_out"') 2>&1
            PP_max=$(echo $PPcurl | jq -r '."'"$VPNIP"'" | ."bandwidth_max"') 2>&1
            max1=$PP_in
            if [ $PP_out -gt $PP_in ]; then max1=$PP_out; fi
            max2=$PP_max
            if [ $PP_in -gt $PP_max ]; then max2=$PP_in; elif [ $PP_out -gt $PP_max ]; then max2=$PP_out; fi
            VPNLOAD=$(awk -v m1=$max1 -v m2=$max2 'BEGIN{printf "%0.0f\n", 100*m1/m2}') 2>&1

            if [ -z $VPNLOAD ]; then break; fi
            if [ $VPNLOAD -gt 0 ]; then break; fi
            sleep 1

            if [ $loadcount -eq 60 ]; then
              echo -e "\n${CRed} Error: Unable to reach PerfectPrivacy API! Load reading is not possible.\n${CClear}"
              echo -e "$(date) - VPNMON-R2 ----------> ERROR: Unable to reach PerfectPrivacy API! Load reading is not possible." >> $LOGFILE
              break
            fi
        done

        printf "\r"
        LOAD_END_TIME=$(date +%s)
        LOAD_ELAPSED_TIME=$(( LOAD_END_TIME - LOAD_START_TIME ))
    fi

    if [ -z "$VPNLOAD" ]; then VPNLOAD=0; fi # On that rare occasion where it's unable to get the NordVPN/SurfShark/PerfectPrivacy load, assign 0

    # Display some of the NordVPN/SurfShark/PerfectPrivacy specific stats
    if [ $NordVPNSuperRandom -eq 1 ] || [ $UseNordVPN -eq 1 ] || [ $SurfSharkSuperRandom -eq 1 ] || [ $UseSurfShark -eq 1 ] || [ $PPSuperRandom -eq 1 ] || [ $UsePP -eq 1 ]
      then
        echo -e "${InvGreen} ${CClear}${CGreen} Ping Lo:${CWhite}${InvGreen}$PINGLOW${CClear}${CGreen} Hi:${CWhite}${InvRed}$PINGHIGH${CClear}${CGreen} ms | Load: ${CWhite}${InvDkGray} $VPNLOAD% ${CClear}${CGreen} | Cfg: ${CWhite}${InvDkGray}$RANDOMMETHOD${CClear}"

        # Display the high/low ping times, and for non-NordVPN/SurfShark/PerfectPrivacy customers, whether Skynet update is enabled.
        elif [ $UpdateSkynet -eq 0 ]
        then
          echo -e "${InvGreen} ${CClear}${CGreen} Ping Lo:${CWhite}${InvGreen}$PINGLOW${CClear}${CGreen} Hi:${CWhite}${InvRed}$PINGHIGH${CClear}${CGreen} ms | Cfg: ${CWhite}${InvDkGray}$RANDOMMETHOD${CClear}"
        else
          echo -e "${InvGreen} ${CClear}${CGreen} Ping Lo:${CWhite}${InvGreen}$PINGLOW${CClear}${CGreen} Hi:${CWhite}${InvRed}$PINGHIGH${CClear}${CGreen} ms | Skynet: ${CWhite}${InvDkGray}[Y]${CClear}${CGreen} | Cfg: ${CWhite}${InvDkGray}$RANDOMMETHOD${CClear}"
    fi

    # Display some general OpenVPN connection specific Stats
    vpncrypto=$($timeoutcmd$timeoutsec nvram get vpn_client"$CURRCLNT"_crypt)
    vpndigest=$($timeoutcmd$timeoutsec nvram get vpn_client"$CURRCLNT"_digest)
    vpnport=$($timeoutcmd$timeoutsec nvram get vpn_client"$CURRCLNT"_port)
    vpnproto=$($timeoutcmd$timeoutsec nvram get vpn_client"$CURRCLNT"_proto)

    # Display row of stats re: crypto, proto, port and authdigest
    if [ -z "$vpncrypto" ]; then vpncrypto=""; elif [ "$vpncrypto" == "tcp-client" ]; then vpncrypto="tcp"; fi
    echo -e "${InvGreen} ${CClear}${CGreen} Proto: ${CWhite}${InvDkGray}$vpnproto${CClear}${CGreen} | Port: ${CWhite}${InvDkGray}$vpnport${CClear}${CGreen} | Crypto: ${CWhite}${InvDkGray}$vpncrypto${CClear}${CGreen} | AuthDigest: ${CWhite}${InvDkGray}$vpndigest${CClear}"

    # Display row of stats re: method, chances, ping retries + min ping before reset
    if [ $USELOWESTSLOT == "0" ]; then
      echo -e "${InvGreen} ${CClear}${CGreen} Method: ${CWhite}${InvDkGray}Random${CClear}${CGreen} | ${CDkGray}Chances: $PINGCHANCES${CClear}${CGreen} | PING > ${CWhite}${InvDkGray}${TRIES}x${CClear}${CGreen} | Reset > ${CWhite}${InvDkGray}$MINPING${CClear}${CGreen} ms${CClear}"
    elif [ $USELOWESTSLOT == "1" ]; then
      echo -e "${InvGreen} ${CClear}${CGreen} Method: ${CWhite}${InvDkGray}Lowest PING${CClear}${CGreen} | Chances: ${CWhite}${InvDkGray}$PINGCHANCES${CClear}${CGreen} | PING > ${CWhite}${InvDkGray}${TRIES}x${CClear}${CGreen} | Reset > ${CWhite}${InvDkGray}$MINPING${CClear}${CGreen} ms${CClear}"
    elif [ $USELOWESTSLOT == "2" ]; then
      echo -e "${InvGreen} ${CClear}${CGreen} Method: ${CWhite}${InvDkGray}Round Robin${CClear}${CGreen} | ${CDkGray}Chances: $PINGCHANCES${CClear}${CGreen} | PING > ${CWhite}${InvDkGray}${TRIES}x${CClear}${CGreen} | Reset > ${CWhite}${InvDkGray}$MINPING${CClear}${CGreen} ms${CClear}"
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

    # Modify the amount of time for the calculation to be the Interval + VPN Server Load check + VPN/WAN Ping checks + WAN connectivity check
    INTERVALTIMEMOD=$(($INTERVAL + $LOAD_ELAPSED_TIME + $VW_ELAPSED_TIME + $WAN_ELAPSED_TIME))

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
        echo -e "${InvYellow} ${CClear}${CYellow} [Gathering VPN RX and TX Stats]... ${CGreen}| Ttl RX:${CWhite}${InvDkGray}$txgbytes GB${CClear} ${CGreen}TX:${CWhite}${InvDkGray}$rxgbytes GB${CClear}"
      else
        # Display current avg rx/tx rates and total rx/tx bytes for active VPN tunnel.
        echo -e "${InvGreen} ${CClear}${CGreen} Avg RX:${CWhite}${InvDkGray}$txmbrate Mbps${CClear}${CGreen} TX:${CWhite}${InvDkGray}$rxmbrate Mbps${CClear}${CGreen} | Ttl RX:${CWhite}${InvDkGray}$txgbytes GB${CClear} ${CGreen}TX:${CWhite}${InvDkGray}$rxgbytes GB${CClear}"
    fi

    #VPN Traffic Measurement assignment of newest bytes to old counter before timer kicks off again
    oldrxbytes=$newrxbytes
    oldtxbytes=$newtxbytes

  else

    sleep 2

    # Check for external commandline activity
    lockcheck

  fi

    resetcheck  # Check for all major reset scenarios

  # Provide a progressbar to show script activity
  if [ "$SKIPPROGRESS" == "0" ]; then
    echo ""
    i=0
    while [ $i -le $INTERVAL ]
    do
        preparebar 51 "|"
        progressbar $i $INTERVAL
        #sleep 1
        i=$(($i+1))

        lockcheck # check to see if a lockfile is present from a commandline process

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
echo -e "${CClear}"
exit 0

#} #2>&1 | tee $LOG | logger -t $(basename $0)[$$]  # uncomment/comment to enable/disable debug mode
