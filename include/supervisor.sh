#!/bin/bash
# Author:  OneinStack
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Install_supervisor() {
  if [ -e "/usr/bin/supervisord" -o -e "/usr/local/bin/supervisord" ]; then
    echo "${CWARNING}Supervisor already installed! ${CEND}"
  else
    if [ "${PM}" == 'yum' ]; then
      yum -y install epel-release
      yum -y install supervisor
      if [ -e "/etc/supervisord.conf" ] && [ ! -d "/etc/supervisord.d" ]; then
        mkdir -p /etc/supervisord.d
      fi
      systemctl enable supervisord
      systemctl start supervisord
    elif [ "${PM}" == 'apt-get' ]; then
      apt-get -y update
      apt-get -y install supervisor
      mkdir -p /etc/supervisord.d
      if [ -e "/etc/supervisor/supervisord.conf" ] && [ -z "$(grep '/etc/supervisord.d/\*.ini' /etc/supervisor/supervisord.conf)" ]; then
        sed -i 's@^files = .*@files = /etc/supervisor/conf.d/*.conf /etc/supervisord.d/*.ini@' /etc/supervisor/supervisord.conf
      fi
      systemctl enable supervisor
      systemctl restart supervisor
    fi
    if [ -e "/usr/bin/supervisord" -o -e "/usr/local/bin/supervisord" ]; then
      echo; echo "${CSUCCESS}Supervisor installed successfully! Config dir: /etc/supervisord.d/ ${CEND}"
    else
      echo; echo "${CFAILURE}Supervisor install failed, Please try again! ${CEND}"
    fi
  fi
}

Uninstall_supervisor() {
  if [ -e "/usr/bin/supervisord" -o -e "/usr/local/bin/supervisord" ]; then
    if [ "${PM}" == 'yum' ]; then
      systemctl stop supervisord > /dev/null 2>&1
      systemctl disable supervisord > /dev/null 2>&1
      yum -y remove supervisor > /dev/null 2>&1
    elif [ "${PM}" == 'apt-get' ]; then
      systemctl stop supervisor > /dev/null 2>&1
      systemctl disable supervisor > /dev/null 2>&1
      apt-get -y remove supervisor > /dev/null 2>&1
    fi
    echo; echo "${CMSG}Supervisor uninstall completed${CEND}"
  else
    echo; echo "${CWARNING}Supervisor does not exist! ${CEND}"
  fi
}
