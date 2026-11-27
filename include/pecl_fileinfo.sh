#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Install_pecl_fileinfo() {
  if [ -e "${php_install_dir}/bin/phpize" ]; then
    if ${php_install_dir}/bin/php -m 2>/dev/null | grep -qiw '^fileinfo$'; then
      echo "${CSUCCESS}PHP fileinfo module is already enabled! ${CEND}"
      return 0
    fi
    pushd ${oneinstack_dir}/src > /dev/null
    phpExtensionDir=$(${php_install_dir}/bin/php-config --extension-dir)
    PHP_detail_ver=$(${php_install_dir}/bin/php-config --version)
    src_url=https://www.php.net/distributions/php-${PHP_detail_ver}.tar.gz && Download_src
    tar xzf php-${PHP_detail_ver}.tar.gz
    pushd php-${PHP_detail_ver}/ext/fileinfo > /dev/null
    ${php_install_dir}/bin/phpize
    ./configure --with-php-config=${php_install_dir}/bin/php-config
    sed -i 's@^CFLAGS =.*@CFLAGS = -std=c99 -g@' Makefile
    make -j ${THREAD} && make install
    popd > /dev/null
    if [ -f "${phpExtensionDir}/fileinfo.so" ]; then
      echo 'extension=fileinfo.so' > ${php_install_dir}/etc/php.d/04-fileinfo.ini
      echo "${CSUCCESS}PHP fileinfo module installed successfully! ${CEND}"
      rm -rf php-${PHP_detail_ver}
    else
      echo "${CFAILURE}PHP fileinfo module install failed, Please contact the author! ${CEND}" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
    fi
    popd > /dev/null
  fi
}

Uninstall_pecl_fileinfo() {
  if [ -e "${php_install_dir}/etc/php.d/04-fileinfo.ini" ]; then
    rm -f ${php_install_dir}/etc/php.d/04-fileinfo.ini
    echo; echo "${CMSG}PHP fileinfo module uninstall completed${CEND}"
  elif [ -f "${php_install_dir}/.install_method" ] && [ -e "${php_install_dir}/etc/php.d/20-fileinfo.ini" ]; then
    /bin/mv "${php_install_dir}/etc/php.d/20-fileinfo.ini" "${php_install_dir}/etc/php.d/20-fileinfo.ini.disabled"
    echo; echo "${CMSG}PHP fileinfo module disabled${CEND}"
  elif [ -f "${php_install_dir}/.install_method" ] && [ "$(awk -F= '/^method=/{print $2}' "${php_install_dir}/.install_method" 2>/dev/null)" == "apt" ]; then
    local _apt_ver
    _apt_ver=$(awk -F= '/^apt_ver=/{print $2}' "${php_install_dir}/.install_method" 2>/dev/null)
    if [ -n "${_apt_ver}" ] && ls "/etc/php/${_apt_ver}/"*/conf.d/*fileinfo.ini >/dev/null 2>&1; then
      command -v phpdismod >/dev/null 2>&1 && phpdismod -v "${_apt_ver}" fileinfo >/dev/null 2>&1 || rm -f "/etc/php/${_apt_ver}/"*/conf.d/*fileinfo.ini
      echo; echo "${CMSG}PHP fileinfo module disabled${CEND}"
    else
      echo; echo "${CWARNING}PHP fileinfo module does not exist! ${CEND}"
    fi
  else
    echo; echo "${CWARNING}PHP fileinfo module does not exist! ${CEND}"
  fi
}
