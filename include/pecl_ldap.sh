#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Install_pecl_ldap() {
  local deb_multiarch

  if [ ! -e "${php_install_dir}/bin/phpize" ]; then
    echo "${CFAILURE}PHP phpize is required to install ldap.${CEND}"
    return 1
  fi

    pushd ${oneinstack_dir}/src > /dev/null || return 1
    phpExtensionDir=$(${php_install_dir}/bin/php-config --extension-dir)
    PHP_detail_ver=$(${php_install_dir}/bin/php-config --version)
    src_url=https://www.php.net/distributions/php-${PHP_detail_ver}.tar.gz
    [ "${PHP_detail_ver}" = "${php85_ver}" ] && src_checksum=${php85_checksum:-}
    Download_src no_kill || return 1
    tar xzf php-${PHP_detail_ver}.tar.gz || return 1
    pushd php-${PHP_detail_ver}/ext/ldap > /dev/null || return 1
    if [ "${PM}" == 'yum' ]; then
      yum -y install openldap-devel || return 1
    else
      apt-get --no-install-recommends -y install libldap2-dev || return 1
      deb_multiarch=$(dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null)
      [ -z "${deb_multiarch}" ] && deb_multiarch=$(gcc -print-multiarch 2>/dev/null)
      if [ -z "${deb_multiarch}" ] || [ ! -d "/usr/lib/${deb_multiarch}" ]; then
        echo "${CFAILURE}Unable to determine the Debian multiarch LDAP library directory.${CEND}"
        return 1
      fi
    fi
    ${php_install_dir}/bin/phpize || return 1
    if [ "${PM}" == 'yum' ]; then
      ./configure --with-php-config=${php_install_dir}/bin/php-config --with-ldap --with-libdir=lib64 || return 1
    else
      ./configure --with-php-config=${php_install_dir}/bin/php-config \
        --with-ldap=/usr --with-libdir="lib/${deb_multiarch}" || return 1
    fi
    make -j ${THREAD} && make install || return 1
    popd > /dev/null
    if [ -f "${phpExtensionDir}/ldap.so" ]; then
      echo 'extension=ldap.so' > ${php_install_dir}/etc/php.d/04-ldap.ini
      echo "${CSUCCESS}PHP ldap module installed successfully! ${CEND}"
      rm -rf php-${PHP_detail_ver}
    else
      echo "${CFAILURE}PHP ldap module install failed, Please contact the author! ${CEND}"
      grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
      return 1
    fi
    popd > /dev/null
}

Uninstall_pecl_ldap() {
  if [ -e "${php_install_dir}/etc/php.d/04-ldap.ini" ]; then
    rm -f ${php_install_dir}/etc/php.d/04-ldap.ini
    echo; echo "${CMSG}PHP ldap module uninstall completed${CEND}"
  else
    echo; echo "${CWARNING}PHP ldap module does not exist! ${CEND}"
  fi
}
