#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Install_pecl_calendar() {
  if [ -e "${php_install_dir}/bin/phpize" ]; then
    if ${php_install_dir}/bin/php -m 2>/dev/null | grep -qiw '^calendar$'; then
      echo "${CSUCCESS}PHP calendar module is already enabled! ${CEND}"
      return 0
    fi
    pushd ${oneinstack_dir}/src > /dev/null
    phpExtensionDir=$(${php_install_dir}/bin/php-config --extension-dir)
    PHP_detail_ver=$(${php_install_dir}/bin/php-config --version)
    src_url=https://www.php.net/distributions/php-${PHP_detail_ver}.tar.gz && Download_src
    tar xzf php-${PHP_detail_ver}.tar.gz
    pushd php-${PHP_detail_ver}/ext/calendar > /dev/null
    ${php_install_dir}/bin/phpize
    ./configure --with-php-config=${php_install_dir}/bin/php-config
    make -j ${THREAD} && make install
    popd > /dev/null
    if [ -f "${phpExtensionDir}/calendar.so" ]; then
      echo 'extension=calendar.so' > ${php_install_dir}/etc/php.d/04-calendar.ini
      echo "${CSUCCESS}PHP calendar module installed successfully! ${CEND}"
      rm -rf php-${PHP_detail_ver}
    else
      echo "${CFAILURE}PHP calendar module install failed, Please contact the author! ${CEND}" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
    fi
    popd > /dev/null
  fi
}

Uninstall_pecl_calendar() {
  if [ -e "${php_install_dir}/etc/php.d/04-calendar.ini" ]; then
    rm -f ${php_install_dir}/etc/php.d/04-calendar.ini
    echo; echo "${CMSG}PHP calendar module uninstall completed${CEND}"
  elif [ -f "${php_install_dir}/.install_method" ] && [ -e "${php_install_dir}/etc/php.d/20-calendar.ini" ]; then
    /bin/mv "${php_install_dir}/etc/php.d/20-calendar.ini" "${php_install_dir}/etc/php.d/20-calendar.ini.disabled"
    echo; echo "${CMSG}PHP calendar module disabled${CEND}"
  elif [ -f "${php_install_dir}/.install_method" ] && [ "$(awk -F= '/^method=/{print $2}' "${php_install_dir}/.install_method" 2>/dev/null)" == "apt" ]; then
    local _apt_ver
    _apt_ver=$(awk -F= '/^apt_ver=/{print $2}' "${php_install_dir}/.install_method" 2>/dev/null)
    if [ -n "${_apt_ver}" ] && ls "/etc/php/${_apt_ver}/"*/conf.d/*calendar.ini >/dev/null 2>&1; then
      command -v phpdismod >/dev/null 2>&1 && phpdismod -v "${_apt_ver}" calendar >/dev/null 2>&1 || rm -f "/etc/php/${_apt_ver}/"*/conf.d/*calendar.ini
      echo; echo "${CMSG}PHP calendar module disabled${CEND}"
    else
      echo; echo "${CWARNING}PHP calendar module does not exist! ${CEND}"
    fi
  else
    echo; echo "${CWARNING}PHP calendar module does not exist! ${CEND}"
  fi
}
