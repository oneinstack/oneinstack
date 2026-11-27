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
  if [ -e "${php_install_dir}/bin/phpize" ]; then
    if ${php_install_dir}/bin/php -m 2>/dev/null | grep -qiw '^ldap$'; then
      echo "${CSUCCESS}PHP ldap module is already enabled! ${CEND}"
      return 0
    fi
    if [ -f "${php_install_dir}/.install_method" ]; then
      local _php_method _remi_pkg _apt_pkg
      _php_method=$(awk -F= '/^method=/{print $2}' "${php_install_dir}/.install_method" 2>/dev/null)
      _remi_pkg=$(awk -F= '/^remi_pkg=/{print $2}' "${php_install_dir}/.install_method" 2>/dev/null)
      _apt_pkg=$(awk -F= '/^apt_pkg=/{print $2}' "${php_install_dir}/.install_method" 2>/dev/null)
      if [ "${_php_method}" == "dnf" ] && [ -n "${_remi_pkg}" ] && command -v dnf >/dev/null 2>&1; then
        type PHP_DNF_Build_Repo_Args >/dev/null 2>&1 || . "${oneinstack_dir}/include/php_dnf.sh"
        PHP_DNF_Build_Repo_Args
        dnf -y ${PHP_DNF_REPO_ARGS} install "${_remi_pkg}-php-ldap" >/dev/null 2>&1 || true
        if ${php_install_dir}/bin/php -m 2>/dev/null | grep -qiw '^ldap$'; then
          echo "${CSUCCESS}PHP ldap module installed successfully via DNF! ${CEND}"
          return 0
        fi
      elif [ "${_php_method}" == "apt" ] && [ -n "${_apt_pkg}" ] && command -v apt-get >/dev/null 2>&1; then
        DEBIAN_FRONTEND=noninteractive apt-get --no-install-recommends -y install "${_apt_pkg}-ldap" >/dev/null 2>&1 || true
        if ${php_install_dir}/bin/php -m 2>/dev/null | grep -qiw '^ldap$'; then
          echo "${CSUCCESS}PHP ldap module installed successfully via APT! ${CEND}"
          return 0
        fi
      fi
    fi
    pushd ${oneinstack_dir}/src > /dev/null
    phpExtensionDir=$(${php_install_dir}/bin/php-config --extension-dir)
    PHP_detail_ver=$(${php_install_dir}/bin/php-config --version)
    src_url=https://www.php.net/distributions/php-${PHP_detail_ver}.tar.gz && Download_src
    tar xzf php-${PHP_detail_ver}.tar.gz
    pushd php-${PHP_detail_ver}/ext/ldap > /dev/null
    if [ "${PM}" == 'yum' ]; then
      yum -y install openldap-devel
    else
      apt-get -y install libldap2-dev
      ln -s /usr/lib/${ARCH}-linux-gnu/libldap.so /usr/lib/
      ln -s /usr/lib/${ARCH}-linux-gnu/liblber.so /usr/lib/
    fi
    ${php_install_dir}/bin/phpize
    if [ "${PM}" == 'yum' ]; then
      ./configure --with-php-config=${php_install_dir}/bin/php-config --with-ldap --with-libdir=lib64
    else
      ./configure --with-php-config=${php_install_dir}/bin/php-config --with-ldap --with-libdir=lib/${ARCH}-linux-gnu
    fi
    make -j ${THREAD} && make install
    popd > /dev/null
    if [ -f "${phpExtensionDir}/ldap.so" ]; then
      echo 'extension=ldap.so' > ${php_install_dir}/etc/php.d/04-ldap.ini
      echo "${CSUCCESS}PHP ldap module installed successfully! ${CEND}"
      rm -rf php-${PHP_detail_ver}
    else
      echo "${CFAILURE}PHP ldap module install failed, Please contact the author! ${CEND}" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
    fi
    popd > /dev/null
  fi
}

Uninstall_pecl_ldap() {
  if [ -e "${php_install_dir}/etc/php.d/04-ldap.ini" ]; then
    rm -f ${php_install_dir}/etc/php.d/04-ldap.ini
    echo; echo "${CMSG}PHP ldap module uninstall completed${CEND}"
  elif [ -f "${php_install_dir}/.install_method" ]; then
    local _php_method _remi_pkg _apt_pkg
    _php_method=$(awk -F= '/^method=/{print $2}' "${php_install_dir}/.install_method" 2>/dev/null)
    _remi_pkg=$(awk -F= '/^remi_pkg=/{print $2}' "${php_install_dir}/.install_method" 2>/dev/null)
    _apt_pkg=$(awk -F= '/^apt_pkg=/{print $2}' "${php_install_dir}/.install_method" 2>/dev/null)
    if [ "${_php_method}" == "dnf" ] && [ -n "${_remi_pkg}" ] && command -v dnf >/dev/null 2>&1 && rpm -q "${_remi_pkg}-php-ldap" >/dev/null 2>&1; then
      dnf -y remove "${_remi_pkg}-php-ldap"
      echo; echo "${CMSG}PHP ldap module uninstall completed${CEND}"
    elif [ "${_php_method}" == "apt" ] && [ -n "${_apt_pkg}" ] && command -v apt-get >/dev/null 2>&1 && dpkg -s "${_apt_pkg}-ldap" >/dev/null 2>&1; then
      DEBIAN_FRONTEND=noninteractive apt-get -y purge "${_apt_pkg}-ldap"
      echo; echo "${CMSG}PHP ldap module uninstall completed${CEND}"
    else
      echo; echo "${CWARNING}PHP ldap module does not exist! ${CEND}"
    fi
  else
    echo; echo "${CWARNING}PHP ldap module does not exist! ${CEND}"
  fi
}
