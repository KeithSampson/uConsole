#!/usr/bin/env bash
##################################################
### Script: uConsole                           ###
### Version 0.1                                ###
### Made by Kostya Shutenko                    ###
### Contact address: kostya.shutenko@gmail.com ###
##################################################

BIN_PATH=$(dirname $(readlink -f $0))
NORMAL='\033[0m'
BOLD='\033[1m'
CYAN='\e[0;36m'
RED='\033[0;31m'
GREEN='\033[0;32m'

if [[ ! -f $BIN_PATH/conf.d/console.conf ]]; then
    echo "Config was not found."
    echo "Please create $BIN_PATH/conf.d/console.conf"
    exit 1
else
    . $BIN_PATH/conf.d/console.conf
fi

function updatesCheck () {
    echo "No updates"
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

    echo "mount -t cifs $mountSource /home/$userAccount/$mountFolder"
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
    echo "Please select account for removal: "
    select userAccount in `ls /home`
    do
        if [[ $userAccount == "" ]]; then
            echo -en "${RED}Account is not selected${NORMAL}"
            echo ""
            exit 2
        fi
        break
    done

    echo -en "${GREEN}Account $userAccount will be removed. Please confirm (y/N): ${NORMAL}"
    read confirmDel
    if [[ $confirmDel == "y" || $confirmAdd == "Y" ]]; then
        userdel --remove $userAccount
        if id -u $userAccount >/dev/null 2>&1; then
            echo "$(date +%F_%H-%M-%S) - [error] Account $userAccount was not removed."
            exit 3
        else
            echo "$(date +%F_%H-%M-%S) - Account $userAccount removed"
        fi
    fi

}




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
        echo "You must use the following methods with $0:"
        echo ""
        echo -en "${GREEN}`cat $0 |grep "^function"  |awk {'print$2'}`${NORMAL}"
        echo ""
        echo ""
        echo "Please use one of them."
esac

exit 0