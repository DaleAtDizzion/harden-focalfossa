#!/bin/bash

# set color codes for status
RESTORE='\033[0m'
BLACK='\033[00;30m'
RED='\033[00;31m'
GREEN='\033[00;32m'
YELLOW='\033[00;33m'
BLUE='\033[00;34m'
PURPLE='\033[00;35m'
CYAN='\033[00;36m'
LIGHTGRAY='\033[00;37m'
LBLACK='\033[01;30m'
LRED='\033[01;31m'
LGREEN='\033[01;32m'
LYELLOW='\033[01;33m'
LBLUE='\033[01;34m'
LPURPLE='\033[01;35m'
LCYAN='\033[01;36m'
WHITE='\033[01;37m'
OVERWRITE='\e[1A\e[K'

# _header colorize the given argument with spacing
function _task {
    # if _task is called while a task was set, complete the previous
    if [[ $TASK != "" ]]; then
        printf "${OVERWRITE}${LGREEN} [✓]  ${LGREEN}${TASK}\n"
    fi
    # set new task title and print
    TASK=$1
    printf "${LBLACK} [ ]  ${TASK} \n${LRED}"
}

# _cmd performs commands with error checking
function _cmd {
    # empty harden.log
    > harden.log
    # hide stdout, on error we print and exit
    if eval "$1" 1> /dev/null 2> harden.log; then
        return 0 # success
    fi
    # read error from log and add spacing
    printf "${OVERWRITE}${LRED} [X]  ${TASK}${LRED}\n"
    while read line; do 
        printf "      ${line}\n"
    done < harden.log
    printf "\n"
    # remove log file
    rm harden.log
    # exit installation
    exit 1
} 

clear
 
printf "${RED}
HARDEN.SH
${LBLACK}Hardening ${YELLOW}Ubuntu 20.04 ${LBLACK}
"

# script must be run as root
if [[ $(id -u) -ne 0 ]] ; then printf "\n${LRED} Please run as root${RESTORE}\n\n" ; exit 1 ; fi

# dependencies
_task "update dependencies"
    _cmd 'apt-get install wget sed git -y'
    
# update and upgrade apt
_task "update system"
    _cmd 'apt-get update -y && apt-get full-upgrade -y'
    
# add net-tools
_task "install net-tools"
    _cmd 'apt-get install net-tools -y'

# finish last task
#printf "${OVERWRITE}${LGREEN} [✓]  ${LGREEN}${TASK}\n"

# update NTP servers to pool.ntp.org
_task "update ntp servers"
    _cmd 'truncate -s0 /etc/systemd/timesyncd.conf'
    _cmd 'echo "[Time]" | sudo tee -a /etc/systemd/timesyncd.conf'
    _cmd 'echo "NTP=pool.ntp.org" | sudo tee -a /etc/systemd/timesyncd.conf'
    _cmd 'echo "FallbackNTP=ntp.ubuntu.com" | sudo tee -a /etc/systemd/timesyncd.conf'

# replace systctl.conf with a hardened version
_task "update sysctl.conf"
    _cmd 'sudo chmod 744 /etc/sysctl.conf && sudo rm /etc/sysctl.conf -f'
    _cmd 'wget --timeout=5 --tries=2 --quiet -c https://raw.githubusercontent.com/daleatdizzion/harden-focalfossa/main/sysctl.conf -O /etc/sysctl.conf'

# replace sshd_config with a hardened version
_task "update sshd_config"
    _cmd 'sudo chmod 744 /etc/ssh/sshd_config && sudo rm /etc/ssh/sshd_config -f'
    _cmd 'wget --timeout=5 --tries=2 --quiet -c https://raw.githubusercontent.com/daleatdizzion/harden-focalfossa/main/sshd.conf -O /etc/ssh/sshd_config'

# disable snapd
_task "disable snapd"
    _cmd 'systemctl stop snapd.service'
    _cmd 'systemctl disable snapd.service'
    _cmd 'systemctl mask snapd.service'

# configure firewall and allow port 22 for ssh
_task "configure firewall"
    _cmd 'ufw disable'
    _cmd 'echo "y" | sudo ufw reset'
    _cmd 'ufw logging off'
    _cmd 'ufw default deny incoming'
    _cmd 'ufw default allow outgoing'
    _cmd 'ufw allow 22/tcp comment "ssh"'
    
    # disable IPv6
    _cmd 'sed -i "/ipv6=/Id" /etc/default/ufw'
    _cmd 'echo "IPV6=no" | sudo tee -a /etc/default/ufw'
    _cmd 'sed -i "/GRUB_CMDLINE_LINUX_DEFAULT=/Id" /etc/default/grub'
    _cmd 'echo "GRUB_CMDLINE_LINUX_DEFAULT=\"ipv6.disable=1 quiet splash\"" | sudo tee -a /etc/default/grub'

# sets session timeout to 15 minutes via autologout.sh
_task "create 15 minute autologout "
    _cmd 'sudo wget --timeout=5 --tries=2 --quiet -c https://raw.githubusercontent.com/daleatdizzion/harden-focalfossa/main/autologout.sh -O /etc/profile.d/autologout.sh'
    _cmd 'sudo chmod 0755 /etc/profile.d/autologout.sh'

# configure automatic security update installation
_task "configure automatic security updates"
#    _cmd 'sudo dpkg-reconfigure --priority=low unattended-upgrades'
    _cmd 'echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections'
    _cmd 'dpkg-reconfigure -f noninteractive unattended-upgrades'

# reload system to commit changes
_task "reload system"
    _cmd 'sysctl -p'
    _cmd 'update-grub2'
    _cmd 'systemctl restart systemd-timesyncd'
    _cmd 'ufw --force enable'
    _cmd 'service ssh restart'

# finish last task
printf "${OVERWRITE}${LGREEN} [✓]  ${LGREEN}${TASK}\n"

# remove log file
if [[ harden.log != null ]] ; then 
   rm harden.log; fi

# prompt for reboot
printf "\n${YELLOW} Do you want to reboot [Y/n]? ${RESTORE}"
read prompt && printf "${OVERWRITE}" && if [[ $prompt == "y" || $prompt == "Y" ]]; then
    reboot
fi

# exit
exit 1

# the following are pending review and/or removal
# # description
# _task "disable multipathd"
#     _cmd 'systemctl stop multipathd'
#     _cmd 'systemctl disable multipathd'
#     _cmd 'systemctl mask multipathd'

# # description
# _task "disable fwupd"
#     _cmd 'systemctl stop fwupd.service'
#     _cmd 'systemctl disable fwupd.service'
#     _cmd 'systemctl mask fwupd.service'


# # description
# _task "disable qemu-guest"
#     _cmd 'apt-get remove qemu-guest-agent -y'
#     _cmd 'apt-get remove --auto-remove qemu-guest-agent -y' 
#     _cmd 'apt-get purge qemu-guest-agent -y' 
#     _cmd 'apt-get purge --auto-remove qemu-guest-agent -y'

# # description
# _task "disable policykit"
#     _cmd 'apt-get remove policykit-1 -y'
#     _cmd 'apt-get autoremove policykit-1 -y' 
#     _cmd 'apt-get purge policykit-1 -y' 
#     _cmd 'apt-get autoremove --purge policykit-1 -y'

# # description
# _task "disable accountsservice"
#     _cmd 'service accounts-daemon stop'
#     _cmd 'apt remove accountsservice -y'
