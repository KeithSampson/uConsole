#!/usr/bin/env bash
##################################################
### Script: uConsole                           ###
### Version 0.2                                ###
### Made by Kostya Shutenko                    ###
### Contact address: kostya.shutenko@gmail.com ###
##################################################

BIN_PATH=$(dirname $(readlink -f $0))
NORMAL='\033[0m'
BOLD='\033[1m'
CYAN='\e[0;36m'
RED='\033[0;31m'
GREEN='\033[0;32m'

function updatesCheck () {
    remoteVer=`curl -s https://raw.githubusercontent.com/KeithSampson/uConsole/master/uConsole.sh |grep "### Version" |head -n1 |sed s/[^0-9.]//g`
    currentVer=`cat $0 |grep "### Version" |head -n1 |sed s/[^0-9.]//g`

    echo "Current Version: $currentVer"
    echo "Remote Version: $remoteVer"

    if [[ $currentVer == $remoteVer ]]; then
        echo "$(date +%F_%H-%M-%S) - No updates"
    else
        wget -O uConsole.sh_new https://raw.githubusercontent.com/KeithSampson/uConsole/master/uConsole.sh
        chmod +x uConsole.sh_new
        rm -f $0
        mv uConsole.sh_new uConsole.sh
        echo "$(date +%F_%H-%M-%S) - Script uConsole.sh updated."
    fi
~                  
}

function shareMount () {
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
    fi

    echo -en "${CYAN}Enter account folder on share server:${NORMAL} $mountServer/"
    read mountFolder
    mkdir -p /home/$userAccount/$mountFolder
    chown -R $userAccount.$userAccount /home/$userAccount/$mountFolder
    mountSource="$mountServer/$mountFolder"

    echo "mount -t cifs $mountSource /home/$userAccount/$mountFolder" >> /etc/fstab
    if [[ `cat /etc/fstab |grep "/home/$userAccount/" |wc -l` > 0 ]]; then
        echo "$(date +%F_%H-%M-%S) - Share for $userAccount account added to /etc/fstab."
    fi
}

function userAdd () {
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

    useradd --create-home --password $pswdHash $userAccount
    if id -u $userAccount >/dev/null 2>&1; then
        echo "$(date +%F_%H-%M-%S) - Account $userAccount created"
    else
        echo "$(date +%F_%H-%M-%S) - [error] Account $userAccount was not created. Abort."
        exit 3
    fi

    shareMount $userAccount
}

function userDel () {
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
        userdel --remove $userAccount
        if id -u $userAccount >/dev/null 2>&1; then
            echo "$(date +%F_%H-%M-%S) - [error] Account $userAccount was not removed."
            exit 3
        else
            echo "$(date +%F_%H-%M-%S) - Account $userAccount removed"
        fi

        if [[ `cat /etc/fstab |grep "/home/$userAccount/" |wc -l` > 0 ]]; then
            sed -i "/\/home\/$userAccount\//d" /etc/fstab
            echo "$(date +%F_%H-%M-%S) - Share for $userAccount account removed from /etc/fstab."
        fi
    fi

}


if [[ ! -f ~/.uconsole/uconsole.conf ]]; then
    echo "Config was not found."
    mkdir -p ~/.uconsole/
    cp $BIN_PATH/sources/uconsole.conf-simple ~/.uconsole/uconsole.conf
    
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

    echo "Servers with share: ${SERVERS_LIST[*]}"
    sed -i "s|SERVERS_LIST|`echo ${SERVERS_LIST[*]}`|" ~/.uconsole/uconsole.conf

else
    . ~/.uconsole/uconsole.conf
fi


case "$1" in
'updatesCheck')
        updatesCheck
        ;;
'userAdd')
        userAdd
        ;;
'userDel')
        userDel
        ;;
'shareMount')
        shareMount
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