#!/usr/bin/env bash
##################################################
### Script: uConsole_hn                        ###
### Version 0.3.3                              ###
### Made by Kostya Shutenko                    ###
### Contact address: kostya.shutenko@gmail.com ###
##################################################

BIN_PATH=$(dirname $(readlink -f $0))
NORMAL='\033[0m'
BOLD='\033[1m'
CYAN='\e[0;36m'
RED='\033[0;31m'
GREEN='\033[0;32m'

function updatesCheck {
    remoteVer=`curl -s https://raw.githubusercontent.com/KeithSampson/uConsole/master/uConsole_hn.sh |grep "### Version" |head -n1 |sed s/[^0-9.]//g`
    currentVer=`cat $0 |grep "### Version" |head -n1 |sed s/[^0-9.]//g`

    echo -en "${BOLD}Current Version: $currentVer ${NORMAL}"
    echo ""
    echo -en "${BOLD}Remote Version: $remoteVer ${NORMAL}"
    echo ""

    if [[ $currentVer == $remoteVer ]]; then
        echo "$(date +%F_%H-%M-%S) - No updates"
    else
        wget -O uConsole_hn.sh_$remoteVer https://raw.githubusercontent.com/KeithSampson/uConsole/master/uConsole_hn.sh
        chmod +x uConsole_hn.sh_$remoteVer
        rm -f $0
        mv uConsole_hn.sh_$remoteVer uConsole_hn.sh
        echo "$(date +%F_%H-%M-%S) - Script uConsole_hn.sh updated to $remoteVer"
    fi                  
}

function configRecreate {
 declare -a SERVERS_LIST
    i=0
    until [[ $asStatus == 0 ]]; do
        until [[ $msStatus == 0 ]]; do
            echo -en "${CYAN}Enter new share path (in format //IP_ADDRESS/SHARE): ${NORMAL}"
            read mountServer
            if [[ `echo $mountServer |cut -c1-2` == '//' ]]; then
                SERVERS_LIST[$i]=$mountServer
                msStatus=0
                break 1
            else
                echo -en "${RED}Incorrect path: $mountServer. Please use format //IP_ADDRESS/SHARE${NORMAL}"
                echo ""
            fi
        done

        echo "Is it finish (y/N)"
        read asStatus
        if [[ $asStatus == 'y' || $asStatus == "Y" ]]; then
            asStatus=0
            break 1
        else
            echo "New one will be added"
            msStatus=1
            let i=i+1
        fi

    done


    echo -en "${CYAN}Enter default username for mount share folders: ${NORMAL}"
    read cifsUserName
    echo -en "${CYAN}Enter default password for mount share folders: ${NORMAL}"
    read cifsUserPwd
    echo -en "${CYAN}Enter domain for share user: ${NORMAL}"
    read cifsDomain
	
	echo -en "${CYAN}Enter VID with FTP server: ${NORMAL}"
	read VID

    echo -en "${BOLD}Config will be created with the follwing paramethers:${NORMAL}"
    echo ""
    echo -en "${BOLD}Servers with share: \"${SERVERS_LIST[*]}${NORMAL}\""
    echo ""
    echo -en "${BOLD}Username:${NORMAL} $cifsUserName"
    echo ""
    echo -en "${BOLD}Password:${NORMAL} $cifsUserPwd"
    echo ""
    echo -en "${BOLD}Domain:${NORMAL} $cifsDomain"
    echo ""
	echo -en "${BOLD}VPS with FTP server:${NORMAL} $VID"
	echo ""
    echo -en "${GREEN}Please confirm (Y/n): ${NORMAL}"
    read confirmConfAdd
    if [[ $confirmConfAdd == "n" || $confirmConfAdd == "N" ]]; then
        echo -en "${RED}Exit${NORMAL}"
        echo ""
        rm -rf ~/.uconsole
		rm -f /etc/vz/conf/$VID.mount
        exit 0
    fi

	mkdir -p ~/.uconsole/
	chmod -R 700 ~/.uconsole
    cp $BIN_PATH/sources/uconsole.conf-sample ~/.uconsole/uconsole.conf
    cp $BIN_PATH/sources/smb.conf-sample ~/.uconsole/smb.conf
    cp $BIN_PATH/sources/VID.mount-sample /etc/vz/conf/$VID.mount
	chmod +x /etc/vz/conf/$VID.mount

    sed -i "s|SERVERS_LIST|${SERVERS_LIST[*]}|" ~/.uconsole/uconsole.conf
    sed -i "s|FTP_VID|$VID|" ~/.uconsole/uconsole.conf
    sed -i "s|USER_NAME|$cifsUserName|" ~/.uconsole/uconsole.conf
    sed -i "s|USER_NAME|$cifsUserName|" ~/.uconsole/smb.conf
    sed -i "s|USER_PWD|$cifsUserPwd|" ~/.uconsole/uconsole.conf
    sed -i "s|USER_PWD|$cifsUserPwd|" ~/.uconsole/smb.conf
    sed -i "s|USER_DOMAIN|$cifsDomain|" ~/.uconsole/uconsole.conf
    sed -i "s|USER_DOMAIN|$cifsDomain|" ~/.uconsole/smb.conf
}

function shareMount {
echo -en "${GREEN}Do you want to mount share? (Y/n): ${NORMAL}"
    read confirmMount
    if [[ $confirmMount == "n" || $confirmMount == "N" ]]; then
        exit 5
    else
		if [[ $# != 0 ]]; then
            userAccount=$1
        else
			echo "Please select account for mount: "
			select userAccount in `ls /var/lib/vz/private/$VID/home/`
			do
				if [[ $userAccount == "" ]]; then
					echo -en "${RED}Account is not selected${NORMAL}"
					echo ""
					exit 2
				fi
				break
			done
		fi
		
		userAccountUID=`vzctl exec $VID id -u $userAccount`
		userAccountGID=`vzctl exec $VID id -g $userAccount`
		if [[ $userAccountUID == "" || $userAccountGID == "" ]]; then
			echo -en "${RED}ERROR: Can not get UID or GID${NORMAL}"
            echo ""
			exit 2
		fi

        echo "Select share server: "
        select shareServer in `echo $SERVERS` 'Custom'
        do
            if [[ $shareServer == 'Custom' ]]; then
                until [[ $msStatus == 0 ]]; do
                    echo -en "${CYAN}Enter new share path (in format //IP_ADDRESS/SHARE): ${NORMAL}"
                    read mountServer
                    if [[ `echo $mountServer |cut -c1-2` == '//' ]]; then
                        msStatus=0
                        break 1
                    fi
                    echo -en "${RED}ERROR: Incorrect path: $mountServer. Please use format //IP_ADDRESS/SHARE${NORMAL}"
                    echo ""
                done
            elif [[ $shareServer != "" ]]; then
                mountServer=$shareServer
            else
                echo -en "${RED}ERROR: Server is not selected${NORMAL}"
                echo ""
                exit 2
            fi
            break
        done

        echo "Select username for mount share:"
        select shareUsername in `echo $CIFS_USERNAME"@"$CIFS_DOMAIN` 'Custom'
        do
            if [[ $shareUsername == 'Custom' ]]; then
                    echo -en "${CYAN}Enter username for mount share folder: ${NORMAL}"
                    read cifsUserName
                    echo -en "${CYAN}Enter domain for share user: ${NORMAL}"
                    read cifsDomain
                    echo -en "${CYAN}Enter password for mount share folder: ${NORMAL}"
                    read cifsUserPwd
					smbConfigPath="/root/.uconsole/smb_$cifsUserName.conf"
					touch $smbConfigPath
					echo "username=$cifsUserName" > $smbConfigPath
					echo "dom=$cifsDomain" >> $smbConfigPath
					echo "password=$cifsUserPwd" >> $smbConfigPath
					break 1
            else
				smbConfigPath="/root/.uconsole/smb.conf"
				break 1
            fi
        done
        
    fi

    echo -en "${CYAN}Enter account folder on share server:${NORMAL} $mountServer/"
    read mountFolder
    mkdir -p /var/lib/vz/private/$VID/home/$userAccount/$mountFolder
    chown -R $userAccountUID.$userAccountGID /var/lib/vz/private/$VID/home/$userAccount/$mountFolder
    
	mountSource="$mountServer/$mountFolder"
	mountTarget="/mnt/$userAccount/$mountFolder"
	mkdir -p $mountTarget

	mount.cifs $mountSource $mountTarget -o rw,credentials=$smbConfigPath
	if [[ `cat /etc/mtab  |grep "$mountTarget" |wc -l` > 0 ]]; then
		echo "Share folder $mountTarget has been mount to the system."
	else
		echo "${RED}ERROR: Share folder $mountTarget has not been mount to the system. ${NORMAL}"
		exit 3
	fi
    
	echo "$mountSource $mountTarget cifs credentials=$smbConfigPath,iocharset=utf8,sec=ntlm,rw 0 0" >> /etc/fstab
    if [[ `cat /etc/fstab |grep "$mountTarget" |wc -l` > 0 ]]; then
        echo "Share for $userAccount account added to /etc/fstab."
	else
        echo "${RED}ERROR: Share for $userAccount account is not added to /etc/fstab.${NORMAL}"
    fi
	
	# Change config for bind mount
	srcValue="SRC[$userAccount]=$mountTarget"
	dstValue="DST[$userAccount]=/home/$userAccount/$mountFolder"
	sed -i "/# SRC_ARRAY/a $srcValue" /etc/vz/conf/$VID.mount
	sed -i "/# DST_ARRAY/a $dstValue" /etc/vz/conf/$VID.mount
	if [[ `cat /etc/vz/conf/$VID.mount |grep "$mountTarget" |wc -l` > 0 && `cat /etc/vz/conf/$VID.mount |grep "/home/$userAccount/$mountFolder" |wc -l` > 0 ]]; then
		echo "OpenVZ config updated to mount share for user $userAccount."
	else
		echo "${RED}ERROR: OpenVZ config was not updated.${NORMAL}"
	fi
}

function shareUmount {
	# Select user
	if [[ $# != 0 ]]; then
        userAccount=$1
	else
		echo "Please select account for mount: "
		select userAccount in `ls /var/lib/vz/private/$VID/home/`
		do
			if [[ $userAccount == "" ]]; then
				echo -en "${RED}Account is not selected${NORMAL}"
				echo ""
				exit 2
			fi
			break
		done
	fi
	
	
	
	# Umount BIND share
	umountTarget=`vzctl exec $UID cat /etc/mtab  |grep /$userAccount/ |cut -d" " -f2`
	vzctl exec $VID umount $umountTarget
	
	# Delete from OpenVZ config
	if [[ `cat /etc/vz/conf/$VID.mount |grep "/mnt/$userAccount" |wc -l` > 0 ]]; then
		sed -i "/\/mnt\/$userAccount\//d" /etc/fstab
		sed -i "/\/home\/$userAccount\//d" /etc/fstab
		echo "Share for $userAccount account removed from /etc/fstab."
	fi
	
	# Umount CIFS
	umountSource=`cat /etc/mtab  |grep /$userAccount/ |cut -d" " -f2`
	umount -l $umountSource
	
	# Delete from fstab
	if [[ `cat /etc/fstab |grep "/mnt/$userAccount" |wc -l` > 0 ]]; then
		sed -i "/\/mnt\/$userAccount\//d" /etc/fstab
		echo "Share for $userAccount account removed from /etc/fstab."
	fi
}

function userAdd {
    echo -en "${CYAN}Enter username: ${NORMAL}"
    read userAccount
    echo -en "${CYAN}Enter password for account: ${NORMAL}"
    read pswdNormal
	pswdHash=$(python -c "import crypt, getpass, pwd; print crypt.crypt('$pswdNormal','\$6\$SALTsalt\$')")

    echo -en "${BOLD}Account will be created with the follwing paramethers:${NORMAL}"
    echo ""
    echo -en "${BOLD}Username:${NORMAL} $userAccount"
    echo ""
    echo -en "${BOLD}Password:${NORMAL} $pswdNormal"
    echo ""
    echo -en "${GREEN}Please confirm (Y/n): ${NORMAL}"
    read confirmAdd
    if [[ $confirmAdd == "n" || $confirmAdd == "N" ]]; then
        echo -en "${RED}Exit${NORMAL}"
        echo ""
        exit 0
    fi

    vzctl exec $VID useradd --create-home --password $pswdHash $userAccount
    if  vzctl exec $VID id -u $userAccount >/dev/null 2>&1; then
        echo "Account $userAccount created"
    else
        echo "${RED}ERROR: Account $userAccount was not created. Abort.${NORMAL}"
        exit 3
    fi

    shareMount $userAccount
}

function userDel {
    if [[ `ls /var/lib/vz/private/$VID/home |wc -l` == 0 ]]; then
        echo -en "${RED}Nothing found in home directory. Exit.${NORMAL}"
        echo ""
        exit 2
    fi
    echo -en "${BOLD}Please select account for removal:  ${NORMAL}"
    echo ""
    select userAccount in `ls /var/lib/vz/private/$VID/home/`
    do
        if [[ $userAccount == "" ]]; then
            echo -en "${RED}Account is not selected${NORMAL}"
            echo ""
            exit 2
        fi
        break
    done

    if vzctl exec $VID id -u $userAccount >/dev/null 2>&1; then
        echo -en "${GREEN}Account $userAccount will be removed. Please confirm (y/N): ${NORMAL}"
        echo ""
        read confirmDel
    else
        echo -en "${RED}ERROR: Account $userAccount was not found in system. Abort. ${NORMAL}"
        echo ""
        confirmDel="N"
        exit 3
    fi
    
    if [[ $confirmDel == "y" || $confirmAdd == "Y" ]]; then
        vzctl exec $VID userdel --remove --force $userAccount
        if vzctl exec $VID id -u $userAccount >/dev/null 2>&1; then
            echo "${RED}ERROR: Account $userAccount was not removed.${NORMAL}"
            exit 3
        else
            echo "Account $userAccount removed"
        fi

        if [[ `cat /etc/fstab |grep "/mnt/$userAccount" |wc -l` > 0 ]]; then
            sed -i "/\/mnt\/$userAccount\//d" /etc/fstab
            echo "Share for $userAccount account removed from /etc/fstab."
        fi
		
		if [[ `cat /etc/vz/conf/$VID.mount |grep "/mnt/$userAccount" |wc -l` > 0 ]]; then
            sed -i "/\/mnt\/$userAccount\//d" /etc/fstab
            sed -i "/\/home\/$userAccount\//d" /etc/fstab
            echo "Share for $userAccount account removed from /etc/fstab."
        fi
    fi

}


if [[ ! -f ~/.uconsole/uconsole.conf ]]; then
    echo "Config file absent and will be created."
	configRecreate
else
    . ~/.uconsole/uconsole.conf
fi


case "$1" in
'updatesCheck')
        updatesCheck
        ;;
'configRecreate')
		configRecreate
        ;;
'userAdd')
		. ~/.uconsole/uconsole.conf
        userAdd
        ;;
'userDel')
		. ~/.uconsole/uconsole.conf
        userDel
        ;;
'shareMount')
		. ~/.uconsole/uconsole.conf
        shareMount
        ;;
'shareUmount')
		. ~/.uconsole/uconsole.conf
        shareUmount
        ;;
*)
        echo "Wrong method."
        echo "You must use the following methods with uConsole:"
        echo ""
        echo -en "${GREEN}`cat $0 |grep "^function"  |awk {'print$2'}`${NORMAL}"
        echo ""
        echo ""
        echo "Please use one of them."
esac

exit 0