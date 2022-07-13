#!/bin/sh

#######################################################
##                                                   ##
##   __   __ _ __   _ __   _ __ ___    __ _  _ __    ##
##   \ \ / /| '_ \ | '_ \ | '_ ` _ \  / _` || '__|   ##
##    \ V / | |_) || | | || | | | | || (_| || |      ##
##     \_/  | .__/ |_| |_||_| |_| |_| \__, ||_|      ##
##          | |                        __/ |         ##
##          |_|                       |___/          ##
##                                                   ##
##         https://github.com/jackyaz/vpnmgr         ##
##                forked from h0me5k1n               ##
#######################################################

##########         Shellcheck directives     ##########
# shellcheck disable=SC2016
# shellcheck disable=SC2018
# shellcheck disable=SC2019
# shellcheck disable=SC2039
# shellcheck disable=SC2059
# shellcheck disable=SC2140
# shellcheck disable=SC2155
# shellcheck disable=SC3003
#######################################################

### Start of script variables ###
readonly SCRIPT_NAME="vpnmgr"
readonly SCRIPT_VERSION="v2.3.1"
SCRIPT_BRANCH="master"
SCRIPT_REPO="https://raw.githubusercontent.com/jackyaz/$SCRIPT_NAME/$SCRIPT_BRANCH"
readonly SCRIPT_DIR="/jffs/addons/$SCRIPT_NAME.d"
readonly SCRIPT_CONF="$SCRIPT_DIR/config"
readonly OVPN_ARCHIVE_DIR="$SCRIPT_DIR/ovpn"
readonly SCRIPT_WEBPAGE_DIR="$(readlink /www/user)"
readonly SCRIPT_WEB_DIR="$SCRIPT_WEBPAGE_DIR/$SCRIPT_NAME"
readonly SHARED_DIR="/jffs/addons/shared-jy"
readonly SHARED_REPO="https://raw.githubusercontent.com/jackyaz/shared-jy/master"
readonly SHARED_WEB_DIR="$SCRIPT_WEBPAGE_DIR/shared-jy"
[ -z "$(nvram get odmpid)" ] && ROUTER_MODEL=$(nvram get productid) || ROUTER_MODEL=$(nvram get odmpid)
GLOBAL_VPN_NO=""
GLOBAL_VPN_PROVIDER=""
GLOBAL_VPN_PROT=""
GLOBAL_VPN_TYPE=""
GLOBAL_CRU_DAYNUMBERS=""
GLOBAL_CRU_HOURS=""
GLOBAL_CRU_MINS=""
GLOBAL_COUNTRY_NAME=""
GLOBAL_COUNTRY_ID=""
GLOBAL_CITY_NAME=""
GLOBAL_CTIY_ID=""
### End of script variables ###

### Start of output format variables ###
readonly CRIT="\\e[41m"
readonly ERR="\\e[31m"
readonly WARN="\\e[33m"
readonly PASS="\\e[32m"
readonly BOLD="\\e[1m"
readonly SETTING="${BOLD}\\e[36m"
readonly CLEARFORMAT="\\e[0m"
### End of output format variables ###

# $1 = print to syslog, $2 = message to print, $3 = log level
Print_Output(){
	if [ "$1" = "true" ]; then
		logger -t "$SCRIPT_NAME" "$2"
	fi
	printf "${BOLD}${3}%s${CLEARFORMAT}\\n\\n" "$2"
}

Firmware_Version_Check(){
	if nvram get rc_support | grep -qF "am_addons"; then
		return 0
	else
		return 1
	fi
}

Firmware_Number_Check(){
	echo "$1" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'
}

### Code for these functions inspired by https://github.com/Adamm00 - credit to @Adamm ###
Check_Lock(){
	if [ -f "/tmp/$SCRIPT_NAME.lock" ]; then
		ageoflock=$(($(date +%s) - $(date +%s -r /tmp/$SCRIPT_NAME.lock)))
		if [ "$ageoflock" -gt 600 ]; then
			Print_Output true "Stale lock file found (>600 seconds old) - purging lock" "$ERR"
			kill "$(sed -n '1p' /tmp/$SCRIPT_NAME.lock)" >/dev/null 2>&1
			Clear_Lock
			echo "$$" > "/tmp/$SCRIPT_NAME.lock"
			return 0
		else
			Print_Output true "Lock file found (age: $ageoflock seconds) - stopping to prevent duplicate runs" "$ERR"
			if [ -z "$1" ]; then
				exit 1
			else
				if [ "$1" = "webui" ]; then
					echo 'var vpnmgrstatus = "LOCKED";' > /tmp/detect_vpnmgr.js
					exit 1
				fi
				return 1
			fi
		fi
	else
		echo "$$" > "/tmp/$SCRIPT_NAME.lock"
		return 0
	fi
}

Clear_Lock(){
	rm -f "/tmp/$SCRIPT_NAME.lock" 2>/dev/null
	return 0
}

###################################

Set_Version_Custom_Settings(){
	SETTINGSFILE="/jffs/addons/custom_settings.txt"
	case "$1" in
		local)
			if [ -f "$SETTINGSFILE" ]; then
				if [ "$(grep -c "vpnmgr_version_local" $SETTINGSFILE)" -gt 0 ]; then
					if [ "$2" != "$(grep "vpnmgr_version_local" /jffs/addons/custom_settings.txt | cut -f2 -d' ')" ]; then
						sed -i "s/vpnmgr_version_local.*/vpnmgr_version_local $2/" "$SETTINGSFILE"
					fi
				else
					echo "vpnmgr_version_local $2" >> "$SETTINGSFILE"
				fi
			else
				echo "vpnmgr_version_local $2" >> "$SETTINGSFILE"
			fi
		;;
		server)
			if [ -f "$SETTINGSFILE" ]; then
				if [ "$(grep -c "vpnmgr_version_server" $SETTINGSFILE)" -gt 0 ]; then
					if [ "$2" != "$(grep "vpnmgr_version_server" /jffs/addons/custom_settings.txt | cut -f2 -d' ')" ]; then
						sed -i "s/vpnmgr_version_server.*/vpnmgr_version_server $2/" "$SETTINGSFILE"
					fi
				else
					echo "vpnmgr_version_server $2" >> "$SETTINGSFILE"
				fi
			else
				echo "vpnmgr_version_server $2" >> "$SETTINGSFILE"
			fi
		;;
	esac
}

Update_Check(){
	echo 'var updatestatus = "InProgress";' > "$SCRIPT_WEB_DIR/detect_update.js"
	doupdate="false"
	localver=$(grep "SCRIPT_VERSION=" "/jffs/scripts/$SCRIPT_NAME" | grep -m1 -oE 'v[0-9]{1,2}([.][0-9]{1,2})([.][0-9]{1,2})')
	/usr/sbin/curl -fsL --retry 3 "$SCRIPT_REPO/$SCRIPT_NAME.sh" | grep -qF "jackyaz" || { Print_Output true "404 error detected - stopping update" "$ERR"; return 1; }
	serverver=$(/usr/sbin/curl -fsL --retry 3 "$SCRIPT_REPO/$SCRIPT_NAME.sh" | grep "SCRIPT_VERSION=" | grep -m1 -oE 'v[0-9]{1,2}([.][0-9]{1,2})([.][0-9]{1,2})')
	if [ "$localver" != "$serverver" ]; then
		doupdate="version"
		Set_Version_Custom_Settings server "$serverver"
		echo 'var updatestatus = "'"$serverver"'";'  > "$SCRIPT_WEB_DIR/detect_update.js"
	else
		localmd5="$(md5sum "/jffs/scripts/$SCRIPT_NAME" | awk '{print $1}')"
		remotemd5="$(curl -fsL --retry 3 "$SCRIPT_REPO/$SCRIPT_NAME.sh" | md5sum | awk '{print $1}')"
		if [ "$localmd5" != "$remotemd5" ]; then
			doupdate="md5"
			Set_Version_Custom_Settings server "$serverver-hotfix"
			echo 'var updatestatus = "'"$serverver-hotfix"'";'  > "$SCRIPT_WEB_DIR/detect_update.js"
		fi
	fi
	if [ "$doupdate" = "false" ]; then
		echo 'var updatestatus = "None";'  > "$SCRIPT_WEB_DIR/detect_update.js"
	fi
	echo "$doupdate,$localver,$serverver"
}

Update_Version(){
	if [ -z "$1" ]; then
		updatecheckresult="$(Update_Check)"
		isupdate="$(echo "$updatecheckresult" | cut -f1 -d',')"
		localver="$(echo "$updatecheckresult" | cut -f2 -d',')"
		serverver="$(echo "$updatecheckresult" | cut -f3 -d',')"
		
		if [ "$isupdate" = "version" ]; then
			Print_Output true "New version of $SCRIPT_NAME available - $serverver" "$PASS"
		elif [ "$isupdate" = "md5" ]; then
			Print_Output true "MD5 hash of $SCRIPT_NAME does not match - hotfix available $serverver" "$PASS"
		fi
		
		if [ "$isupdate" != "false" ]; then
			printf "\\n${BOLD}Do you want to continue with the update? (y/n)${CLEARFORMAT}  "
			read -r confirm
			case "$confirm" in
				y|Y)
					Update_File shared-jy.tar.gz
					Update_File vpnmgr_www.asp
					printf "\\n"
					/usr/sbin/curl -fsL --retry 3 "$SCRIPT_REPO/$SCRIPT_NAME.sh" -o "/jffs/scripts/$SCRIPT_NAME" && Print_Output true "$SCRIPT_NAME successfully updated"
					chmod 0755 "/jffs/scripts/$SCRIPT_NAME"
					Set_Version_Custom_Settings local "$serverver"
					Set_Version_Custom_Settings server "$serverver"
					Clear_Lock
					PressEnter
					exec "$0"
					exit 0
				;;
				*)
					printf "\\n"
					Clear_Lock
					return 1
				;;
			esac
			exit 0
		else
			Print_Output true "No updates available - latest is $localver" "$WARN"
			Clear_Lock
		fi
	fi
	
	if [ "$1" = "force" ]; then
		serverver=$(/usr/sbin/curl -fsL --retry 3 "$SCRIPT_REPO/$SCRIPT_NAME.sh" | grep "SCRIPT_VERSION=" | grep -m1 -oE 'v[0-9]{1,2}([.][0-9]{1,2})([.][0-9]{1,2})')
		Print_Output true "Downloading latest version ($serverver) of $SCRIPT_NAME" "$PASS"
		Update_File shared-jy.tar.gz
		Update_File vpnmgr_www.asp
		/usr/sbin/curl -fsL --retry 3 "$SCRIPT_REPO/$SCRIPT_NAME.sh" -o "/jffs/scripts/$SCRIPT_NAME" && Print_Output true "$SCRIPT_NAME successfully updated"
		chmod 0755 "/jffs/scripts/$SCRIPT_NAME_LOWER"
		Set_Version_Custom_Settings local "$serverver"
		Set_Version_Custom_Settings server "$serverver"
		Clear_Lock
		if [ -z "$2" ]; then
			PressEnter
			exec "$0"
		elif [ "$2" = "unattended" ]; then
			exec "$0" postupdate
		fi
		exit 0
	fi
}

Update_File(){
	if [ "$1" = "shared-jy.tar.gz" ]; then
		if [ ! -f "$SHARED_DIR/$1.md5" ]; then
			Download_File "$SHARED_REPO/$1" "$SHARED_DIR/$1"
			Download_File "$SHARED_REPO/$1.md5" "$SHARED_DIR/$1.md5"
			tar -xzf "$SHARED_DIR/$1" -C "$SHARED_DIR"
			rm -f "$SHARED_DIR/$1"
			Print_Output true "New version of $1 downloaded" "$PASS"
		else
			localmd5="$(cat "$SHARED_DIR/$1.md5")"
			remotemd5="$(curl -fsL --retry 3 "$SHARED_REPO/$1.md5")"
			if [ "$localmd5" != "$remotemd5" ]; then
				Download_File "$SHARED_REPO/$1" "$SHARED_DIR/$1"
				Download_File "$SHARED_REPO/$1.md5" "$SHARED_DIR/$1.md5"
				tar -xzf "$SHARED_DIR/$1" -C "$SHARED_DIR"
				rm -f "$SHARED_DIR/$1"
				Print_Output true "New version of $1 downloaded" "$PASS"
			fi
		fi
	elif [ "$1" = "vpnmgr_www.asp" ]; then
		tmpfile="/tmp/$1"
		Download_File "$SCRIPT_REPO/$1" "$tmpfile"
		if ! diff -q "$tmpfile" "$SCRIPT_DIR/$1" >/dev/null 2>&1; then
			if [ -f "$SCRIPT_DIR/$1" ]; then
				Get_WebUI_Page "$SCRIPT_DIR/$1"
				sed -i "\\~$MyPage~d" /tmp/menuTree.js
				rm -f "$SCRIPT_WEBPAGE_DIR/$MyPage" 2>/dev/null
			fi
			Download_File "$SCRIPT_REPO/$1" "$SCRIPT_DIR/$1"
			Print_Output true "New version of $1 downloaded" "$PASS"
			Mount_WebUI
		fi
		rm -f "$tmpfile"
	else
		return 1
	fi
}

Auto_Startup(){
	case $1 in
		create)
			if [ -f /jffs/scripts/services-start ]; then
				STARTUPLINECOUNT=$(grep -c '# '"${SCRIPT_NAME}_startup" /jffs/scripts/services-start)
				
				if [ "$STARTUPLINECOUNT" -gt 0 ]; then
					sed -i -e '/# '"${SCRIPT_NAME}_startup"'/d' /jffs/scripts/services-start
				fi
			fi
			if [ -f /jffs/scripts/post-mount ]; then
				STARTUPLINECOUNT=$(grep -c '# '"${SCRIPT_NAME}_startup" /jffs/scripts/post-mount)
				STARTUPLINECOUNTEX=$(grep -cx "/jffs/scripts/$SCRIPT_NAME startup"' "$@" & # '"$SCRIPT_NAME" /jffs/scripts/post-mount)
				
				if [ "$STARTUPLINECOUNT" -gt 1 ] || { [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ "$STARTUPLINECOUNT" -gt 0 ]; }; then
					sed -i -e '/# '"${SCRIPT_NAME}_startup"'/d' /jffs/scripts/post-mount
				fi
				
				if [ "$STARTUPLINECOUNTEX" -eq 0 ]; then
					echo "/jffs/scripts/$SCRIPT_NAME startup"' "$@" & # '"${SCRIPT_NAME}_startup" >> /jffs/scripts/post-mount
				fi
			else
				echo "#!/bin/sh" > /jffs/scripts/post-mount
				echo "" >> /jffs/scripts/post-mount
				echo "/jffs/scripts/$SCRIPT_NAME startup"' "$@" & # '"${SCRIPT_NAME}_startup" >> /jffs/scripts/post-mount
				chmod 0755 /jffs/scripts/post-mount
			fi
		;;
		delete)
			if [ -f /jffs/scripts/services-start ]; then
				STARTUPLINECOUNT=$(grep -c '# '"${SCRIPT_NAME}_startup" /jffs/scripts/services-start)
				
				if [ "$STARTUPLINECOUNT" -gt 0 ]; then
					sed -i -e '/# '"${SCRIPT_NAME}_startup"'/d' /jffs/scripts/services-start
				fi
			fi
			if [ -f /jffs/scripts/post-mount ]; then
				STARTUPLINECOUNT=$(grep -c '# '"${SCRIPT_NAME}_startup" /jffs/scripts/post-mount)
				
				if [ "$STARTUPLINECOUNT" -gt 0 ]; then
					sed -i -e '/# '"${SCRIPT_NAME}_startup"'/d' /jffs/scripts/post-mount
				fi
			fi
		;;
	esac
}

Auto_ServiceEvent(){
	case $1 in
		create)
			if [ -f /jffs/scripts/service-event ]; then
				STARTUPLINECOUNT=$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/service-event)
				STARTUPLINECOUNTEX=$(grep -cx 'if echo "$2" | /bin/grep -q "'"$SCRIPT_NAME"'"; then { /jffs/scripts/'"$SCRIPT_NAME"' service_event "$@" & }; fi # '"$SCRIPT_NAME" /jffs/scripts/service-event)
				
				if [ "$STARTUPLINECOUNT" -gt 1 ] || { [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ "$STARTUPLINECOUNT" -gt 0 ]; }; then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/service-event
				fi
				
				if [ "$STARTUPLINECOUNTEX" -eq 0 ]; then
					echo 'if echo "$2" | /bin/grep -q "'"$SCRIPT_NAME"'"; then { /jffs/scripts/'"$SCRIPT_NAME"' service_event "$@" & }; fi # '"$SCRIPT_NAME" >> /jffs/scripts/service-event
				fi
			else
				echo "#!/bin/sh" > /jffs/scripts/service-event
				echo "" >> /jffs/scripts/service-event
				echo 'if echo "$2" | /bin/grep -q "'"$SCRIPT_NAME"'"; then { /jffs/scripts/'"$SCRIPT_NAME"' service_event "$@" & }; fi # '"$SCRIPT_NAME" >> /jffs/scripts/service-event
				chmod 0755 /jffs/scripts/service-event
			fi
		;;
		delete)
			if [ -f /jffs/scripts/service-event ]; then
				STARTUPLINECOUNT=$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/service-event)
				
				if [ "$STARTUPLINECOUNT" -gt 0 ]; then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/service-event
				fi
			fi
		;;
	esac
}

Auto_Cron(){
	case $1 in
		create)
			STARTUPLINECOUNT=$(cru l | grep -c "${SCRIPT_NAME}_countrydata")
			if [ "$STARTUPLINECOUNT" -gt 0 ]; then
				cru d "${SCRIPT_NAME}_countrydata"
			fi
		
			STARTUPLINECOUNT=$(cru l | grep -c "${SCRIPT_NAME}_cacheddata")
			if [ "$STARTUPLINECOUNT" -eq 0 ]; then
				cru a "${SCRIPT_NAME}_cacheddata" "0 0 * * * /jffs/scripts/$SCRIPT_NAME refreshcacheddata"
			fi
		;;
		delete)
			STARTUPLINECOUNT=$(cru l | grep -c "${SCRIPT_NAME}_cacheddata")
			if [ "$STARTUPLINECOUNT" -gt 0 ]; then
				cru d "${SCRIPT_NAME}_cacheddata"
			fi
		;;
	esac
}

Download_File(){
	/usr/sbin/curl -fsL --retry 3 "$1" -o "$2"
}

Get_WebUI_Page(){
	MyPage="none"
	for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
		page="/www/user/user$i.asp"
		if [ -f "$page" ] && [ "$(md5sum < "$1")" = "$(md5sum < "$page")" ]; then
			MyPage="user$i.asp"
			return
		elif [ "$MyPage" = "none" ] && [ ! -f "$page" ]; then
			MyPage="user$i.asp"
		fi
	done
}

### function based on @dave14305's FlexQoS webconfigpage function ###
Get_WebUI_URL(){
	urlpage=""
	urlproto=""
	urldomain=""
	urlport=""

	urlpage="$(sed -nE "/$SCRIPT_NAME/ s/.*url\: \"(user[0-9]+\.asp)\".*/\1/p" /tmp/menuTree.js)"
	if [ "$(nvram get http_enable)" -eq 1 ]; then
		urlproto="https"
	else
		urlproto="http"
	fi
	if [ -n "$(nvram get lan_domain)" ]; then
		urldomain="$(nvram get lan_hostname).$(nvram get lan_domain)"
	else
		urldomain="$(nvram get lan_ipaddr)"
	fi
	if [ "$(nvram get ${urlproto}_lanport)" -eq 80 ] || [ "$(nvram get ${urlproto}_lanport)" -eq 443 ]; then
		urlport=""
	else
		urlport=":$(nvram get ${urlproto}_lanport)"
	fi

	if echo "$urlpage" | grep -qE "user[0-9]+\.asp"; then
		echo "${urlproto}://${urldomain}${urlport}/${urlpage}" | tr "A-Z" "a-z"
	else
		echo "WebUI page not found"
	fi
}
### ###

### locking mechanism code credit to Martineau (@MartineauUK) ###
Mount_WebUI(){
	Print_Output true "Mounting WebUI tab for $SCRIPT_NAME" "$PASS"
	LOCKFILE=/tmp/addonwebui.lock
	FD=386
	eval exec "$FD>$LOCKFILE"
	flock -x "$FD"
	Get_WebUI_Page "$SCRIPT_DIR/vpnmgr_www.asp"
	if [ "$MyPage" = "none" ]; then
		Print_Output true "Unable to mount $SCRIPT_NAME WebUI page, exiting" "$CRIT"
		flock -u "$FD"
		return 1
	fi
	cp -f "$SCRIPT_DIR/vpnmgr_www.asp" "$SCRIPT_WEBPAGE_DIR/$MyPage"
	echo "$SCRIPT_NAME" > "$SCRIPT_WEBPAGE_DIR/$(echo $MyPage | cut -f1 -d'.').title"
	
	if [ "$(uname -o)" = "ASUSWRT-Merlin" ]; then
		if [ ! -f "/tmp/menuTree.js" ]; then
			cp -f "/www/require/modules/menuTree.js" "/tmp/"
		fi
		
		sed -i "\\~$MyPage~d" /tmp/menuTree.js
		sed -i "/url: \"Advanced_OpenVPNClient_Content.asp\", tabName:/a {url: \"$MyPage\", tabName: \"$SCRIPT_NAME\"}," /tmp/menuTree.js
		
		umount /www/require/modules/menuTree.js 2>/dev/null
		mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
	fi
	flock -u "$FD"
	Print_Output true "Mounted $SCRIPT_NAME WebUI page as $MyPage" "$PASS"
}

Validate_Number(){
	if [ "$1" -eq "$1" ] 2>/dev/null; then
		return 0
	else
		return 1
	fi
}

Conf_FromSettings(){
	SETTINGSFILE="/jffs/addons/custom_settings.txt"
	TMPFILE="/tmp/vpnmgr_settings.txt"
	if [ -f "$SETTINGSFILE" ]; then
		if [ "$(grep "vpnmgr_" $SETTINGSFILE | grep -v "version" -c)" -gt 0 ]; then
			Print_Output true "Updated settings from WebUI found, merging into $SCRIPT_CONF" "$PASS"
			cp -a "$SCRIPT_CONF" "$SCRIPT_CONF.bak"
			grep "vpnmgr_" "$SETTINGSFILE" | grep -v "version" > "$TMPFILE"
			sed -i "s/vpnmgr_//g;s/ /=/g" "$TMPFILE"
			while IFS='' read -r line || [ -n "$line" ]; do
				SETTINGNAME="$(echo "$line" | cut -f1 -d'=')"
				SETTINGVALUE="$(echo "$line" | cut -f2- -d'=' | sed "s/=/ /g")"
				SETTINGVPNNO="$(echo "$SETTINGNAME" | cut -f1 -d'_' | sed 's/vpn//g')"
				if echo "$SETTINGNAME" | grep -q "usn"; then
					nvram set vpn_client"$SETTINGVPNNO"_username="$SETTINGVALUE"
				elif echo "$SETTINGNAME" | grep -q "pwd"; then
					nvram set vpn_client"$SETTINGVPNNO"_password="$SETTINGVALUE"
				else
					sed -i "s~$SETTINGNAME=.*~$SETTINGNAME=$SETTINGVALUE~" "$SCRIPT_CONF"
				fi
			done < "$TMPFILE"
			grep 'vpnmgr_version' "$SETTINGSFILE" > "$TMPFILE"
			sed -i "\\~vpnmgr_~d" "$SETTINGSFILE"
			mv "$SETTINGSFILE" "$SETTINGSFILE.bak"
			cat "$SETTINGSFILE.bak" "$TMPFILE" > "$SETTINGSFILE"
			rm -f "$TMPFILE"
			rm -f "$SETTINGSFILE.bak"
			nvram commit
			Print_Output true "Merge of updated settings from WebUI completed successfully" "$PASS"
		else
			Print_Output false "No updated settings from WebUI found, no merge into $SCRIPT_CONF necessary" "$PASS"
		fi
	fi
}

Create_Dirs(){
	if [ ! -d "$SCRIPT_DIR" ]; then
		mkdir -p "$SCRIPT_DIR"
	fi
	
	if [ ! -d "$OVPN_ARCHIVE_DIR" ]; then
		mkdir -p "$OVPN_ARCHIVE_DIR"
	fi
	
	if [ ! -d "$SHARED_DIR" ]; then
		mkdir -p "$SHARED_DIR"
	fi
	
	if [ ! -d "$SCRIPT_WEBPAGE_DIR" ]; then
		mkdir -p "$SCRIPT_WEBPAGE_DIR"
	fi
	
	if [ ! -d "$SCRIPT_WEB_DIR" ]; then
		mkdir -p "$SCRIPT_WEB_DIR"
	fi
}

Create_Symlinks(){
	rm -rf "${SCRIPT_WEB_DIR:?}/"* 2>/dev/null
	
	ln -s "$SCRIPT_DIR/config" "$SCRIPT_WEB_DIR/config.htm" 2>/dev/null
	ln -s "$SCRIPT_DIR/nordvpn_countrydata" "$SCRIPT_WEB_DIR/nordvpn_countrydata.htm" 2>/dev/null
	ln -s "$SCRIPT_DIR/pia_countrydata" "$SCRIPT_WEB_DIR/pia_countrydata.htm" 2>/dev/null
	ln -s "$SCRIPT_DIR/wevpn_countrydata" "$SCRIPT_WEB_DIR/wevpn_countrydata.htm" 2>/dev/null
	
	ln -s /tmp/detect_vpnmgr.js "$SCRIPT_WEB_DIR/detect_vpnmgr.js" 2>/dev/null
	ln -s /tmp/vpnmgrserverloads "$SCRIPT_WEB_DIR/vpnmgrserverloads.js" 2>/dev/null
	
	if [ ! -d "$SHARED_WEB_DIR" ]; then
		ln -s "$SHARED_DIR" "$SHARED_WEB_DIR" 2>/dev/null
	fi
}

Conf_Exists(){
	if [ -f "$SCRIPT_CONF" ]; then
		dos2unix "$SCRIPT_CONF"
		chmod 0644 "$SCRIPT_CONF"
		sed -i -e 's/"//g' "$SCRIPT_CONF"
		if ! grep -q "_customsettings" "$SCRIPT_CONF"; then
			for i in 1 2 3 4 5; do
				sed -i '/^vpn'"$i"'_type=.*/a vpn'"$i"'_customsettings=true' "$SCRIPT_CONF"
			done
		fi
		return 0
	else
		for i in 1 2 3 4 5; do
			{
				echo "##### VPN Client $i #####"
				echo "vpn${i}_managed=false"
				echo "vpn${i}_provider=NordVPN"
				echo "vpn${i}_protocol=UDP"
				echo "vpn${i}_type=Standard"
				echo "vpn${i}_customsettings=true"
				echo "vpn${i}_schenabled=false"
				echo "vpn${i}_schdays=*"
				echo "vpn${i}_schhours=0"
				echo "vpn${i}_schmins=$i"
				echo "vpn${i}_countryname="
				echo "vpn${i}_cityname="
				echo "vpn${i}_countryid=0"
				echo "vpn${i}_cityid=0"
				echo "#########################"
			} >> "$SCRIPT_CONF"
		done
		return 1
	fi
}

# use to create content of vJSON variable; $1 VPN type, $2 VPN protocol, $3 country id
getRecommendedServers(){
	curlstring="https://api.nordvpn.com/v1/servers/recommendations?filters\[servers_groups\]\[identifier\]=${1}&filters\[servers_technologies\]\[identifier\]=${2}"
	if [ "$3" -ne 0 ]; then
		curlstring="${curlstring}&filters\[country_id\]=$3"
	fi
	curlstring="${curlstring}&limit=1"
	/usr/sbin/curl -fsL --retry 3 "$curlstring" | jq -r -e '.[] // empty'
}

getServerLoad(){
	curlstring="https://api.nordvpn.com/server/stats/"
	serverhostname="$(echo "$1" | cut -f2 -d ' ' | tr "A-Z" "a-z").nordvpn.com"
	/usr/sbin/curl -fsL --retry 3 "$curlstring$serverhostname" | jq -r -e '.percent // "Unknown"'
}

getServersforCity(){
	/usr/sbin/curl -fsL --retry 3 "https://api.nordvpn.com/v1/servers/recommendations?filters\[servers_groups\]\[identifier\]=${1}&filters\[servers_technologies\]\[identifier\]=${2}&filters\[country_id\]=${3}&limit=2500" | jq -r -e ' [ .[] | select(.locations[].country.city.id=='"$4"')][0] // empty'
}

getCountryData(){
	Print_Output true "Refreshing NordVPN country data..." "$PASS"
	/usr/sbin/curl -fsL --retry 3 "https://api.nordvpn.com/v1/servers/countries" | jq -r > /tmp/nordvpn_countrydata
	countrydata="$(cat /tmp/nordvpn_countrydata)"
	[ -z "$countrydata" ] && Print_Output true "Error, country data from NordVPN failed to download" "$ERR" && return 1
	if [ -f "$SCRIPT_DIR/nordvpn_countrydata" ]; then
		if ! diff -q /tmp/nordvpn_countrydata "$SCRIPT_DIR/nordvpn_countrydata" >/dev/null 2>&1; then
			mv /tmp/nordvpn_countrydata "$SCRIPT_DIR/nordvpn_countrydata"
			Print_Output true "Changes detected in NordVPN country data found, updating now" "$PASS"
			Create_Symlinks
		else
			rm -f /tmp/nordvpn_countrydata
			Print_Output true "No changes in NordVPN country data" "$WARN"
		fi
	else
		mv /tmp/nordvpn_countrydata "$SCRIPT_DIR/nordvpn_countrydata"
		Create_Symlinks
		Print_Output true "No previous NordVPN country data found, updating now" "$PASS"
	fi
}

sedCountryCodesDestructive(){
	sed 's/ /_/g;s/^AU_.*/Australia/I;s/^CA_.*/Canada/I;s/^DE_.*/Germany/I;s/^UAE_.*/United Arab Emirates/I;s/^UK_.*/United Kingdom/I;s/^US_.*/United States/I;
s/^AE_.*/United Arab Emirates/I;s/^GB_.*/United Kingdom/I;s/^AT_.*/Austria/I;s/^BE_.*/Belgium/I;s/^BG_.*/Bulgaria/I;s/^BR_.*/Brazil/I;
s/^CH_.*/Switzerland/I;s/^CZ_.*/Czech Republic/I;s/^DK_.*/Denmark/I;s/^ES_.*/Spain/I;s/^FR_.*/France/I;s/^HK_.*/Hong Kong/I;s/^HU_.*/Hungary/I;
s/^IE_.*/Ireland/I;s/^IL_.*/Israel/I;s/^IN_.*/India/I;s/^IT_.*/Italy/I;s/^JP_.*/Japan/I;s/^MX_.*/Mexico/I;s/^NL_.*/Netherlands/I;s/^NO_.*/Norway/I;s/^NZ_.*/New Zealand/I;
s/^PL_.*/Poland/I;s/^RO_.*/Romania/I;s/^RS_.*/Serbia/I;s/^SE_.*/Sweden/I;s/^SG_.*/Singapore/I;s/^ZA_.*/South Africa/I;s/_/ /g;'
}

sedCountryCodes(){
	sed 's/ /_/g;s/^AU_/Australia/I;s/^CA_/Canada/I;s/^DE_/Germany/I;s/^UAE_/United Arab Emirates/I;s/^UK_/United Kingdom/I;s/^US_/United States/I;
s/^AE_/United Arab Emirates/I;s/^GB_/United Kingdom/I;s/^AT_/Austria/I;s/^BE_/Belgium/I;s/^BG_/Bulgaria/I;s/^BR_/Brazil/I;
s/^CH_/Switzerland/I;s/^CZ_/Czech Republic/I;s/^DK_/Denmark/I;s/^ES_/Spain/I;s/^FR_/France/I;s/^HK_/Hong Kong/I;s/^HU_/Hungary/I;
s/^IE_/Ireland/I;s/^IL_/Israel/I;s/^IN_/India/I;s/^IT_/Italy/I;s/^JP_/Japan/I;s/^MX_/Mexico/I;s/^NL_/Netherlands/I;s/^NO_/Norway/I;s/^NZ_/New Zealand/I;
s/^PL_/Poland/I;s/^RO_/Romania/I;s/^RS_/Serbia/I;s/^SE_/Sweden/I;s/^SG_/Singapore/I;s/^ZA_/South Africa/I;s/_/ /g;'
}

sedReverseCountryCodesPIA(){
	sed 's/Australia/AU/;s/Canada/CA/;s/Germany/DE/;s/United Kingdom/UK/;s/United States/US/;'
}

sedReverseCountryCodesWeVPN(){
	sed 's/Australia/AU/;s/Canada/CA/;s/Germany/DE/;s/United States/US/;s/United Arab Emirates/AE/;s/United Kingdom/GB/;
s/Austria/AT/;s/Belgium/BE/;s/Bulgaria/BG/;s/Brazil/BR/;s/Switzerland/CH/;s/Czech Republic/CZ/;s/Denmark/DK/;s/Spain/ES/;s/France/FR/;
s/Hong Kong/HK/;s/Hungary/HU/;s/Ireland/IE/;s/Israel/IL/;s/India/IN/;s/Italy/IT/;s/Japan/JP/;s/Mexico/MX/;s/Netherlands/NL/;s/Norway/NO/;s/New Zealand/NZ/;
s/Poland/PL/;s/Romania/RO/;s/Serbia/RS/;s/Sweden/SE/;s/Singapore/SG/;s/South Africa/ZA/;s/_/ /g;'
}

getCountryNames(){
	if [ "$1" = "NordVPN" ]; then
		echo "$2" | jq -r -e '.[] | .name // empty'
	elif [ "$1" = "PIA" ] || [ "$1" = "WeVPN" ]; then
		echo "$2" | sedCountryCodesDestructive | awk '{$1=$1;print}' | awk '{for(i=1;i<=NF;i++){ $i=toupper(substr($i,1,1)) substr($i,2) }}1' | sort -u
	fi
}

getCountryID(){
	echo "$1" | jq -r -e '.[] | select(.name=="'"$2"'") | .id // empty'
}

getCityCount(){
	if [ "$1" = "NordVPN" ]; then
		echo "$2" | jq -r -e '.[] | select(.name=="'"$3"'") | .cities | length // empty'
	elif [ "$1" = "PIA" ] || [ "$1" = "WeVPN" ]; then
		echo "$2" | sedCountryCodesDestructive | sort | grep -c "$3"
	fi
}

getCityNames(){
	if [ "$1" = "NordVPN" ]; then
		echo "$2" | jq -r -e '.[] | select(.name=="'"$3"'") | .cities[] | .name // empty'
	elif [ "$1" = "PIA" ] || [ "$1" = "WeVPN" ]; then
		echo "$2" | sedCountryCodes | grep "$3" | sed "s/$3//" | awk '{$1=$1;print}' | awk '{for(i=1;i<=NF;i++){ $i=toupper(substr($i,1,1)) substr($i,2) }}1' | sort
	fi
}

getCityID(){
	echo "$1" | jq -r -e '.[] | select(.name=="'"$2"'") | .cities[] | select(.name=="'"$3"'") | .id // empty'
}

getIP(){
	echo "$1" | grep "^remote " | cut -f2 -d' '
}

getHostname(){
	echo "$1" | jq -r -e '.hostname // empty'
}

getOVPNcontents(){
	/usr/sbin/curl -fsL --retry 3 "https://downloads.nordcdn.com/configs/files/ovpn_$2/servers/$1"
}

getPort(){
	echo "$1" | grep "^remote " | cut -f3 -d' '
}

getCipher(){
	echo "$1" | grep "^cipher " | cut -f2 -d' '
}

getAuthDigest(){
	echo "$1" | grep "^auth " | cut -f2 -d' '
}

getClientCA(){
	echo "$1" | awk '/<ca>/{flag=1;next}/<\/ca>/{flag=0}flag' | sed '/^#/ d'
}

getClientCert(){
	echo "$1" | awk '/<cert>/{flag=1;next}/<\/cert>/{flag=0}flag' | sed '/^#/ d'
}

getStaticKey(){
	if [ "$2" = "NordVPN" ]; then
		echo "$1" | awk '/<tls-auth>/{flag=1;next}/<\/tls-auth>/{flag=0}flag' | sed '/^#/ d'
	elif [ "$2" = "WeVPN" ]; then
		echo "$1" | awk '/<tls-crypt>/{flag=1;next}/<\/tls-crypt>/{flag=0}flag' | sed '/^#/ d'
	fi
}

getKey(){
	echo "$1" | awk '/<key>/{flag=1;next}/<\/key>/{flag=0}flag' | sed '/^#/ d'
}

getCRL(){
	echo "$1" | awk '/<crl-verify>/{flag=1;next}/<\/crl-verify>/{flag=0}flag' | sed '/^#/ d'
}

getConnectState(){
	nvram get vpn_client"$1"_state
}

getOVPNArchives(){
	Print_Output true "Refreshing OpenVPN file archives..." "$PASS"
	
	### PIA ###
	# Standard UDP
	Download_File https://www.privateinternetaccess.com/openvpn/openvpn.zip /tmp/pia_udp_standard.zip
	# Standard TCP
	Download_File https://www.privateinternetaccess.com/openvpn/openvpn-tcp.zip /tmp/pia_tcp_standard.zip
	# Strong UDP
	Download_File https://www.privateinternetaccess.com/openvpn/openvpn-strong.zip /tmp/pia_udp_strong.zip
	# Strong TCP
	Download_File https://www.privateinternetaccess.com/openvpn/openvpn-strong-tcp.zip /tmp/pia_tcp_strong.zip
	###########
	
	piachanged="$(CompareArchiveContents "/tmp/pia_udp_standard.zip /tmp/pia_tcp_standard.zip /tmp/pia_udp_strong.zip /tmp/pia_tcp_strong.zip")"
	
	if [ "$piachanged" = "true" ]; then
		/opt/bin/7za -ba l "$OVPN_ARCHIVE_DIR/pia_udp_standard.zip" -- *.ovpn | awk '{ for (i = 6; i <= NF; i++) { printf "%s ",$i } printf "\n"}' | sed 's/\.ovpn//' | sort | awk '{$1=$1;print}' > "$SCRIPT_DIR/pia_countrydata"
		Print_Output true "Changes detected in PIA OpenVPN file archives, local copies updated" "$PASS"
	else
		Print_Output true "No changes in PIA OpenVPN file archives" "$WARN"
	fi
	
	### WeVPN ###
	# Standard UDP
	Download_File https://wevpn.com/resources/openvpn.bak/UDP.zip /tmp/wevpn_udp_standard.zip
	# Standard TCP
	Download_File https://wevpn.com/resources/openvpn.bak/TCP.zip /tmp/wevpn_tcp_standard.zip
	###########
	
	wevpnchanged="$(CompareArchiveContents "/tmp/wevpn_udp_standard.zip /tmp/wevpn_tcp_standard.zip")"
	
	if [ "$wevpnchanged" = "true" ]; then
		/opt/bin/7za -ba l "$OVPN_ARCHIVE_DIR/wevpn_tcp_standard.zip" -- *.ovpn | awk '{ for (i = 6; i <= NF; i++) { printf "%s ",$i } printf "\n"}' | sed 's/\.ovpn//;s/-UDP//;s/-TCP//;s/_/ /;' | sort | awk '{$1=$1;print}' > "$SCRIPT_DIR/wevpn_countrydata"
		Print_Output true "Changes detected in WeVPN OpenVPN file archives, local copies updated" "$PASS"
	else
		Print_Output true "No changes in WeVPN OpenVPN file archives" "$WARN"
	fi
}

CompareArchiveContents(){
	archiveschanged="false"
	FILES="$1"
	for f in $FILES; do
		if [ -f "$f" ]; then
			if [ -f "$OVPN_ARCHIVE_DIR/$(basename "$f")" ]; then
				remotemd5="$(md5sum "$f" | awk '{print $1}')"
				localmd5="$(md5sum "$OVPN_ARCHIVE_DIR/$(basename "$f")" | awk '{print $1}')"
				if [ "$localmd5" != "$remotemd5" ]; then
					mv "$f" "$OVPN_ARCHIVE_DIR/$(basename "$f")"
					archiveschanged="true"
				else
					rm -f "$f"
				fi
			else
				mv "$f" "$OVPN_ARCHIVE_DIR/$(basename "$f")"
				archiveschanged="true"
			fi
		fi
	done
	echo "$archiveschanged"
}

ListVPNClients(){
	showload="$1"
	showunmanaged="$2"
	
	if [ "$showload" = "true" ]; then
		printf "Checking server loads using NordVPN API...\\n\\n"
	fi
	
	printf "VPN client list:\\n\\n"
	for i in 1 2 3 4 5; do
		VPN_CLIENTDESC="$(nvram get vpn_client"$i"_desc)"
		if [ "$showload" = "true" ]; then
			if ! echo "$VPN_CLIENTDESC" | grep -iq "nordvpn"; then
				continue
			fi
		fi
		MANAGEDSTATE=""
		CONNECTSTATE=""
		SCHEDULESTATE=""
		CUSTOMSETTINGSTATE=""
		if [ "$(grep "vpn${i}_managed" "$SCRIPT_CONF" | cut -f2 -d"=")" = "true" ]; then
			MANAGEDSTATE="${BOLD}${PASS}Managed${CLEARFORMAT}"
		elif [ "$(grep "vpn${i}_managed" "$SCRIPT_CONF" | cut -f2 -d"=")" = "false" ]; then
			if [ "$showunmanaged" = "hide" ]; then
				continue
			fi
			MANAGEDSTATE="${BOLD}${ERR}Unmanaged${CLEARFORMAT}"
		fi
		if [ "$(getConnectState "$i")" = "2" ]; then
			CONNECTSTATE="${BOLD}${PASS}Connected${CLEARFORMAT}"
		else
			CONNECTSTATE="${BOLD}${ERR}Disconnected${CLEARFORMAT}"
		fi
		if [ "$(grep "vpn${i}_customsettings" "$SCRIPT_CONF" | cut -f2 -d"=")" = "true" ]; then
			CUSTOMSETTINGSTATE="${SETTING}Customised${CLEARFORMAT}"
		elif [ "$(grep "vpn${i}_customsettings" "$SCRIPT_CONF" | cut -f2 -d"=")" = "false" ]; then
			CUSTOMSETTINGSTATE="${BOLD}Uncustomised${CLEARFORMAT}"
		fi
		if [ "$(grep "vpn${i}_schenabled" "$SCRIPT_CONF" | cut -f2 -d"=")" = "true" ]; then
			SCHEDULESTATE="${SETTING}Scheduled${CLEARFORMAT}"
		elif [ "$(grep "vpn${i}_schenabled" "$SCRIPT_CONF" | cut -f2 -d"=")" = "false" ]; then
			SCHEDULESTATE="${BOLD}Unscheduled${CLEARFORMAT}"
		fi
		COUNTRYNAME="$(grep "vpn${i}_countryname" "$SCRIPT_CONF" | cut -f2 -d"=")"
		[ -z "$COUNTRYNAME" ] && COUNTRYNAME="None"
		CITYNAME="$(grep "vpn${i}_cityname" "$SCRIPT_CONF" | cut -f2 -d"=")"
		[ -z "$CITYNAME" ] && CITYNAME="None"
		
		if [ "$showload" = "true" ]; then
			SERVERLOAD="$(getServerLoad "$VPN_CLIENTDESC")"
		fi
		
		if [ "$(grep "vpn${i}_managed" "$SCRIPT_CONF" | cut -f2 -d"=")" = "true" ]; then
			printf "%s.    $VPN_CLIENTDESC ($MANAGEDSTATE, $SCHEDULESTATE, $CUSTOMSETTINGSTATE, $CONNECTSTATE)\\n" "$i"
		else
			printf "%s.    $VPN_CLIENTDESC ($MANAGEDSTATE, $CONNECTSTATE)\\n" "$i"
		fi
		if [ "$showload" = "true" ]; then
			printf "      Current server load: %s%%\\n" "$SERVERLOAD"
		fi
		printf "      Chosen country: %s - Preferred city: %s\\n\\n" "$COUNTRYNAME" "$CITYNAME"
	done
	printf "\\n"
}

UpdateVPNConfig(){
	ISUNATTENDED=""
	if [ "$1" = "unattended" ]; then
		ISUNATTENDED="true"
		shift
	fi
	VPN_NO="$1"
	VPN_PROVIDER="$(grep "vpn${VPN_NO}_provider" "$SCRIPT_CONF" | cut -f2 -d"=")"
	VPN_PROT_SHORT="$(grep "vpn${VPN_NO}_protocol" "$SCRIPT_CONF" | cut -f2 -d"=")"
	VPN_PROT="openvpn_$(echo "$VPN_PROT_SHORT" | tr "A-Z" "a-z")"
	VPN_TYPE_SHORT="$(grep "vpn${VPN_NO}_type" "$SCRIPT_CONF" | cut -f2 -d"=")"
	VPN_TYPE=""
	if [ "$VPN_TYPE_SHORT" = "Double" ]; then
		VPN_TYPE="legacy_$(echo "$VPN_TYPE_SHORT" | tr "A-Z" "a-z")""_vpn"
	else
		VPN_TYPE="legacy_$(echo "$VPN_TYPE_SHORT" | tr "A-Z" "a-z")"
	fi
	VPN_COUNTRYID="$(grep "vpn${VPN_NO}_countryid" "$SCRIPT_CONF" | cut -f2 -d"=")"
	VPN_COUNTRYNAME="$(grep "vpn${VPN_NO}_countryname" "$SCRIPT_CONF" | cut -f2 -d"=")"
	VPN_CITYID="$(grep "vpn${VPN_NO}_cityid" "$SCRIPT_CONF" | cut -f2 -d"=")"
	VPN_CITYNAME="$(grep "vpn${VPN_NO}_cityname" "$SCRIPT_CONF" | cut -f2 -d"=")"
	vJSON=""
	OVPNFILE=""
	OVPN_ADDR=""
	
	if [ "$VPN_PROVIDER" = "NordVPN" ]; then
		Print_Output true "Retrieving recommended VPN server using NordVPN API with below parameters" "$PASS"
		if [ "$VPN_COUNTRYID" -eq 0 ]; then
			Print_Output true "Protocol: $VPN_PROT_SHORT - Type: $VPN_TYPE_SHORT" "$PASS"
			vJSON="$(getRecommendedServers "$VPN_TYPE" "$VPN_PROT" "$VPN_COUNTRYID")"
		else
			if [ "$VPN_CITYID" -eq 0 ]; then
				Print_Output true "Protocol: $VPN_PROT_SHORT - Type: $VPN_TYPE_SHORT - Country: $VPN_COUNTRYNAME" "$PASS"
				vJSON="$(getRecommendedServers "$VPN_TYPE" "$VPN_PROT" "$VPN_COUNTRYID")"
			else
				Print_Output true "Protocol: $VPN_PROT_SHORT - Type: $VPN_TYPE_SHORT - Country: $VPN_COUNTRYNAME - City: $VPN_CITYNAME" "$PASS"
				vJSON="$(getServersforCity "$VPN_TYPE" "$VPN_PROT" "$VPN_COUNTRYID" "$VPN_CITYID")"
				if [ -z "$vJSON" ]; then
					Print_Output true "No VPN servers found for $VPN_CITYNAME, removing filter for city" "$WARN"
					vJSON="$(getRecommendedServers "$VPN_TYPE" "$VPN_PROT" "$VPN_COUNTRYID")"
					if [ -z "$vJSON" ]; then
						Print_Output true "No VPN servers found for $VPN_COUNTRYNAME, removing filter for country" "$WARN"
						vJSON="$(getRecommendedServers "$VPN_TYPE" "$VPN_PROT" 0)"
					fi
				fi
			fi
		fi
		
		[ -z "$vJSON" ] && Print_Output true "Error contacting NordVPN API" "$ERR" && return 1
		OVPN_HOSTNAME="$(getHostname "$vJSON")"
		[ -z "$OVPN_HOSTNAME" ] && Print_Output true "Could not determine hostname for VPN server" "$ERR" && return 1
		OVPNFILE="$OVPN_HOSTNAME.$(echo "$VPN_PROT" | cut -f2 -d"_").ovpn"
		OVPN_DETAIL="$(getOVPNcontents "$OVPNFILE" "$(echo "$VPN_PROT" | cut -f2 -d"_")")"
	elif [ "$VPN_PROVIDER" = "PIA" ]; then
		OVPNARCHIVE="$OVPN_ARCHIVE_DIR/pia_$(echo "$VPN_PROT" | cut -f2 -d"_")_$(echo "$VPN_TYPE" | cut -f2 -d"_").zip"
		OVPN_FILENAME="$(echo "$VPN_COUNTRYNAME" | sedReverseCountryCodesPIA)"
		if [ -n "$VPN_CITYNAME" ]; then
			OVPN_FILENAME="${OVPN_FILENAME}_${VPN_CITYNAME}"
		fi
		OVPN_FILENAME="$(echo "$OVPN_FILENAME" | tr "A-Z" "a-z" | sed 's/ /_/g;')"
		/opt/bin/7za e -bsp0 -bso0 "$OVPNARCHIVE" -o/tmp "$OVPN_FILENAME.ovpn"
		OVPN_DETAIL="$(cat "/tmp/$OVPN_FILENAME.ovpn")"
		rm -f "/tmp/$OVPN_FILENAME.ovpn"
	elif [ "$VPN_PROVIDER" = "WeVPN" ]; then
		OVPNARCHIVE="$OVPN_ARCHIVE_DIR/wevpn_$(echo "$VPN_PROT" | cut -f2 -d"_")_$(echo "$VPN_TYPE" | cut -f2 -d"_").zip"
		OVPN_FILENAME="$(echo "$VPN_COUNTRYNAME" | sedReverseCountryCodesWeVPN)"'_'"$(echo "$VPN_CITYNAME" | tr "A-Z" "a-z")-$VPN_PROT_SHORT"
		/opt/bin/7za e -bsp0 -bso0 "$OVPNARCHIVE" -o/tmp "$OVPN_FILENAME.ovpn"
		OVPN_DETAIL="$(cat "/tmp/$OVPN_FILENAME.ovpn")"
		rm -f "/tmp/$OVPN_FILENAME.ovpn"
	fi
	
	[ -z "$OVPN_DETAIL" ] && Print_Output true "Error retrieving VPN server ovpn file" "$ERR" && return 1
	
	OVPN_ADDR="$(getIP "$OVPN_DETAIL")"
	[ -z "$OVPN_ADDR" ] && Print_Output true "Could not determine address for VPN server" "$ERR" && return 1
	OVPN_PORT="$(getPort "$OVPN_DETAIL")"
	[ -z "$OVPN_PORT" ] && Print_Output true "Error determining port for VPN server" "$ERR" && return 1
	OVPN_CIPHER="$(getCipher "$OVPN_DETAIL")"
	[ -z "$OVPN_CIPHER" ] && Print_Output true "Error determining cipher for VPN server" "$ERR" && return 1
	OVPN_AUTHDIGEST="$(getAuthDigest "$OVPN_DETAIL")"
	[ -z "$OVPN_AUTHDIGEST" ] && Print_Output true "Error determining auth digest for VPN server" "$ERR" && return 1
	CLIENT_CA="$(getClientCA "$OVPN_DETAIL")"
	[ -z "$CLIENT_CA" ] && Print_Output true "Error determing VPN server Certificate Authority certificate" "$ERR" && return 1
	
	STATIC_KEY=""
	if [ "$VPN_PROVIDER" != "PIA" ]; then
		STATIC_KEY="$(getStaticKey "$OVPN_DETAIL" "$VPN_PROVIDER")"
		[ -z "$STATIC_KEY" ] && Print_Output true "Error determing VPN static key" "$ERR" && return 1
	fi
	
	CLIENT_KEY=""
	if [ "$VPN_PROVIDER" = "WeVPN" ]; then
		CLIENT_KEY="$(getKey "$OVPN_DETAIL")"
		[ -z "$CLIENT_KEY" ] && Print_Output true "Error determing VPN client key" "$ERR" && return 1
	fi
	
	CLIENT_CRT=""
	if [ "$VPN_PROVIDER" = "WeVPN" ]; then
		CLIENT_CRT="$(getClientCert "$OVPN_DETAIL")"
		[ -z "$CLIENT_CRT" ] && Print_Output true "Error determing VPN client cert" "$ERR" && return 1
	fi
	
	CLIENT_CRL=""
	if [ "$VPN_PROVIDER" = "PIA" ]; then
		CLIENT_CRL="$(getCRL "$OVPN_DETAIL")"
		[ -z "$CLIENT_CRL" ] && Print_Output true "Error determing VPN client CRL" "$ERR" && return 1
	fi
	
	EXISTING_ADDR="$(nvram get vpn_client"$VPN_NO"_addr)"
	EXISTING_PORT="$(nvram get vpn_client"$VPN_NO"_port)"
	EXISTING_PROTO="$(nvram get vpn_client"$VPN_NO"_proto)"
	if [ "$EXISTING_PROTO" = "tcp-client" ]; then
		EXISTING_PROTO="TCP"
	elif [ "$EXISTING_PROTO" = "udp" ]; then
		EXISTING_PROTO="UDP"
	fi
	
	OVPN_HOSTNAME_SHORT=""
	if [ "$VPN_PROVIDER" = "NordVPN" ]; then
		OVPN_HOSTNAME_SHORT="$(echo "$OVPN_HOSTNAME" | cut -f1 -d'.' | tr "a-z" "A-Z")"
	elif [ "$VPN_PROVIDER" = "PIA" ]; then
		if echo "$OVPN_ADDR" | grep -q "-" ; then
			OVPN_HOSTNAME_SHORT="$(echo "$OVPN_ADDR" | cut -f1 -d'.' | awk '{print toupper(substr($0,0,2))tolower(substr($0,3))}')"
		else
			OVPN_HOSTNAME_SHORT="$(echo "$OVPN_ADDR" | cut -f1 -d'.' | awk '{print toupper(substr($0,0,1))tolower(substr($0,2))}')"
		fi
	elif [ "$VPN_PROVIDER" = "WeVPN" ]; then
		OVPN_HOSTNAME_SHORT="$(echo "$OVPN_ADDR" | cut -f1 -d'.' | awk '{print toupper(substr($0,0,1))tolower(substr($0,2))}')"
	fi
	
	if [ "$OVPN_ADDR" = "$EXISTING_ADDR" ] && [ "$OVPN_PORT" = "$EXISTING_PORT" ] && [ "$VPN_PROT_SHORT" = "$EXISTING_PROTO" ]; then
		Print_Output true "VPN client $VPN_NO server - unchanged" "$WARN"
		return 1
	fi
	
	Print_Output true "Updating VPN client $VPN_NO to $VPN_PROVIDER server" "$PASS"
	
	if [ -z "$(nvram get vpn_client"$VPN_NO"_addr)" ]; then
		nvram set vpn_client"$VPN_NO"_adns=3
		nvram set vpn_client"$VPN_NO"_enforce=1
		if [ "$(Firmware_Number_Check "$(nvram get buildno)")" -lt "$(Firmware_Number_Check 384.18)" ]; then
			nvram set vpn_client"$VPN_NO"_clientlist="<DummyVPN>172.16.14.1>0.0.0.0>VPN"
		else
			nvram set vpn_client"$VPN_NO"_clientlist="<DummyVPN>172.16.14.1>>VPN"
		fi
		if ! nvram get vpn_clientx_eas | grep -q "$VPN_NO"; then
			nvram set vpn_clientx_eas="$(nvram get vpn_clientx_eas),$VPN_NO"
		fi
	fi
	
	nvram set vpn_client"$VPN_NO"_addr="$OVPN_ADDR"
	nvram set vpn_client"$VPN_NO"_port="$OVPN_PORT"
	if [ "$VPN_PROT_SHORT" = "TCP" ]; then
		nvram set vpn_client"$VPN_NO"_proto="tcp-client"
	elif [ "$VPN_PROT_SHORT" = "UDP" ]; then
		nvram set vpn_client"$VPN_NO"_proto="udp"
	fi
	nvram set vpn_client"$VPN_NO"_desc="$VPN_PROVIDER $OVPN_HOSTNAME_SHORT $VPN_TYPE_SHORT $VPN_PROT_SHORT"
	
	nvram set vpn_client"$VPN_NO"_cipher="$OVPN_CIPHER"
	nvram set vpn_client"$VPN_NO"_crypt="tls"
	nvram set vpn_client"$VPN_NO"_digest="$OVPN_AUTHDIGEST"
	nvram set vpn_client"$VPN_NO"_fw=1
	nvram set vpn_client"$VPN_NO"_if="tun"
	nvram set vpn_client"$VPN_NO"_nat=1
	nvram set vpn_client"$VPN_NO"_ncp_ciphers="AES-256-GCM:AES-128-GCM:AES-256-CBC:AES-128-CBC"
	nvram set vpn_client"$VPN_NO"_ncp_enable=1
	nvram set vpn_client"$VPN_NO"_reneg=0
	nvram set vpn_client"$VPN_NO"_tlsremote=0
	nvram set vpn_client"$VPN_NO"_userauth=1
	nvram set vpn_client"$VPN_NO"_useronly=0
	
	if [ "$VPN_PROVIDER" = "NordVPN" ] || [ "$VPN_PROVIDER" = "WeVPN" ]; then
		nvram set vpn_client"$VPN_NO"_comp="-1"
	elif [ "$VPN_PROVIDER" = "PIA" ]; then
		nvram set vpn_client"$VPN_NO"_comp="no"
	fi
	
	if [ "$VPN_PROVIDER" = "NordVPN" ] || [ "$VPN_PROVIDER" = "PIA" ]; then
		nvram set vpn_client"$VPN_NO"_hmac=1
	elif [ "$VPN_PROVIDER" = "WeVPN" ]; then
		nvram set vpn_client"$VPN_NO"_hmac=3
	fi
	
	if [ "$(Firmware_Number_Check "$(nvram get buildno)")" -lt "$(Firmware_Number_Check 384.19)" ]; then
		nvram set vpn_client"$VPN_NO"_connretry="-1"
	else
		nvram set vpn_client"$VPN_NO"_connretry=0
	fi
	
	if [ "$(grep "vpn${VPN_NO}_customsettings" "$SCRIPT_CONF" | cut -f2 -d"=")" = "true" ]; then
		SetVPNCustomSettings "$VPN_NO"
	fi
	
	if [ "$ISUNATTENDED" = "true" ]; then
		if [ -z "$(nvram get vpn_client"$VPN_NO"_username)" ]; then
			Print_Output true "No username set for VPN client $VPN_NO" "$WARN"
		fi
		
		if [ -z "$(nvram get vpn_client"$VPN_NO"_password)" ]; then
			Print_Output true "No password set for VPN client $VPN_NO" "$WARN"
		fi
	else
		if [ -n "$(nvram get vpn_client"$VPN_NO"_username)" ] && [ -n "$(nvram get vpn_client"$VPN_NO"_password)" ]; then
			while true; do
				printf "\\n${BOLD}Do you want to update the username and password for the VPN client? (y/n)${CLEARFORMAT}  "
				read -r confirm
				case "$confirm" in
					y|Y)
						printf "Please enter username:  "
						read -r vpnusn
						nvram set vpn_client"$VPN_NO"_username="$vpnusn"
						printf "\\n"
						printf "Please enter password:  "
						read -r vpnpwd
						nvram set vpn_client"$VPN_NO"_password="$vpnpwd"
						printf "\\n"
						break
					;;
					n|N)
						break
					;;
					*)
						printf "\\n${BOLD}Please enter a valid choice (y/n)${CLEARFORMAT}\\n"
					;;
				esac
			done
		fi
		
		if [ -z "$(nvram get vpn_client"$VPN_NO"_username)" ]; then
			printf "\\n${BOLD}No username set for VPN client %s${CLEARFORMAT}\\n" "$VPN_NO"
			printf "Please enter username:  "
			read -r vpnusn
			nvram set vpn_client"$VPN_NO"_username="$vpnusn"
			printf "\\n"
		fi
		
		if [ -z "$(nvram get vpn_client"$VPN_NO"_password)" ]; then
			printf "\\n${BOLD}No password set for VPN client %s${CLEARFORMAT}\\n" "$VPN_NO"
			printf "Please enter password:  "
			read -r vpnpwd
			nvram set vpn_client"$VPN_NO"_password="$vpnpwd"
			printf "\\n"
		fi
	fi
	
	nvram commit
	
	if [ "$VPN_PROVIDER" = "NordVPN" ]; then
		echo "$CLIENT_CA" > /jffs/openvpn/vpn_crt_client"$VPN_NO"_ca
		echo "$STATIC_KEY" > /jffs/openvpn/vpn_crt_client"$VPN_NO"_static
		rm -f /jffs/openvpn/vpn_crt_client"$VPN_NO"_crl
		rm -f /jffs/openvpn/vpn_crt_client"$VPN_NO"_key
		rm -f /jffs/openvpn/vpn_crt_client"$VPN_NO"_crt
	elif [ "$VPN_PROVIDER" = "PIA" ]; then
		echo "$CLIENT_CA" > /jffs/openvpn/vpn_crt_client"$VPN_NO"_ca
		echo "$CLIENT_CRL" > /jffs/openvpn/vpn_crt_client"$VPN_NO"_crl
		rm -f /jffs/openvpn/vpn_crt_client"$VPN_NO"_static
		rm -f /jffs/openvpn/vpn_crt_client"$VPN_NO"_key
		rm -f /jffs/openvpn/vpn_crt_client"$VPN_NO"_crt
	elif [ "$VPN_PROVIDER" = "WeVPN" ]; then
		echo "$CLIENT_CA" > /jffs/openvpn/vpn_crt_client"$VPN_NO"_ca
		echo "$CLIENT_CRT" > /jffs/openvpn/vpn_crt_client"$VPN_NO"_crt
		echo "$STATIC_KEY" > /jffs/openvpn/vpn_crt_client"$VPN_NO"_static
		echo "$CLIENT_KEY" > /jffs/openvpn/vpn_crt_client"$VPN_NO"_key
		rm -f /jffs/openvpn/vpn_crt_client"$VPN_NO"_crl
	fi
	
	if nvram get vpn_clientx_eas | grep -q "$VPN_NO"; then
		service restart_vpnclient"$VPN_NO" >/dev/null 2>&1
	fi
	Print_Output true "VPN client $VPN_NO updated successfully ($OVPN_HOSTNAME_SHORT $VPN_TYPE_SHORT $VPN_PROT_SHORT)" "$PASS"
}

ManageVPN(){
	VPN_NO="$1"
	
	if [ -z "$(nvram get vpn_client"$VPN_NO"_username)" ] && [ -z "$(nvram get vpn_client"$VPN_NO"_password)" ]; then
		Print_Output false "No username or password set for VPN client $VPN_NO, cannot enable management" "$ERR"
		return 1
	fi
	
	Print_Output true "Enabling management of VPN client $VPN_NO" "$PASS"
	sed -i 's/^vpn'"$VPN_NO"'_managed.*$/vpn'"$VPN_NO"'_managed=true/' "$SCRIPT_CONF"
	Print_Output true "Management of VPN client $VPN_NO successfully enabled" "$PASS"
}

UnmanageVPN(){
	VPN_NO="$1"
	
	Print_Output true "Removing management of VPN client $VPN_NO" "$PASS"
	sed -i 's/^vpn'"$VPN_NO"'_managed.*$/vpn'"$VPN_NO"'_managed=false/' "$SCRIPT_CONF"
	CancelScheduleVPN "$VPN_NO"
	Print_Output true "Management of VPN client $VPN_NO successfully removed" "$PASS"
}

ScheduleVPN(){
	VPN_NO="$1"
	CRU_DAYNUMBERS="$(grep "vpn${VPN_NO}_schdays" "$SCRIPT_CONF" | cut -f2 -d"=" | sed 's/Sun/0/;s/Mon/1/;s/Tues/2/;s/Wed/3/;s/Thurs/4/;s/Fri/5/;s/Sat/6/;')"
	CRU_HOURS="$(grep "vpn${VPN_NO}_schhours" "$SCRIPT_CONF" | cut -f2 -d"=")"
	CRU_MINUTES="$(grep "vpn${VPN_NO}_schmins" "$SCRIPT_CONF" | cut -f2 -d"=")"
	
	Print_Output true "Configuring scheduled update for VPN client $VPN_NO" "$PASS"
	
	if cru l | grep -q "${SCRIPT_NAME}${VPN_NO}"; then
		cru d "${SCRIPT_NAME}_VPN${VPN_NO}"
	fi
	
	cru a "${SCRIPT_NAME}_VPN${VPN_NO}" "$CRU_MINUTES $CRU_HOURS * * $CRU_DAYNUMBERS /jffs/scripts/$SCRIPT_NAME updatevpn $VPN_NO"
	
	if [ -f /jffs/scripts/services-start ]; then
		sed -i "/${SCRIPT_NAME}_VPN${VPN_NO}/d" /jffs/scripts/services-start
		echo "cru a ${SCRIPT_NAME}_VPN${VPN_NO} \"$CRU_MINUTES $CRU_HOURS * * $CRU_DAYNUMBERS /jffs/scripts/$SCRIPT_NAME updatevpn $VPN_NO\" # $SCRIPT_NAME" >> /jffs/scripts/services-start
	else
		echo "#!/bin/sh" > /jffs/scripts/services-start
		echo "cru a ${SCRIPT_NAME}_VPN${VPN_NO} \"$CRU_MINUTES $CRU_HOURS * * $CRU_DAYNUMBERS /jffs/scripts/$SCRIPT_NAME updatevpn $VPN_NO\" # $SCRIPT_NAME" >> /jffs/scripts/services-start
		chmod 755 /jffs/scripts/services-start
	fi
	
	sed -i 's/^vpn'"$VPN_NO"'_schenabled.*$/vpn'"$VPN_NO"'_schenabled=true/' "$SCRIPT_CONF"
	
	Print_Output true "Scheduled update created for VPN client $VPN_NO" "$PASS"
}

CancelScheduleVPN(){
	VPN_NO="$1"
	
	Print_Output true "Removing scheduled update for VPN client $VPN_NO" "$PASS"
		
	if cru l | grep -q "${SCRIPT_NAME}_VPN${VPN_NO}"; then
		cru d "${SCRIPT_NAME}_VPN${VPN_NO}"
	fi
	
	sed -i 's/^vpn'"$VPN_NO"'_schenabled.*$/vpn'"$VPN_NO"'_schenabled=false/' "$SCRIPT_CONF"
	
	if grep -q "${SCRIPT_NAME}_VPN${VPN_NO}" /jffs/scripts/services-start; then
		sed -i "/${SCRIPT_NAME}_VPN${VPN_NO}/d" /jffs/scripts/services-start
	fi
	
	Print_Output true "Scheduled update cancelled for VPN client $VPN_NO" "$PASS"
}

Shortcut_Script(){
	case $1 in
		create)
			if [ -d /opt/bin ] && [ ! -f "/opt/bin/$SCRIPT_NAME" ] && [ -f "/jffs/scripts/$SCRIPT_NAME" ]; then
				ln -s "/jffs/scripts/$SCRIPT_NAME" /opt/bin
				chmod 0755 "/opt/bin/$SCRIPT_NAME"
			fi
		;;
		delete)
			if [ -f "/opt/bin/$SCRIPT_NAME" ]; then
				rm -f "/opt/bin/$SCRIPT_NAME"
			fi
		;;
	esac
}

SetVPNClient(){
	ScriptHeader
	ListVPNClients false "$1"
	printf "Choose options as follows:\\n"
	printf "    - VPN client (pick from list)\\n"
	printf "\\n"
	printf "${BOLD}#########################################################${CLEARFORMAT}\\n"
	
	exitmenu=""
	vpnnum=""
	
	while true; do
		printf "\\n${BOLD}Please enter the VPN client number (pick from list):${CLEARFORMAT}  "
		read -r vpn_choice
		
		if [ "$vpn_choice" = "e" ]; then
			exitmenu="exit"
			break
		elif ! Validate_Number "$vpn_choice"; then
			printf "\\n\\e[31mPlease enter a valid number (pick from list)${CLEARFORMAT}\\n"
		else
			if [ "$vpn_choice" -lt 1 ] || [ "$vpn_choice" -gt 5 ]; then
				printf "\\n\\e[31mPlease enter a number between 1 and 5${CLEARFORMAT}\\n"
			else
				vpnnum="$vpn_choice"
				printf "\\n"
				break
			fi
		fi
	done
	
	if [ "$exitmenu" != "exit" ]; then
		GLOBAL_VPN_NO="$vpnnum"
		return 0
	else
		printf "\\n"
		return 1
	fi
}

SetVPNParameters(){
	exitmenu=""
	vpnnum=""
	vpnprovider=""
	vpnprot=""
	vpntype=""
	countrydata=""
	choosecountry=""
	choosecity=""
	countryname=""
	countryid=0
	cityname=""
	cityid=0
	
	while true; do
		printf "\\n${BOLD}Please enter the VPN client number (pick from list):${CLEARFORMAT}  "
		read -r vpn_choice
		
		if [ "$vpn_choice" = "e" ]; then
			exitmenu="exit"
			break
		elif ! Validate_Number "$vpn_choice"; then
			printf "\\n\\e[31mPlease enter a valid number (pick from list)${CLEARFORMAT}\\n"
		else
			if [ "$vpn_choice" -lt 1 ] || [ "$vpn_choice" -gt 5 ]; then
				printf "\\n\\e[31mPlease enter a number between 1 and 5${CLEARFORMAT}\\n"
			else
				vpnnum="$vpn_choice"
				printf "\\n"
				break
			fi
		fi
	done
	
	if [ "$exitmenu" != "exit" ]; then
		if [ "$(grep "vpn${vpnnum}_managed" "$SCRIPT_CONF" | cut -f2 -d"=")" = "false" ]; then
			Print_Output false "VPN client $vpnnum is not managed" "$ERR"
			return 1
		fi
		while true; do
			printf "\\n${BOLD}Please select a VPN provider:${CLEARFORMAT}\\n"
			printf "    1. NordVPN\\n"
			printf "    2. Private Internet Access (PIA)\\n"
			printf "    3. WeVPN\\n\\n"
			printf "Choose an option:  "
			read -r provmenu
			
			case "$provmenu" in
				1)
					vpnprovider="NordVPN"
					printf "\\n"
					break
				;;
				2)
					vpnprovider="PIA"
					printf "\\n"
					break
				;;
				3)
					vpnprovider="WeVPN"
					printf "\\n"
					break
				;;
				e)
					exitmenu="exit"
					break
				;;
				*)
					printf "\\n\\e[31mPlease enter a valid choice (1-2)${CLEARFORMAT}\\n"
				;;
			esac
		done
	fi
	
	if [ "$exitmenu" != "exit" ]; then
		if [ "$vpnprovider" = "NordVPN" ]; then
			while true; do
				printf "\\n${BOLD}Please select a VPN Type:${CLEARFORMAT}\\n"
				printf "    1. Standard\\n"
				printf "    2. Double\\n"
				printf "    3. P2P\\n\\n"
				printf "Choose an option:  "
				read -r typemenu
				
				case "$typemenu" in
					1)
						vpntype="legacy_standard"
						printf "\\n"
						break
					;;
					2)
						vpntype="legacy_double_vpn"
						printf "\\n"
						break
					;;
					3)
						vpntype="legacy_p2p"
						printf "\\n"
						break
					;;
					e)
						exitmenu="exit"
						break
					;;
					*)
						printf "\\n\\e[31mPlease enter a valid choice (1-3)${CLEARFORMAT}\\n"
					;;
				esac
			done
		elif [ "$vpnprovider" = "PIA" ]; then
			while true; do
				printf "\\n${BOLD}Please select a VPN Type:${CLEARFORMAT}\\n"
				printf "    1. Standard\\n"
				printf "    2. Strong\\n\\n"
				printf "Choose an option:  "
				read -r typemenu
				
				case "$typemenu" in
					1)
						vpntype="standard"
						printf "\\n"
						break
					;;
					2)
						vpntype="strong"
						printf "\\n"
						break
					;;
					e)
						exitmenu="exit"
						break
					;;
					*)
						printf "\\n\\e[31mPlease enter a valid choice (1-3)${CLEARFORMAT}\\n"
					;;
				esac
			done
		elif [ "$vpnprovider" = "WeVPN" ]; then
			vpntype="standard"
		fi
	fi
	
	if [ "$exitmenu" != "exit" ]; then
		while true; do
			printf "\\n${BOLD}Please select a VPN protocol:${CLEARFORMAT}\\n"
			printf "    1. UDP\\n"
			printf "    2. TCP\\n\\n"
			printf "Choose an option:  "
			read -r protmenu
			
			case "$protmenu" in
				1)
					vpnprot="openvpn_udp"
					printf "\\n"
					break
				;;
				2)
					vpnprot="openvpn_tcp"
					printf "\\n"
					break
				;;
				e)
					exitmenu="exit"
					break
				;;
				*)
					printf "\\n\\e[31mPlease enter a valid choice (1-2)${CLEARFORMAT}\\n"
				;;
			esac
		done
	fi
	
		if [ "$exitmenu" != "exit" ]; then
			if [ "$vpnprovider" = "NordVPN" ]; then
				while true; do
					printf "\\n${BOLD}Would you like to select a country (y/n)?${CLEARFORMAT}  "
					read -r country_select
					
					if [ "$country_select" = "e" ]; then
						exitmenu="exit"
						break
					elif [ "$country_select" = "n" ] || [ "$country_select" = "N" ]; then
						choosecountry="false"
						break
					elif [ "$country_select" = "y" ] || [ "$country_select" = "Y" ]; then
						choosecountry="true"
						break
					else
						printf "\\n\\e[31mPlease enter y or n${CLEARFORMAT}\\n"
					fi
				done
			elif [ "$vpnprovider" = "PIA" ] || [ "$vpnprovider" = "WeVPN" ]; then
				choosecountry="true"
			fi
		fi
		
		if [ "$choosecountry" = "true" ]; then
			LISTCOUNTRIES=""
			if [ "$vpnprovider" = "NordVPN" ]; then
				countrydata="$(cat "$SCRIPT_DIR/nordvpn_countrydata")"
				[ -z "$countrydata" ] && Print_Output true "Error, country data from NordVPN is missing" "$ERR" && return 1
				LISTCOUNTRIES="$(getCountryNames NordVPN "$countrydata")"
			elif [ "$vpnprovider" = "PIA" ]; then
				countrydata="$(cat "$SCRIPT_DIR/pia_countrydata")"
				[ -z "$countrydata" ] && Print_Output true "Error, country data from PIA is missing" "$ERR" && return 1
				LISTCOUNTRIES="$(getCountryNames PIA "$countrydata")"
			elif [ "$vpnprovider" = "WeVPN" ]; then
				countrydata="$(cat "$SCRIPT_DIR/wevpn_countrydata")"
				[ -z "$countrydata" ] && Print_Output true "Error, country data from WeVPN is missing" "$ERR" && return 1
				LISTCOUNTRIES="$(getCountryNames WeVPN "$countrydata")"
			fi
			COUNTCOUNTRIES="$(echo "$LISTCOUNTRIES" | wc -l)"
			while true; do
				printf "\\n${BOLD}Please select a country:${CLEARFORMAT}\\n"
				COUNTER=1
				IFS=$'\n'
				for COUNTRY in $LISTCOUNTRIES; do
					printf "    %s. %s\\n" "$COUNTER" "$COUNTRY" >> /tmp/vpnmgr_countrylist
					COUNTER=$((COUNTER+1))
				done
				column /tmp/vpnmgr_countrylist
				rm -f /tmp/vpnmgr_countrylist
				unset IFS
				
				printf "\\nChoose an option:  "
				read -r country_choice
				
				if [ "$country_choice" = "e" ]; then
					exitmenu="exit"
					break
				elif ! Validate_Number "$country_choice"; then
					printf "\\n\\e[31mPlease enter a valid number (1-%s)${CLEARFORMAT}\\n" "$COUNTCOUNTRIES"
				else
					if [ "$country_choice" -lt 1 ] || [ "$country_choice" -gt "$COUNTCOUNTRIES" ]; then
						printf "\\n\\e[31mPlease enter a number between 1 and %s${CLEARFORMAT}\\n" "$COUNTCOUNTRIES"
					else
						countryname="$(echo "$LISTCOUNTRIES" | sed -n "$country_choice"p)"
						if [ "$vpnprovider" = "NordVPN" ]; then
							countryid="$(getCountryID "$countrydata" "$countryname")"
						fi
						printf "\\n"
						break
					fi
				fi
			done
		
			if [ "$exitmenu" != "exit" ]; then
				citycount=0
				if [ "$vpnprovider" = "NordVPN" ]; then
					citycount="$(getCityCount NordVPN "$countrydata" "$countryname")"
				elif [ "$vpnprovider" = "PIA" ]; then
					countrydata="$(cat "$SCRIPT_DIR/pia_countrydata")"
					citycount="$(getCityCount PIA "$countrydata" "$countryname")"
				elif [ "$vpnprovider" = "WeVPN" ]; then
					countrydata="$(cat "$SCRIPT_DIR/wevpn_countrydata")"
					citycount="$(getCityCount WeVPN "$countrydata" "$countryname")"
				fi
				
				if [ "$citycount" -eq 1 ]; then
					if [ "$vpnprovider" = "NordVPN" ]; then
						cityname="$(getCityNames NordVPN "$countrydata" "$countryname")"
						cityid="$(getCityID "$countrydata" "$countryname" "$cityname")"
					elif [ "$vpnprovider" = "PIA" ]; then
						countrydata="$(cat "$SCRIPT_DIR/pia_countrydata")"
						cityname="$(getCityNames PIA "$countrydata" "$countryname")"
					elif [ "$vpnprovider" = "WeVPN" ]; then
						countrydata="$(cat "$SCRIPT_DIR/wevpn_countrydata")"
						cityname="$(getCityNames WeVPN "$countrydata" "$countryname")"
					fi
				elif [ "$citycount" -gt 1 ]; then
					if [ "$vpnprovider" = "NordVPN" ]; then
						while true; do
							printf "\\n${BOLD}Would you like to select a city (y/n)?${CLEARFORMAT}  "
							read -r city_select
							
							if [ "$city_select" = "e" ]; then
								exitmenu="exit"
								break
							elif [ "$city_select" = "n" ] || [ "$city_select" = "N" ]; then
								choosecity="false"
								break
							elif [ "$city_select" = "y" ] || [ "$city_select" = "Y" ]; then
								choosecity="true"
								break
							else
								printf "\\n\\e[31mPlease enter y or n${CLEARFORMAT}\\n"
							fi
						done
					elif [ "$vpnprovider" = "PIA" ] || [ "$vpnprovider" = "WeVPN" ]; then
						choosecity="true"
					fi
				fi
			fi
			
			if [ "$choosecity" = "true" ]; then
				LISTCITIES=""
				
				if [ "$vpnprovider" = "NordVPN" ]; then
					LISTCITIES="$(getCityNames NordVPN "$countrydata" "$countryname")"
				elif [ "$vpnprovider" = "PIA" ]; then
					countrydata="$(cat "$SCRIPT_DIR/pia_countrydata")"
					LISTCITIES="$(getCityNames PIA "$countrydata" "$countryname")"
				elif [ "$vpnprovider" = "WeVPN" ]; then
					countrydata="$(cat "$SCRIPT_DIR/wevpn_countrydata")"
					LISTCITIES="$(getCityNames WeVPN "$countrydata" "$countryname")"
				fi
				
				COUNTCITIES="$(echo "$LISTCITIES" | wc -l)"
				while true; do
					printf "\\n${BOLD}Please select a city:${CLEARFORMAT}\\n"
					COUNTER=1
					IFS=$'\n'
					for CITY in $LISTCITIES; do
						printf "    %s. %s\\n" "$COUNTER" "$CITY"
						COUNTER=$((COUNTER+1))
					done
					unset IFS
					
					printf "\\nChoose an option:  "
					read -r city_choice
					
					if [ "$city_choice" = "e" ]; then
						exitmenu="exit"
						break
					elif ! Validate_Number "$city_choice"; then
						printf "\\n\\e[31mPlease enter a valid number (1-%s)${CLEARFORMAT}\\n" "$COUNTCITIES"
					else
						if [ "$city_choice" -lt 1 ] || [ "$city_choice" -gt "$COUNTCITIES" ]; then
							printf "\\n\\e[31mPlease enter a number between 1 and %s${CLEARFORMAT}\\n" "$COUNTCITIES"
						else
							cityname="$(echo "$LISTCITIES" | sed -n "$city_choice"p)"
							if [ "$vpnprovider" = "NordVPN" ]; then
								cityid="$(getCityID "$countrydata" "$countryname" "$cityname")"
							fi
							printf "\\n"
							break
						fi
					fi
				done
			fi
		fi
	
	if [ "$exitmenu" != "exit" ]; then
		GLOBAL_VPN_NO="$vpnnum"
		GLOBAL_VPN_PROVIDER="$vpnprovider"
		GLOBAL_VPN_PROT="$vpnprot"
		GLOBAL_VPN_TYPE="$vpntype"
		GLOBAL_COUNTRY_NAME="$countryname"
		GLOBAL_COUNTRY_ID="$countryid"
		GLOBAL_CITY_NAME="$cityname"
		GLOBAL_CTIY_ID="$cityid"
		return 0
	else
		return 1
	fi
}

SetScheduleParameters(){
	exitmenu=""
	vpnnum=""
	formattype=""
	crudays=""
	crudaysvalidated=""
	cruhours=""
	crumins=""
	
	while true; do
		printf "\\n${BOLD}Please enter the VPN client number (pick from list):${CLEARFORMAT}  "
		read -r vpn_choice
		
		if [ "$vpn_choice" = "e" ]; then
			exitmenu="exit"
			break
		elif ! Validate_Number "$vpn_choice"; then
			printf "\\n\\e[31mPlease enter a valid number (pick from list)${CLEARFORMAT}\\n"
		else
			if [ "$vpn_choice" -lt 1 ] || [ "$vpn_choice" -gt 5 ]; then
				printf "\\n\\e[31mPlease enter a number between 1 and 5${CLEARFORMAT}\\n"
			else
				vpnnum="$vpn_choice"
				printf "\\n"
				break
			fi
		fi
	done
	
	if [ "$exitmenu" != "exit" ]; then
		if [ "$(grep "vpn${vpnnum}_managed" "$SCRIPT_CONF" | cut -f2 -d"=")" = "false" ]; then
			Print_Output false "VPN client $vpnnum is not managed, cannot enable schedule" "$ERR"
			return 1
		fi
		while true; do
			printf "\\n${BOLD}Please choose which day(s) to update VPN configuration (0-6, * for every day, or comma separated days):${CLEARFORMAT}  "
			read -r day_choice
			
			if [ "$day_choice" = "e" ]; then
				exitmenu="exit"
				break
			elif [ "$day_choice" = "*" ]; then
				crudays="$day_choice"
				printf "\\n"
				break
			elif [ -z "$day_choice" ]; then
				printf "\\n\\e[31mPlease enter a valid number (0-6) or comma separated values${CLEARFORMAT}\\n"
			else
				crudaystmp="$(echo "$day_choice" | sed "s/,/ /g")"
				crudaysvalidated="true"
				for i in $crudaystmp; do
					if ! Validate_Number "$i"; then
						printf "\\n\\e[31mPlease enter a valid number (0-6) or comma separated values${CLEARFORMAT}\\n"
						crudaysvalidated="false"
						break
					else
						if [ "$i" -lt 0 ] || [ "$i" -gt 6 ]; then
							printf "\\n\\e[31mPlease enter a number between 0 and 6 or comma separated values${CLEARFORMAT}\\n"
							crudaysvalidated="false"
							break
						fi
					fi
				done
				if [ "$crudaysvalidated" = "true" ]; then
					crudays="$day_choice"
					printf "\\n"
					break
				fi
			fi
		done
	fi
	
	if [ "$exitmenu" != "exit" ]; then
		while true; do
			printf "\\n${BOLD}Please choose the format to specify the hour/minute(s) to update VPN configuration:${CLEARFORMAT}\\n"
			printf "    1. Every X hours/minutes\\n"
			printf "    2. Custom\\n\\n"
			printf "Choose an option:  "
			read -r formatmenu
			
			case "$formatmenu" in
				1)
					formattype="everyx"
					printf "\\n"
					break
				;;
				2)
					formattype="custom"
					printf "\\n"
					break
				;;
				e)
					exitmenu="exit"
					break
				;;
				*)
					printf "\\n\\e[31mPlease enter a valid choice (1-2)${CLEARFORMAT}\\n"
				;;
			esac
		done
	fi
	
	if [ "$exitmenu" != "exit" ]; then
		if [ "$formattype" = "everyx" ]; then
			while true; do
				printf "\\n${BOLD}Please choose whether to specify every X hours or every X minutes to update VPN configuration:${CLEARFORMAT}\\n"
				printf "    1. Hours\\n"
				printf "    2. Minutes\\n\\n"
				printf "Choose an option:  "
				read -r formatmenu
				
				case "$formatmenu" in
					1)
						formattype="hours"
						printf "\\n"
						break
					;;
					2)
						formattype="mins"
						printf "\\n"
						break
					;;
					e)
						exitmenu="exit"
						break
					;;
					*)
						printf "\\n\\e[31mPlease enter a valid choice (1-2)${CLEARFORMAT}\\n"
					;;
				esac
			done
		fi
	fi
	
	if [ "$exitmenu" != "exit" ]; then
		if [ "$formattype" = "hours" ]; then
			while true; do
				printf "\\n${BOLD}Please choose how often to update VPN configuration (every X hours, where X is 1-24):${CLEARFORMAT}  "
				read -r hour_choice
				
				if [ "$hour_choice" = "e" ]; then
					exitmenu="exit"
					break
				elif ! Validate_Number "$hour_choice"; then
						printf "\\n\\e[31mPlease enter a valid number (1-24)${CLEARFORMAT}\\n"
				elif [ "$hour_choice" -lt 1 ] || [ "$hour_choice" -gt 24 ]; then
					printf "\\n\\e[31mPlease enter a number between 1 and 24${CLEARFORMAT}\\n"
				else
					if [ "$hour_choice" -eq 24 ]; then
						cruhours=0
						crumins=0
						printf "\\n"
						break
					else
						cruhours="*/$hour_choice"
						crumins=0
						printf "\\n"
						break
					fi
				fi
			done
		elif [ "$formattype" = "mins" ]; then
			while true; do
				printf "\\n${BOLD}Please choose how often to update VPN configuration (every X minutes, where X is 1-30):${CLEARFORMAT}  "
				read -r min_choice
				
				if [ "$min_choice" = "e" ]; then
					exitmenu="exit"
					break
				elif ! Validate_Number "$min_choice"; then
						printf "\\n\\e[31mPlease enter a valid number (1-30)${CLEARFORMAT}\\n"
				elif [ "$min_choice" -lt 1 ] || [ "$min_choice" -gt 30 ]; then
					printf "\\n\\e[31mPlease enter a number between 1 and 30${CLEARFORMAT}\\n"
				else
					crumins="*/$min_choice"
					cruhours="*"
					printf "\\n"
					break
				fi
			done
		fi
	fi
	
	if [ "$exitmenu" != "exit" ]; then
		if [ "$formattype" = "custom" ]; then
			while true; do
				printf "\\n${BOLD}Please choose which hour(s) to update VPN configuration (0-23, * for every hour, or comma separated hours):${CLEARFORMAT}  "
				read -r hour_choice
				
				if [ "$hour_choice" = "e" ]; then
					exitmenu="exit"
					break
				elif [ "$hour_choice" = "*" ]; then
					cruhours="$hour_choice"
					printf "\\n"
					break
				else
					cruhourstmp="$(echo "$hour_choice" | sed "s/,/ /g")"
					cruhoursvalidated="true"
					for i in $cruhourstmp; do
						if ! Validate_Number "$i"; then
							printf "\\n\\e[31mPlease enter a valid number (0-23) or comma separated values${CLEARFORMAT}\\n"
							cruhoursvalidated="false"
							break
						else
							if [ "$i" -lt 0 ] || [ "$i" -gt 23 ]; then
								printf "\\n\\e[31mPlease enter a number between 0 and 23 or comma separated values${CLEARFORMAT}\\n"
								cruhoursvalidated="false"
								break
							fi
						fi
					done
					if [ "$cruhoursvalidated" = "true" ]; then
						cruhours="$hour_choice"
						printf "\\n"
						break
					fi
				fi
			done
		fi
	fi
	
	if [ "$exitmenu" != "exit" ]; then
		if [ "$formattype" = "custom" ]; then
			while true; do
				printf "\\n${BOLD}Please choose which minutes(s) to update VPN configuration (0-59, * for every minute, or comma separated minutes):${CLEARFORMAT}  "
				read -r min_choice
				
				if [ "$min_choice" = "e" ]; then
					exitmenu="exit"
					break
				elif [ "$min_choice" = "*" ]; then
					crumins="$min_choice"
					printf "\\n"
					break
				else
					cruminstmp="$(echo "$min_choice" | sed "s/,/ /g")"
					cruminsvalidated="true"
					for i in $cruminstmp; do
						if ! Validate_Number "$i"; then
							printf "\\n\\e[31mPlease enter a valid number (0-59) or comma separated values${CLEARFORMAT}\\n"
							cruminsvalidated="false"
							break
						else
							if [ "$i" -lt 0 ] || [ "$i" -gt 59 ]; then
								printf "\\n\\e[31mPlease enter a number between 0 and 59 or comma separated values${CLEARFORMAT}\\n"
								cruminsvalidated="false"
								break
							fi
						fi
					done
					if [ "$cruminsvalidated" = "true" ]; then
						crumins="$min_choice"
						printf "\\n"
						break
					fi
				fi
			done
		fi
	fi
	
	if [ "$exitmenu" != "exit" ]; then
		GLOBAL_VPN_NO="$vpnnum"
		GLOBAL_CRU_DAYNUMBERS="$crudays"
		GLOBAL_CRU_HOURS="$cruhours"
		GLOBAL_CRU_MINS="$crumins"
		return 0
	else
		return 1
	fi
}

SetVPNCustomSettings(){
	VPN_NO="$1"
	vpncustomoptions='remote-random
resolv-retry infinite
remote-cert-tls server
ping 15
ping-restart 0
ping-timer-rem
persist-key
persist-tun
reneg-sec 0
fast-io
disable-occ
mute-replay-warnings
auth-nocache
sndbuf 524288
rcvbuf 524288
push "sndbuf 524288"
push "rcvbuf 524288"
pull-filter ignore "auth-token"
pull-filter ignore "ifconfig-ipv6"
pull-filter ignore "route-ipv6"'
	
	if [ "$VPN_PROT_SHORT" = "UDP" ]; then
		vpncustomoptions="$vpncustomoptions
explicit-exit-notify 3"
	fi
	
	if [ "$VPN_PROVIDER" = "NordVPN" ]; then
		vpncustomoptions="$vpncustomoptions
tun-mtu 1500
tun-mtu-extra 32
mssfix 1450"
	fi
	
	if [ "$(Firmware_Number_Check "$(nvram get buildno)")" -lt "$(Firmware_Number_Check 386.3)" ]; then
		vpncustomoptionsbase64="$(echo "$vpncustomoptions" | head -c -1 | openssl base64 -A)"
		
		if [ "$(/bin/uname -m)" = "aarch64" ]; then
			nvram set vpn_client"$VPN_NO"_cust2="$(echo "$vpncustomoptionsbase64" | cut -c0-255)"
			nvram set vpn_client"$VPN_NO"_cust21="$(echo "$vpncustomoptionsbase64" | cut -c256-510)"
			nvram set vpn_client"$VPN_NO"_cust22="$(echo "$vpncustomoptionsbase64" | cut -c511-765)"
		elif [ "$(uname -o)" = "ASUSWRT-Merlin" ]; then
			nvram set vpn_client"$VPN_NO"_cust2="$vpncustomoptionsbase64"
		else
			nvram set vpn_client"$VPN_NO"_custom="$vpncustomoptions"
		fi
		nvram commit
	else
		printf "%s" "$vpncustomoptions" > /jffs/openvpn/vpn_client"$VPN_NO"_custom3
	fi
}

PressEnter(){
	while true; do
		printf "Press enter to continue..."
		read -r key
		case "$key" in
			*)
				break
			;;
		esac
	done
	return 0
}

ScriptHeader(){
	clear
	printf "\\n"
	printf "${BOLD}#######################################################${CLEARFORMAT}\\n"
	printf "${BOLD}##                                                   ##${CLEARFORMAT}\\n"
	printf "${BOLD}##   __   __ _ __   _ __   _ __ ___    __ _  _ __    ##${CLEARFORMAT}\\n"
	printf "${BOLD}##   \ \ / /| '_ \ | '_ \ | '_   _ \  / _  || '__|   ##${CLEARFORMAT}\\n"
	printf "${BOLD}##    \ V / | |_) || | | || | | | | || (_| || |      ##${CLEARFORMAT}\\n"
	printf "${BOLD}##     \_/  | .__/ |_| |_||_| |_| |_| \__, ||_|      ##${CLEARFORMAT}\\n"
	printf "${BOLD}##          | |                        __/ |         ##${CLEARFORMAT}\\n"
	printf "${BOLD}##          |_|                       |___/          ##${CLEARFORMAT}\\n"
	printf "${BOLD}##                                                   ##${CLEARFORMAT}\\n"
	printf "${BOLD}##                 %s on %-11s             ##${CLEARFORMAT}\\n" "$SCRIPT_VERSION" "$ROUTER_MODEL"
	printf "${BOLD}##                                                   ##${CLEARFORMAT}\\n"
	printf "${BOLD}##         https://github.com/jackyaz/vpnmgr         ##${CLEARFORMAT}\\n"
	printf "${BOLD}##                                                   ##${CLEARFORMAT}\\n"
	printf "${BOLD}#######################################################${CLEARFORMAT}\\n"
	printf "\\n"
}

MainMenu(){
	printf "WebUI for %s is available at:\\n${SETTING}%s${CLEARFORMAT}\\n\\n" "$SCRIPT_NAME" "$(Get_WebUI_URL)"
	printf "1.    List VPN client configurations\\n"
	printf "1l.   List NordVPN clients with server load percentages\\n\\n"
	printf "2.    Update configuration for a managed VPN client\\n\\n"
	printf "3.    Toggle management for a VPN client\\n\\n"
	printf "4.    Search for new recommended server/reload server\\n\\n"
	printf "5.    Toggle scheduled VPN client update/reload\\n"
	printf "6.    Update schedule for a VPN client\\n\\n"
	printf "7.    Toggle %s custom settings for a VPN client\\n\\n" "$SCRIPT_NAME"
	printf "r.    Refresh cached data from VPN providers\\n\\n"
	printf "u.    Check for updates\\n"
	printf "uf.   Update %s with latest version (force)\\n\\n" "$SCRIPT_NAME"
	printf "e.    Exit %s\\n\\n" "$SCRIPT_NAME"
	printf "z.    Uninstall %s\\n" "$SCRIPT_NAME"
	printf "\\n"
	printf "${BOLD}###################################################${CLEARFORMAT}\\n"
	printf "\\n"
	
	while true; do
		printf "Choose an option:  "
		read -r menu
		case "$menu" in
			1)
				printf "\\n"
				ScriptHeader
				ListVPNClients false show
				PressEnter
				break
			;;
			1l)
				printf "\\n"
				ScriptHeader
				ListVPNClients true show
				PressEnter
				break
			;;
			2)
				printf "\\n"
				if Check_Lock menu; then
					Menu_UpdateVPN
				fi
				PressEnter
				break
			;;
			3)
				printf "\\n"
				if SetVPNClient show; then
					if [ "$(grep "vpn${GLOBAL_VPN_NO}_managed" "$SCRIPT_CONF" | cut -f2 -d"=")" = "false" ]; then
						ManageVPN "$GLOBAL_VPN_NO"
					else
						UnmanageVPN "$GLOBAL_VPN_NO"
					fi
				fi
				PressEnter
				break
			;;
			4)
				printf "\\n"
				if Check_Lock menu; then
					if SetVPNClient hide; then
						if [ "$(grep "vpn${GLOBAL_VPN_NO}_managed" "$SCRIPT_CONF" | cut -f2 -d"=")" = "false" ]; then
							Print_Output false "VPN client $GLOBAL_VPN_NO is not managed, cannot search for new server" "$ERR"
							break
						fi
						UpdateVPNConfig unattended "$GLOBAL_VPN_NO"
					fi
					Clear_Lock
				fi
				PressEnter
				break
			;;
			5)
				printf "\\n"
				if SetVPNClient hide; then
					if [ "$(grep "vpn${GLOBAL_VPN_NO}_managed" "$SCRIPT_CONF" | cut -f2 -d"=")" = "false" ]; then
						Print_Output false "VPN client $GLOBAL_VPN_NO is not managed, cannot enable schedule" "$ERR"
						break
					fi
					if [ "$(grep "vpn${GLOBAL_VPN_NO}_schenabled" "$SCRIPT_CONF" | cut -f2 -d"=")" = "false" ]; then
						ScheduleVPN "$GLOBAL_VPN_NO"
					else
						CancelScheduleVPN "$GLOBAL_VPN_NO"
					fi
				fi
				PressEnter
				break
			;;
			6)
				printf "\\n"
				Menu_ScheduleVPN
				PressEnter
				break
			;;
			7)
				printf "\\n"
				if SetVPNClient hide; then
					if [ "$(grep "vpn${GLOBAL_VPN_NO}_managed" "$SCRIPT_CONF" | cut -f2 -d"=")" = "false" ]; then
						Print_Output false "VPN client $GLOBAL_VPN_NO is not managed, cannot apply custom settings" "$ERR"
						break
					fi
					if [ "$(grep "vpn${GLOBAL_VPN_NO}_customsettings" "$SCRIPT_CONF" | cut -f2 -d"=")" = "false" ]; then
						sed -i 's/^vpn'"$GLOBAL_VPN_NO"'_customsettings.*$/vpn'"$GLOBAL_VPN_NO"'_customsettings=true/' "$SCRIPT_CONF"
						SetVPNCustomSettings "$GLOBAL_VPN_NO"
					else
						sed -i 's/^vpn'"$GLOBAL_VPN_NO"'_customsettings.*$/vpn'"$GLOBAL_VPN_NO"'_customsettings=false/' "$SCRIPT_CONF"
					fi
				fi
				PressEnter
				break
			;;
			r)
				printf "\\n"
				getCountryData
				getOVPNArchives
				PressEnter
				break
			;;
			u)
				printf "\\n"
				if Check_Lock menu; then
					Update_Version
					Clear_Lock
				fi
				PressEnter
				break
			;;
			uf)
				printf "\\n"
				if Check_Lock menu; then
					Update_Version force
					Clear_Lock
				fi
				PressEnter
				break
			;;
			e)
				ScriptHeader
				printf "\\n${BOLD}Thanks for using %s!${CLEARFORMAT}\\n\\n\\n" "$SCRIPT_NAME"
				exit 0
			;;
			z)
				while true; do
					printf "\\n${BOLD}Are you sure you want to uninstall %s? (y/n)${CLEARFORMAT}  " "$SCRIPT_NAME"
					read -r confirm
					case "$confirm" in
						y|Y)
							Menu_Uninstall
							exit 0
						;;
						*)
							break
						;;
					esac
				done
			;;
			*)
				printf "\\nPlease choose a valid option\\n\\n"
			;;
		esac
	done
	
	ScriptHeader
	MainMenu
}

Menu_UpdateVPN(){
	ScriptHeader
	ListVPNClients false hide
	printf "Choose options as follows:\\n"
	printf "    - VPN client (pick from list)\\n"
	printf "    - VPN provider (pick from list)\\n"
	printf "    - type of VPN (pick from list)\\n"
	printf "    - protocol (pick from list)\\n"
	printf "    - country/city of VPN Server (pick from list)\\n"
	printf "\\n"
	printf "${BOLD}#########################################################${CLEARFORMAT}\\n"
	
	if SetVPNParameters; then
		VPN_PROT_SHORT="$(echo "$GLOBAL_VPN_PROT" | cut -f2 -d'_' | tr "a-z" "A-Z")"
		VPN_TYPE_SHORT="$(echo "$GLOBAL_VPN_TYPE" | cut -f2 -d'_')"
		if [ "$VPN_TYPE_SHORT" = "p2p" ]; then
			VPN_TYPE_SHORT="$(echo "$VPN_TYPE_SHORT" | tr "a-z" "A-Z")"
		else
			VPN_TYPE_SHORT="$(echo "$VPN_TYPE_SHORT" | awk '{print toupper(substr($0,0,1))tolower(substr($0,2))}')"
		fi
		
		sed -i 's/^vpn'"$GLOBAL_VPN_NO"'_provider.*$/vpn'"$GLOBAL_VPN_NO"'_provider='"$GLOBAL_VPN_PROVIDER"'/' "$SCRIPT_CONF"
		sed -i 's/^vpn'"$GLOBAL_VPN_NO"'_type.*$/vpn'"$GLOBAL_VPN_NO"'_type='"$VPN_TYPE_SHORT"'/' "$SCRIPT_CONF"
		sed -i 's/^vpn'"$GLOBAL_VPN_NO"'_protocol.*$/vpn'"$GLOBAL_VPN_NO"'_protocol='"$VPN_PROT_SHORT"'/' "$SCRIPT_CONF"
		sed -i 's/^vpn'"$GLOBAL_VPN_NO"'_countryname.*$/vpn'"$GLOBAL_VPN_NO"'_countryname='"$GLOBAL_COUNTRY_NAME"'/' "$SCRIPT_CONF"
		sed -i 's/^vpn'"$GLOBAL_VPN_NO"'_countryid.*$/vpn'"$GLOBAL_VPN_NO"'_countryid='"$GLOBAL_COUNTRY_ID"'/' "$SCRIPT_CONF"
		sed -i 's/^vpn'"$GLOBAL_VPN_NO"'_cityname.*$/vpn'"$GLOBAL_VPN_NO"'_cityname='"$GLOBAL_CITY_NAME"'/' "$SCRIPT_CONF"
		sed -i 's/^vpn'"$GLOBAL_VPN_NO"'_cityid.*$/vpn'"$GLOBAL_VPN_NO"'_cityid='"$GLOBAL_CTIY_ID"'/' "$SCRIPT_CONF"
		UpdateVPNConfig "$GLOBAL_VPN_NO"
	fi
	Clear_Lock
}

Menu_ScheduleVPN(){
	ScriptHeader
	ListVPNClients false hide
	printf "Choose options as follows:\\n"
	printf "    - VPN client (pick from list)\\n"
	printf "    - day(s) to update [0-6]\\n"
	printf "    - hour(s) to update [0-23]\\n"
	printf "    - minute(s) to update [0-59]\\n"
	printf "\\n"
	printf "${BOLD}#########################################################${CLEARFORMAT}\\n"
	
	if SetScheduleParameters; then
		sed -i 's/^vpn'"$GLOBAL_VPN_NO"'_schenabled.*$/vpn'"$GLOBAL_VPN_NO"'_schenabled=true/' "$SCRIPT_CONF"
		sed -i 's/^vpn'"$GLOBAL_VPN_NO"'_schdays.*$/vpn'"$GLOBAL_VPN_NO"'_schdays='"$(echo "$GLOBAL_CRU_DAYNUMBERS" | sed 's/0/Sun/;s/1/Mon/;s/2/Tues/;s/3/Wed/;s/4/Thurs/;s/5/Fri/;s/6/Sat/;')"'/' "$SCRIPT_CONF"
		sed -i 's~^vpn'"$GLOBAL_VPN_NO"'_schhours.*$~vpn'"$GLOBAL_VPN_NO"'_schhours='"$GLOBAL_CRU_HOURS"'~' "$SCRIPT_CONF"
		sed -i 's~^vpn'"$GLOBAL_VPN_NO"'_schmins.*$~vpn'"$GLOBAL_VPN_NO"'_schmins='"$GLOBAL_CRU_MINS"'~' "$SCRIPT_CONF"
		ScheduleVPN "$GLOBAL_VPN_NO"
	fi
}

Check_Requirements(){
	CHECKSFAILED="false"
	
	if [ "$(nvram get jffs2_scripts)" -ne 1 ]; then
		nvram set jffs2_scripts=1
		nvram commit
		Print_Output true "Custom JFFS Scripts enabled" "$WARN"
	fi
	
	if [ ! -f /opt/bin/opkg ]; then
		Print_Output false "Entware not detected!" "$ERR"
		CHECKSFAILED="true"
	fi
	
	if ! Firmware_Version_Check ; then
		Print_Output false "Unsupported firmware version detected" "$ERR"
		Print_Output false "$SCRIPT_NAME requires Merlin 384.15/384.13_4 or Fork 43E5 (or later)" "$ERR"
		CHECKSFAILED="true"
	fi
	
	if [ "$CHECKSFAILED" = "false" ]; then
		Print_Output false "Installing required packages from Entware" "$PASS"
		opkg update
		opkg install jq
		opkg install p7zip
		opkg install column
		return 0
	else
		return 1
	fi
}

Menu_Install(){
	ScriptHeader
	Print_Output true "Welcome to $SCRIPT_NAME $SCRIPT_VERSION, a script by h0me5k1n and JackYaz"
	sleep 1
	
	Print_Output false "Checking your router meets the requirements for $SCRIPT_NAME"
	
	if ! Check_Requirements; then
		Print_Output false "Requirements for $SCRIPT_NAME not met, please see above for the reason(s)" "$CRIT"
		PressEnter
		Clear_Lock
		rm -f "/jffs/scripts/$SCRIPT_NAME" 2>/dev/null
		exit 1
	fi
	
	Create_Dirs
	Conf_Exists
	Create_Symlinks
	Auto_Cron create 2>/dev/null
	Auto_Startup create 2>/dev/null
	Auto_ServiceEvent create 2>/dev/null
	
	Update_File vpnmgr_www.asp
	Update_File shared-jy.tar.gz
	
	getCountryData
	getOVPNArchives
	
	Shortcut_Script create
	Clear_Lock
	
	ScriptHeader
	MainMenu
}

Menu_Startup(){
	if [ -z "$1" ]; then
		Print_Output true "Missing argument for startup, not starting $SCRIPT_NAME" "$WARN"
		exit 1
	elif [ "$1" != "force" ]; then
		if [ ! -f "$1/entware/bin/opkg" ]; then
			Print_Output true "$1 does not contain Entware, not starting $SCRIPT_NAME" "$WARN"
			exit 1
		else
			Print_Output true "$1 contains Entware, starting $SCRIPT_NAME" "$WARN"
		fi
	fi
	
	NTP_Ready
	
	Check_Lock
	
	if [ "$1" != "force" ]; then
		sleep 25
	fi
	
	Create_Dirs
	Conf_Exists
	Set_Version_Custom_Settings local "$SCRIPT_VERSION"
	Set_Version_Custom_Settings server "$SCRIPT_VERSION"
	Create_Symlinks
	Auto_Cron create 2>/dev/null
	Auto_Startup create 2>/dev/null
	Auto_ServiceEvent create 2>/dev/null
	Shortcut_Script create
	Mount_WebUI
	Clear_Lock
}

Menu_Uninstall(){
	Print_Output true "Removing $SCRIPT_NAME..." "$PASS"
	
	Auto_Cron delete 2>/dev/null
	Auto_Startup delete 2>/dev/null
	Auto_ServiceEvent delete 2>/dev/null
	
	LOCKFILE=/tmp/addonwebui.lock
	FD=386
	eval exec "$FD>$LOCKFILE"
	flock -x "$FD"
	Get_WebUI_Page "$SCRIPT_DIR/vpnmgr_www.asp"
	if [ -n "$MyPage" ] && [ "$MyPage" != "none" ] && [ -f /tmp/menuTree.js ]; then
		sed -i "\\~$MyPage~d" /tmp/menuTree.js
		umount /www/require/modules/menuTree.js
		mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
		rm -f "$SCRIPT_WEBPAGE_DIR/$MyPage"
		rm -f "$SCRIPT_WEBPAGE_DIR/$(echo $MyPage | cut -f1 -d'.').title"
	fi
	flock -u "$FD"
	rm -f "$SCRIPT_DIR/vpnmgr_www.asp" 2>/dev/null
	
	SETTINGSFILE="/jffs/addons/custom_settings.txt"
	sed -i '/vpnmgr_version_local/d' "$SETTINGSFILE"
	sed -i '/vpnmgr_version_server/d' "$SETTINGSFILE"
	
	rm -rf "$SCRIPT_WEB_DIR" 2>/dev/null
	rm -rf "$SCRIPT_DIR" 2>/dev/null
	
	Shortcut_Script delete
	
	rm -f "/jffs/scripts/$SCRIPT_NAME" 2>/dev/null
	Clear_Lock
	Print_Output true "Uninstall completed" "$PASS"
}

NTP_Ready(){
	if [ "$(nvram get ntp_ready)" -eq 0 ]; then
		ntpwaitcount=0
		while [ "$(nvram get ntp_ready)" -eq 0 ] && [ "$ntpwaitcount" -lt 600 ]; do
			ntpwaitcount="$((ntpwaitcount + 30))"
			Print_Output true "Waiting for NTP to sync..." "$WARN"
			sleep 30
		done
		if [ "$ntpwaitcount" -ge 600 ]; then
			Print_Output true "NTP failed to sync after 10 minutes. Please resolve!" "$CRIT"
			Clear_Lock
			exit 1
		else
			Print_Output true "NTP synced, $SCRIPT_NAME will now continue" "$PASS"
			Clear_Lock
		fi
	fi
}

### function based on @Adamm00's Skynet USB wait function ###
Entware_Ready(){
	if [ ! -f /opt/bin/opkg ]; then
		Check_Lock
		sleepcount=1
		while [ ! -f /opt/bin/opkg ] && [ "$sleepcount" -le 10 ]; do
			Print_Output true "Entware not found, sleeping for 10s (attempt $sleepcount of 10)" "$ERR"
			sleepcount="$((sleepcount + 1))"
			sleep 10
		done
		if [ ! -f /opt/bin/opkg ]; then
			Print_Output true "Entware not found and is required for $SCRIPT_NAME to run, please resolve" "$CRIT"
			Clear_Lock
			exit 1
		else
			Print_Output true "Entware found, $SCRIPT_NAME will now continue" "$PASS"
			Clear_Lock
		fi
	fi
}
### ###

Show_About(){
	cat <<EOF
About
  $SCRIPT_NAME enables easy management of your VPN Client connections for
various VPN providers on AsusWRT-Merlin. The following VPN Providers are
currently supported: NordVPN, Private Internet Access (PIA) and WeVPN.
NordVPN clients can be configured to automatically refresh on a scheduled
basis with the recommended server as provided by the NordVPN API.
License
  $SCRIPT_NAME is free to use under the GNU General Public License
  version 3 (GPL-3.0) https://opensource.org/licenses/GPL-3.0
Help & Support
  https://www.snbforums.com/forums/asuswrt-merlin-addons.60/?prefix_id=11
Source code
  https://github.com/jackyaz/$SCRIPT_NAME
EOF
	printf "\\n"
}
### ###

### function based on @dave14305's FlexQoS show_help function ###
Show_Help(){
	cat <<EOF
Available commands:
  $SCRIPT_NAME about              explains functionality
  $SCRIPT_NAME update             checks for updates
  $SCRIPT_NAME forceupdate        updates to latest version (force update)
  $SCRIPT_NAME startup force      runs startup actions such as mount WebUI tab
  $SCRIPT_NAME install            installs script
  $SCRIPT_NAME uninstall          uninstalls script
  $SCRIPT_NAME updatevpn X        refresh VPN Client X with the latest server (NordVPN) and settings
  $SCRIPT_NAME refreshcacheddata  triggers a redownload of ovpn file archives from PIA and WeVPN
  $SCRIPT_NAME ntpredirect        apply firewall rules to intercept and redirect NTP traffic
  $SCRIPT_NAME develop            switch to development branch
  $SCRIPT_NAME stable             switch to stable branch
EOF
	printf "\\n"
}
### ###

if [ -z "$1" ]; then
	NTP_Ready
	Entware_Ready
	if [ ! -f /opt/bin/7za ]; then
		opkg update
		opkg install p7zip
		opkg install column
	fi
	Create_Dirs
	Conf_Exists
	Auto_Cron create 2>/dev/null
	Auto_Startup create 2>/dev/null
	Auto_ServiceEvent create 2>/dev/null
	Shortcut_Script create
	if [ ! -f "$SCRIPT_DIR/nordvpn_countrydata" ]; then
		getCountryData
	fi
	if [ "$(/usr/bin/find "$OVPN_ARCHIVE_DIR" -name "*.zip" | wc -l)" -lt 4 ]; then
		getOVPNArchives
	fi
	
	Create_Symlinks
	ScriptHeader
	MainMenu
	exit 0
fi

case "$1" in
	install)
		Check_Lock
		Menu_Install
		exit 0
	;;
	updatevpn)
		NTP_Ready
		Entware_Ready
		UpdateVPNConfig unattended "$2"
		exit 0
	;;
	refreshcacheddata)
		NTP_Ready
		Entware_Ready
		getCountryData
		getOVPNArchives
		exit 0
	;;
	startup)
		Menu_Startup "$2"
		exit 0
	;;
	service_event)
		if [ "$2" = "start" ] && [ "$3" = "$SCRIPT_NAME" ]; then
			Conf_FromSettings
			for i in 1 2 3 4 5; do
				if [ "$(grep "vpn${i}_managed" "$SCRIPT_CONF" | cut -f2 -d"=")" = "true" ]; then
					ManageVPN "$i"
					if [ "$(grep "vpn${i}_schenabled" "$SCRIPT_CONF" | cut -f2 -d"=")" = "true" ]; then
						ScheduleVPN "$i"
					elif [ "$(grep "vpn${i}_schenabled" "$SCRIPT_CONF" | cut -f2 -d"=")" = "false" ]; then
						CancelScheduleVPN "$i"
					fi
					UpdateVPNConfig unattended "$i"
				elif [ "$(grep "vpn${i}_managed" "$SCRIPT_CONF" | cut -f2 -d"=")" = "false" ]; then
					UnmanageVPN "$i"
				fi
			done
			exit 0
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}refreshcacheddata" ]; then
			rm -f /tmp/detect_vpnmgr.js
			Check_Lock webui
			sleep 3
			echo 'var refreshcacheddatastatus = "InProgress";' > /tmp/detect_vpnmgr.js
			sleep 1
			getCountryData
			sleep 1
			getOVPNArchives
			sleep 1
			echo 'var refreshcacheddatastatus = "Done";' > /tmp/detect_vpnmgr.js
			Clear_Lock
			exit 0
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}getserverload" ]; then
			rm -f /tmp/vpnmgrserverloads
			for i in 1 2 3 4 5; do
				VPN_CLIENTDESC="$(nvram get vpn_client"$i"_desc)"
				if ! echo "$VPN_CLIENTDESC" | grep -iq "nordvpn"; then
					continue
				fi
				printf "var vpn%s_serverload=%s;\\r\\n" "$i" "$(getServerLoad "$VPN_CLIENTDESC")" >> /tmp/vpnmgrserverloads.tmp
			done
			mv /tmp/vpnmgrserverloads.tmp /tmp/vpnmgrserverloads
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}checkupdate" ]; then
			Update_Check
			exit 0
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}doupdate" ]; then
			Update_Version force
			exit 0
		fi
		exit 0
	;;
	update)
		Update_Version
		exit 0
	;;
	forceupdate)
		Update_Version force
		exit 0
	;;
	setversion)
		Set_Version_Custom_Settings local "$SCRIPT_VERSION"
		Set_Version_Custom_Settings server "$SCRIPT_VERSION"
		if [ ! -f /opt/bin/7za ]; then
			opkg update
			opkg install p7zip
			opkg install column
		fi
		Create_Dirs
		Conf_Exists
		Auto_Cron create 2>/dev/null
		Auto_Startup create 2>/dev/null
		Auto_ServiceEvent create 2>/dev/null
		Shortcut_Script create
		if [ ! -f "$SCRIPT_DIR/nordvpn_countrydata" ]; then
			getCountryData
		fi
		if [ "$(/usr/bin/find "$OVPN_ARCHIVE_DIR" -name "*.zip" | wc -l)" -lt 4 ]; then
			getOVPNArchives
		fi
		Create_Symlinks
		exit 0
	;;
	postupdate)
		if [ ! -f /opt/bin/7za ]; then
			opkg update
			opkg install p7zip
			opkg install column
		fi
		Create_Dirs
		Conf_Exists
		Auto_Cron create 2>/dev/null
		Auto_Startup create 2>/dev/null
		Auto_ServiceEvent create 2>/dev/null
		Shortcut_Script create
		if [ ! -f "$SCRIPT_DIR/nordvpn_countrydata" ]; then
			getCountryData
		fi
		if [ "$(/usr/bin/find "$OVPN_ARCHIVE_DIR" -name "*.zip" | wc -l)" -lt 4 ]; then
			getOVPNArchives
		fi
		Create_Symlinks
		exit 0
	;;
	about)
		ScriptHeader
		Show_About
		exit 0
	;;
	help)
		ScriptHeader
		Show_Help
		exit 0
	;;
	develop)
		SCRIPT_BRANCH="develop"
		SCRIPT_REPO="https://raw.githubusercontent.com/jackyaz/$SCRIPT_NAME/$SCRIPT_BRANCH"
		Update_Version force
		exit 0
	;;
	stable)
		SCRIPT_BRANCH="master"
		SCRIPT_REPO="https://raw.githubusercontent.com/jackyaz/$SCRIPT_NAME/$SCRIPT_BRANCH"
		Update_Version force
		exit 0
	;;
	uninstall)
		Menu_Uninstall
		exit 0
	;;
	*)
		ScriptHeader
		Print_Output false "Command not recognised." "$ERR"
		Print_Output false "For a list of available commands run: $SCRIPT_NAME help"
		exit 1
	;;
esac
