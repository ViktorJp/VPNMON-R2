#!/bin/sh

#          name: merlin-dns-monitor.sh
#       version: 1.4.2, 26-apr-2022, by eibgrad
#       version: 1.4.3, 07-oct-2023, by Viktor Jaep
#       purpose: monitor what dns servers are active and where routed
#       type(s): n/a (will autostart immediately upon download)
#          href: https://tinyurl.com/2p8fn7xu
#  installation:
#    1. ssh to router and copy/paste the following command:
#         curl -kLs bit.ly/merlin-installer|tr -d '\r'|sh -s AGNF8cC8
#    2. modify script w/ your preferred options using nano editor:
#         nano /tmp/merlin-dns-monitor.sh
#
#  note: script is NOT persistent across a reboot, since it's stored in /tmp
#        upon download and immediately executed

SCRIPTS_DIR='/tmp'
SCRIPT="$SCRIPTS_DIR/merlin-dns-monitor.sh"

mkdir -p $SCRIPTS_DIR

# ------------------------------ BEGIN OPTIONS ------------------------------- #

# how often (in secs) to update display (min 3, max 30)
INTERVAL=6

# uncomment/comment to enable/disable logging of Do53 connections over WAN
#LOGGING=

# ------------------------------- END OPTIONS -------------------------------- #

# ---------------------- DO NOT CHANGE BELOW THIS LINE ----------------------- #

cat << 'EOF' > $SCRIPT
#!/bin/sh

BNAME="$(basename $0 .sh)"

WAN_CHECK_DOMAIN="$(nvram get dns_probe_host)"
HOSTS_FILE='/etc/hosts'

# display color attributes
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'

# display monochrome attributes
NORMAL='\033[0m'
BOLD='\033[1m'
ITALIC='\033[3m'
UNDERLINE='\033[4m'

# display command menu attributes (color and monochrome)
CMENU='\033[7;36m' # reverse + cyan
MMENU='\033[7m'    # reverse only

# display reset attribute
RS='\033[0m'

# display update interval boundaries
MIN_INTERVAL=3
MAX_INTERVAL=30

# work files
HEAD="/tmp/tmp.$$.$BNAME.head"
BODY="/tmp/tmp.$$.$BNAME.body"
DATA="/tmp/tmp.$$.$BNAME.data"
LOG="/tmp/tmp.$$.$BNAME.log"; > $LOG

# function max_val( val1 val2 )
max_val() { echo $(($1 < $2 ? $2 : $1)); }

# function min_val( val1 val2 )
min_val() { echo $(($1 > $2 ? $2 : $1)); }

# function wan_check_enabled()
wan_check_enabled() {
    ! grep -q " $WAN_CHECK_DOMAIN # $BNAME$" "$HOSTS_FILE"
}

# function toggle_wan_check()
toggle_wan_check() {
    [ "$WAN_CHECK_DOMAIN" ] || return 1

    if wan_check_enabled; then
        local ip="$(nslookup $WAN_CHECK_DOMAIN | \
            awk '/^Name:/,0 {if (/^Addr[^:]*: [0-9]{1,3}\./) print $3}')"

        if [ "$ip" ]; then
            echo "$ip $WAN_CHECK_DOMAIN # $BNAME" >> $HOSTS_FILE
        else
            return 1
        fi
    else
        sed -i "/ $WAN_CHECK_DOMAIN # $BNAME$/d" $HOSTS_FILE
    fi

    return 0
}

# function format_header()
format_header() {
    local prof ip adns rgw sw_vpn_printed

    # publish wan/lan ip information
    if echo "$(nvram get wans_dualwan)" | grep -q 'none'; then
        printf 'WAN/LAN IP: %s/%s\n\n' \
            $wan0_ip_4disp $(nvram get lan_ipaddr)
    else
        printf 'WAN1/WAN2/LAN IP: %s/%s/%s\n\n' \
            $wan0_ip_4disp $wan1_ip_4disp $(nvram get lan_ipaddr)
    fi

    # publish wan/dhcp dns information
    printf " WAN DNS: $(echo $(awk '/^nameserver /{print $2}' \
        /etc/resolv.conf) | sed -r 's/ /, /g')\n"
    printf "DHCP DNS: $(echo $(awk -F'[= ]' '/^server=/{print $2}' \
        /tmp/resolv.dnsmasq) | sed -r 's/ /, /g')\n"

    # publish dot (stubby) dns information
    if [ "$(nvram get dnspriv_enable)" == '1' ]; then
        case $(nvram get dnspriv_profile) in
            '0') prof='Opportunistic';;
            '1') prof='Strict';;
        esac

        printf " DoT DNS: $(echo $(awk '/address_data/{print $3}' \
            /etc/stubby/stubby.yml) | sed -r 's/ /, /g') ($prof)\n"
    fi

    # publish openvpn information
    for i in 1 2 3 4 5; do
        ip="$(ifconfig tun1${i} 2>/dev/null | \
            awk '/inet addr/{split ($2,A,":"); print A[2]}')"

        [ "$ip" ] || continue

        case $(nvram get vpn_client${i}_adns) in
            '0') adns='Disabled';;
            '1') adns='Relaxed';;
            '2') adns='Strict';;
            '3') adns='Exclusive';;
        esac

        case $(nvram get vpn_client${i}_rgw) in
            '0') rgw='No';;
            '1') rgw='Yes';;
            '2') rgw='VPN Director';;
        esac

        printf "\nOVPN${i} IP/DNS Config/Redirect Internet: $ip/$adns/$rgw"

        sw_vpn_printed=
    done

    [ ${sw_vpn_printed+x} ] && printf '\n'

    printf "\nActive DNS (Do53/DoT) UDP/TCP Connections\n"
    printf "  ${sev_lvl_2}Do53 (plaintext) routed over the WAN${RS}\n"
    printf "  ${sev_lvl_1}DoT (ciphertext) routed over the WAN${RS}\n"
    printf "  ${sev_lvl_0}Do53/DoT NOT routed over the WAN "
    printf "(loopback, local, or VPN)${RS}\n"
    echo ' '
}

# function format_body()
format_body() {
    _print_with_dupe_count() {
        local dupe_count=0
        local prev_line="$(head -n1 $DATA)"

        # print line w/ duplicate line-count indicator
        __print_line() {
            if [ $dupe_count -gt 1 ]; then
                printf '%-93s %s\n' "$prev_line" "($dupe_count)"
            else
                echo "$prev_line"
            fi
        }

        # find and print unique lines while counting duplicates
        while read line; do
            if [ "$line" == "$prev_line" ]; then
                let dupe_count++
            else
                __print_line; prev_line="$line"; dupe_count=1
            fi
        done < $DATA

        [ "$prev_line" ] && __print_line
    }

    # publish Do53 over udp (replied and sorted)
    grep '^ipv4 .* udp .* dport=53 ' /proc/net/nf_conntrack | \
        awk '$0 !~ /UNREPLIED/{printf "%s %-19s %-19s %-9s %-19s %s\n",
                $3, $6, $7, $9, $10, $11}' | \
            sort > $DATA

    # remove duplicates; optionally include dupe count
    [ ${sw_dupes+x} ] && _print_with_dupe_count || uniq $DATA

    # publish Do53/DoT over tcp (replied and sorted)
    grep -E '^ipv4 .* tcp .* dport=(53|853) ' /proc/net/nf_conntrack | \
        awk '/ASSURED/{printf "%s %-19s %-19s %-9s %-19s %s\n",
                $3, $7, $8, $10, $11, $12}' | \
            sort > $DATA

    # remove duplicates; optionally include dupe count
    [ ${sw_dupes+x} ] && _print_with_dupe_count || uniq $DATA
}

# function pause_display()
pause_display() {
    read -sp "$(echo -e ${menu}"\nPress [Enter] key to continue..."${RS})" \
        < "$(tty 0>&2)"
}

# function exit_0()
exit_0() {
    # publish name of log file
    [ -s $LOG ] && echo -e "\nlog file: $LOG" || rm -f $LOG

    # reenable wan check
    wan_check_enabled || toggle_wan_check

    # cleanup work files
    rm -f $HEAD $BODY $DATA

    # publish information on restarting
    echo -e "\nRun $0 to restart."

    exit 0
}

# trap on unexpected exit (e.g., crtl-c)
trap 'exit_0' SIGHUP SIGINT SIGTERM

# enable header
sw_head=

# set initial update interval
interval=$(max_val $MIN_INTERVAL $(min_val $INTERVAL $MAX_INTERVAL))

# set initial logging state
[ "$LOGGING" ] && sw_log=

# begin display loop
while :; do

# establish wan ip(s) for analysis and display
wan0_ip="$(nvram get wan0_ipaddr)"
wan0_ip_4disp="$([ ${sw_wanip+x} ] && echo 'x.x.x.x' || echo $wan0_ip)"
wan1_ip="$(nvram get wan1_ipaddr)"
wan1_ip_4disp="$([ ${sw_wanip+x} ] && echo 'y.y.y.y' || echo $wan1_ip)"

# set display attributes (color (default) or monochrome)
if [ ! ${sw_mono+x} ]; then
    sev_lvl_2="$RED"
    sev_lvl_1="$YELLOW"
    sev_lvl_0="$GREEN"
    menu="$CMENU"
else
    sev_lvl_2="$BOLD"
    sev_lvl_1="$UNDERLINE"
    sev_lvl_0="$NORMAL"
    menu="$MMENU"
fi

# format command menu
wan_check_enabled  &&    _wan='disable' ||    _wan='enable'
[ ${sw_head+x}   ] &&   _head='hide'    ||   _head='show'
[ ${sw_wanip+x}  ] &&  _wanip='show'    ||  _wanip='hide'
[ ${sw_dupes+x}  ] &&  _dupes='hide'    ||  _dupes='show'
[ ${sw_mono+x}   ] &&   _mono='disable' ||   _mono='enable'
[ ${sw_scroll+x} ] && _scroll='disable' || _scroll='enable'
[ ${sw_log+x}    ] &&    _log='disable' ||    _log='enable'

# format header
[ ${sw_head+x} ] && format_header > $HEAD

# format body
format_body > $BODY

# clear display
clear

# start of "more-able" output
{
# display command menu
if [ ! ${sw_next+x} ]; then
    printf "${menu}%s | %s | %s | %s | %s | %s%s${RS}\n" \
        "[n]ext menu" \
        "$_wan [w]an check" \
        "$_head [h]eader" \
        "[+/-] interval ($interval)" \
        "[p]ause" \
        "[e]xit" \
        ''
else
    printf "${menu}%s | %s | %s | %s | %s | %s%s${RS}\n" \
        "[n]ext menu" \
        "$_wanip wan [i]p" \
        "$_dupes [d]upes" \
        "$_mono [m]ono" \
        "$_scroll [s]croll" \
        "$_log [l]og" \
        ''
fi

# display header
[ ${sw_head+x} ] && cat $HEAD

# display column headings
printf '%43s'   'v-------------- sender ---------------v'
printf '%50s\n' 'v------------- recipient -------------v'

# display body/data (include severity level 0|1|2)
while read line; do
    # hide wan/public ip(s) when requested
    if [ ${sw_wanip+x} ]; then
        line_4disp="$(echo "$line" | \
            sed -r "s/(src|dst)=$wan0_ip($)/\1=$wan0_ip_4disp/g; \
                    s/(src|dst)=$wan0_ip( +)/\1=$wan0_ip_4disp         /g; \
                    s/(src|dst)=$wan1_ip($)/\1=$wan1_ip_4disp/g; \
                    s/(src|dst)=$wan1_ip( +)/\1=$wan1_ip_4disp         /g")"
    else
        line_4disp="$line"
    fi

    if echo $line | grep 'dport=53 ' | \
            grep -qE "(src|dst)=($wan0_ip|$wan1_ip)( |$)"; then
        # Do53 connection routed over WAN
        printf "${sev_lvl_2}$line_4disp${RS}\n"

        # log the connection (optional)
        if [ ${sw_log+x} ]; then
            # remove dupe count (if present)
            line="$(echo "$line" | sed 's/\s*([0-9]*)$//')"
            # ignore duplicates
            grep -qxF "$line" $LOG || echo "$line" >> $LOG
        fi
    elif echo $line | grep 'dport=853 ' | \
            grep -qE "(src|dst)=($wan0_ip|$wan1_ip)( |$)"; then
        # DoT connection routed over WAN
        printf "${sev_lvl_1}$line_4disp${RS}\n"
    else
        # Do53/DoT connection NOT routed over WAN
        printf "${sev_lvl_0}$line_4disp${RS}\n"
    fi
done < $BODY

[ -s $BODY ] || echo '<no-data>'

# end of "more-able" output
} 2>&1 | $([ ${sw_scroll+x} ] && echo 'tee' || echo 'more')

# update display at regular interval (capture any user input)
key_press=''; read -rsn1 -t $interval key_press < "$(tty 0>&2)"

# handle key-press (optional)
if [ $key_press ]; then
    case $key_press in
        # common/shared menu option(s)
        'n') [ ${sw_next+x}   ] && unset sw_next   || sw_next=;;
        # primary menu options
        'w') toggle_wan_check;;
        'h') [ ${sw_head+x}   ] && unset sw_head   || sw_head=;;
        '+') interval=$(min_val $((interval+3)) $MAX_INTERVAL);;
        '-') interval=$(max_val $((interval-3)) $MIN_INTERVAL);;
        'p') pause_display;;
        'e') exit_0;;
        # secondary menu options
        'i') [ ${sw_wanip+x}  ] && unset sw_wanip  || sw_wanip=;;
        'd') [ ${sw_dupes+x}  ] && unset sw_dupes  || sw_dupes=;;
        'm') [ ${sw_mono+x}   ] && unset sw_mono   || sw_mono=;;
        's') [ ${sw_scroll+x} ] && unset sw_scroll || sw_scroll=;;
        'l') [ ${sw_log+x}    ] && unset sw_log    || sw_log=;;
    esac
fi

done # end of 'while :; do'
EOF
[ ${LOGGING+x} ] && sed -ri 's/\$LOGGING/LOGGING/g' $SCRIPT
sed -i "s:\$INTERVAL:$INTERVAL:g" $SCRIPT
chmod +x $SCRIPT

# begin execution
$SCRIPT
