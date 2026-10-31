#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Upgrade_Nodejs() {
  pushd ${oneinstack_dir}/src > /dev/null
  [ ! -e "${nodejs_install_dir}/bin/node" ] && echo "${CWARNING}Nodejs is not installed on your system! ${CEND}" && exit 1
  OLD_nodejs_ver=$(${nodejs_install_dir}/bin/node -v 2>/dev/null | sed 's/^v//')
  glibc_ver=$(ldd --version 2>&1 | head -n1 | grep -oE '[0-9]+\.[0-9]+$')
  if [ -n "${glibc_ver}" ] && [ "$(printf '%s\n' 2.28 "${glibc_ver}" | sort -V | head -n1)" != "2.28" ]; then
    Latest_nodejs_ver=${nodejs_oldver:-16.20.2}
  else
    Latest_nodejs_ver=${nodejs_ver:-24.22.2}
  fi
  echo "Current Nodejs Version: ${CMSG}${OLD_nodejs_ver}${CEND}"
  while :; do echo
    [ "${nodejs_flag}" != 'y' ] && read -e -p "Please input upgrade Nodejs Version(default: ${Latest_nodejs_ver}): " NEW_nodejs_ver
    NEW_nodejs_ver=${NEW_nodejs_ver:-${Latest_nodejs_ver}}
    NEW_nodejs_ver=${NEW_nodejs_ver#v}
    if [ -n "${glibc_ver}" ] && [ "$(printf '%s\n' 2.28 "${glibc_ver}" | sort -V | head -n1)" != "2.28" ] && [ "${NEW_nodejs_ver%%.*}" -ge 18 ] 2>/dev/null; then
      echo "${CWARNING}Your system glibc (${glibc_ver}) < 2.28 does not support Nodejs 18+! ${CEND}"
      [ "${nodejs_flag}" == 'y' ] && exit 1
      unset NEW_nodejs_ver
      continue
    fi
    if [ "${NEW_nodejs_ver}" != "${OLD_nodejs_ver}" ]; then
      FILE_NAME=node-v${NEW_nodejs_ver}-linux-${SYS_ARCH_n}.tar.gz
      [ "${OUTIP_STATE}"x == "China"x ] && DOWN_ADDR_NODE=https://mirrors.tuna.tsinghua.edu.cn/nodejs-release || DOWN_ADDR_NODE=https://nodejs.org/dist
      [ ! -e "${FILE_NAME}" ] && wget --no-check-certificate -c ${DOWN_ADDR_NODE}/v${NEW_nodejs_ver}/${FILE_NAME} > /dev/null 2>&1
      [ ! -e "${FILE_NAME}" ] && wget --no-check-certificate -c ${mirror_link}/oneinstack/src/${FILE_NAME} > /dev/null 2>&1
      [ ! -e "${FILE_NAME}" ] && wget --no-check-certificate -c https://nodejs.org/dist/v${NEW_nodejs_ver}/${FILE_NAME} > /dev/null 2>&1
      if [ -s "${FILE_NAME}" ]; then
        echo "Download [${CMSG}${FILE_NAME}${CEND}] successfully! "
        break
      else
        rm -f "${FILE_NAME}"
        echo "${CWARNING}Nodejs version does not exist! ${CEND}"
        [ "${nodejs_flag}" == 'y' ] && exit 1
        unset NEW_nodejs_ver
      fi
    else
      echo "${CWARNING}input error! Upgrade Nodejs version is the same as the old version${CEND}"
      exit
    fi
  done

  if [ -e "${FILE_NAME}" ]; then
    echo "[${CMSG}${FILE_NAME}${CEND}] found"
    if [ "${nodejs_flag}" != 'y' ]; then
      echo "Press Ctrl+c to cancel or Press any key to continue..."
      char=`get_char`
    fi
    rm -rf node-v${NEW_nodejs_ver}-linux-${SYS_ARCH_n}
    tar xzf ${FILE_NAME}
    if [ -e "node-v${NEW_nodejs_ver}-linux-${SYS_ARCH_n}/bin/node" ]; then
      rm -rf ${nodejs_install_dir}/bin/{node,npm,npx,corepack}
      rm -rf ${nodejs_install_dir}/include/node
      rm -rf ${nodejs_install_dir}/lib/node_modules/{npm,corepack}
      rm -rf ${nodejs_install_dir}/share
      /bin/cp -rf node-v${NEW_nodejs_ver}-linux-${SYS_ARCH_n}/* ${nodejs_install_dir}/
      rm -rf node-v${NEW_nodejs_ver}-linux-${SYS_ARCH_n}
      echo "You have ${CMSG}successfully${CEND} upgrade from ${CWARNING}${OLD_nodejs_ver}${CEND} to ${CWARNING}${NEW_nodejs_ver}${CEND}"
    else
      echo "${CFAILURE}Upgrade Nodejs failed! ${CEND}"
    fi
  fi
  popd > /dev/null
}
