#!/usr/bin/env bash
##################################################
### Script: uConsole                           ###
### Version 0.4.1                              ###
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
    remoteVer=`curl -s https://raw.githubusercontent.com/KeithSampson/uConsole/master/uConsole.sh |grep "### Version" |head -n1 |sed s/[^0-9.]//g`
    currentVer=`cat $0 |grep "### Version" |head -n1 |sed s/[^0-9.]//g`

    echo -en "${BOLD}Current Version: $currentVer ${NORMAL}"
    echo ""
    echo -en "${BOLD}Remote Version: $remoteVer ${NORMAL}"
    echo ""

    if [[ $currentVer == $remoteVer ]]; then
        echo "$(date +%F_%H-%M-%S) - No updates"
    else
        wget -O uConsole.sh_$remoteVer https://raw.githubusercontent.com/KeithSampson/uConsole/master/uConsole.sh
        chmod +x uConsole.sh_$remoteVer
        rm -f $0
        mv uConsole.sh_$remoteVer uConsole.sh
        echo "$(date +%F_%H-%M-%S) - Script uConsole.sh updated to $remoteVer"
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
    echo -en "${GREEN}Please confirm (Y/n): ${NORMAL}"
    read confirmConfAdd
    if [[ $confirmConfAdd == "n" || $confirmConfAdd == "N" ]]; then
        echo -en "${RED}Exit${NORMAL}"
        echo ""
        rm -rf ~/.uconsole
        exit 0
    fi

	mkdir -p ~/.uconsole/
    cp $BIN_PATH/sources/uconsole.conf-sample ~/.uconsole/uconsole.conf
	cp $BIN_PATH/sources/smb.conf-sample ~/.uconsole/smb.conf
	
    sed -i "s|SERVERS_LIST|${SERVERS_LIST[*]}|" ~/.uconsole/uconsole.conf
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
            select userAccount in `ls /home`
            do
                if [[ $userAccount == "" ]]; then
                    echo -en "${RED}Account is not selected${NORMAL}"
                    echo ""
                    exit 2
                fi
                break
            done
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
                    echo -en "${RED}Incorrect path: $mountServer. Please use format //IP_ADDRESS/SHARE${NORMAL}"
                    echo ""
                done
            elif [[ $shareServer != "" ]]; then
                mountServer=$shareServer
            else
                echo -en "${RED}Server is not selected${NORMAL}"
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
    
	mountSource="$mountServer/$mountFolder"

	mount.cifs $mountSource /home/$userAccount/public_ftp -o rw,uid=$userAccount,gid=$userAccount,credentials=$smbConfigPath
	
	echo "$mountSource /home/$userAccount/public_ftp cifs uid=$userAccount,gid=$userAccount,credentials=$smbConfigPath,iocharset=utf8,sec=ntlm,rw 0 0" | sudo tee -a /etc/fstab > /dev/null
    if [[ `cat /etc/fstab |grep "/home/$userAccount/" |wc -l` > 0 ]]; then
        echo "$(date +%F_%H-%M-%S) - Share for $userAccount account added to /etc/fstab."
    fi
}

function shareUmount {
echo -en "${GREEN}Do you want to umount share? (y/N): ${NORMAL}"
    read confirmMount
    if [[ $confirmMount == "n" || $confirmMount == "N" ]]; then
        exit 5
    else
        if [[ $# != 0 ]]; then
            userAccount=$1
        else
            echo "Please select account for umount: "
            select userAccount in `ls /home`
            do
                if [[ $userAccount == "" ]]; then
                    echo -en "${RED}Account is not selected${NORMAL}"
                    echo ""
                    exit 2
                fi
                break
            done
        fi
    fi   
	
	
	if [[ `mount |grep "/home/$userAccount" |wc -l` > 0 ]]; then
		umount -l /home/$userAccount/public_ftp
		echo "$(date +%F_%H-%M-%S) - Share for $userAccount umounted."
	fi
	
	if [[ `cat /etc/fstab |grep "/home/$userAccount/" |wc -l` > 0 ]]; then
		sed -i "/\/home\/$userAccount\//d" /etc/fstab
		echo "$(date +%F_%H-%M-%S) - Share for $userAccount account removed from /etc/fstab."
    fi
}

function userAdd {
    echo -en "${CYAN}Enter username: ${NORMAL}"
    read userAccount
    echo -en "${CYAN}Enter password for account: ${NORMAL}"
    read pswdNormal
    pswdHash=`openssl passwd -1 $pswdNormal`

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

    useradd -G sftponly --create-home --shell /sbin/bash --password $pswdHash $userAccount
	chown root.$userAccount /home/$userAccount
	chmod 750 /home/$userAccount
    if id -u $userAccount >/dev/null 2>&1; then
        echo "$(date +%F_%H-%M-%S) - Account $userAccount created"
		
		shareMount $userAccount
    else
        echo "$(date +%F_%H-%M-%S) - [error] Account $userAccount was not created. Abort."
        exit 3
    fi

    
}

function userDel {
    if [[ `ls /home |wc -l` == 0 ]]; then
        echo -en "${RED}Nothing found in home directory. Exit.${NORMAL}"
        echo ""
        exit 2
    fi
    echo -en "${BOLD}Please select account for removal:  ${NORMAL}"
    echo ""
    select userAccount in `ls /home`
    do
        if [[ $userAccount == "" ]]; then
            echo -en "${RED}Account is not selected${NORMAL}"
            echo ""
            exit 2
        fi
        break
    done

    if id -u $userAccount >/dev/null 2>&1; then
        echo -en "${GREEN}Account $userAccount will be removed. Please confirm (y/N): ${NORMAL}"
        echo ""
        read confirmDel
    else
        echo -en "${RED}$(date +%F_%H-%M-%S) - [error] Account $userAccount was not found in system. Abort. ${NORMAL}"
        echo ""
        confirmDel="N"
        exit 3
    fi
    
    if [[ $confirmDel == "y" || $confirmAdd == "Y" ]]; then
		shareUmount $userAccount
        userdel --remove $userAccount
        if id -u $userAccount >/dev/null 2>&1; then
            echo "$(date +%F_%H-%M-%S) - [error] Account $userAccount was not removed."
            exit 3
        else
            echo "$(date +%F_%H-%M-%S) - Account $userAccount removed"
        fi
		if [[ `cat /etc/group |grep $userAccount |wc -l` > 0 ]]; then
			groupdel $userAccount
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
        userAdd
        ;;
'userDel')
        userDel
        ;;
'shareMount')
		. ~/.uconsole/uconsole.conf
        shareMount
        ;;
'shareUmount')
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