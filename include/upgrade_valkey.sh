#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Upgrade_Valkey() {
  pushd ${oneinstack_dir}/src > /dev/null
  [ ! -d "$valkey_install_dir" ] && echo "${CWARNING}Valkey is not installed on your system! ${CEND}" && exit 1
  OLD_valkey_ver=`$valkey_install_dir/bin/valkey-cli --version 2>&1 | awk '{print $2}'`
  Latest_valkey_ver=${valkey_ver:-8.0.2}
  echo "Current Valkey Version: ${CMSG}$OLD_valkey_ver${CEND}"
  while :; do echo
    [ "${valkey_flag}" != 'y' ] && read -e -p "Please input upgrade Valkey Version(default: ${Latest_valkey_ver}): " NEW_valkey_ver
    NEW_valkey_ver=${NEW_valkey_ver:-${Latest_valkey_ver}}
    if [ "$NEW_valkey_ver" != "$OLD_valkey_ver" ]; then
      src_url=${mirror_link}/oneinstack/src/valkey-${NEW_valkey_ver}.tar.gz && Download_src
      [ ! -e "valkey-${NEW_valkey_ver}.tar.gz" ] && wget --no-check-certificate -c https://github.com/valkey-io/valkey/archive/refs/tags/v${NEW_valkey_ver}.tar.gz -O valkey-${NEW_valkey_ver}.tar.gz > /dev/null 2>&1
      if [ -e "valkey-${NEW_valkey_ver}.tar.gz" ]; then
        echo "Download [${CMSG}valkey-$NEW_valkey_ver.tar.gz${CEND}] successfully! "
        break
      else
        echo "${CWARNING}Valkey version does not exist! ${CEND}"
      fi
    else
      echo "${CWARNING}input error! Upgrade Valkey version is the same as the old version${CEND}"
      exit
    fi
  done

  if [ -e "valkey-$NEW_valkey_ver.tar.gz" ]; then
    echo "[${CMSG}valkey-$NEW_valkey_ver.tar.gz${CEND}] found"
    if [ "${valkey_flag}" != 'y' ]; then
      echo "Press Ctrl+c to cancel or Press any key to continue..."
      char=`get_char`
    fi
    tar xzf valkey-$NEW_valkey_ver.tar.gz
    [ -d "valkey-${NEW_valkey_ver}" ] && pushd valkey-${NEW_valkey_ver} || pushd valkey-v${NEW_valkey_ver}
    make clean
    make -j ${THREAD}

    if [ -f "src/valkey-server" ]; then
      echo "Restarting Valkey..."
      service valkey-server stop
      /bin/cp src/{valkey-benchmark,valkey-check-aof,valkey-check-rdb,valkey-cli,valkey-sentinel,valkey-server} $valkey_install_dir/bin/
      service valkey-server start
      popd > /dev/null
      echo "You have ${CMSG}successfully${CEND} upgrade from ${CWARNING}$OLD_valkey_ver${CEND} to ${CWARNING}$NEW_valkey_ver${CEND}"
      rm -rf valkey-${NEW_valkey_ver} valkey-v${NEW_valkey_ver}
    else
      echo "${CFAILURE}Upgrade Valkey failed! ${CEND}"
    fi
  fi
  popd > /dev/null
}
