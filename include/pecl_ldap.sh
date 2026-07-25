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
  local deb_multiarch php_extension_dir php_detail_ver

  if [ ! -x "${php_install_dir}/bin/phpize" ] ||
    [ ! -x "${php_install_dir}/bin/php-config" ]; then
    echo "${CFAILURE}PHP phpize and php-config are required to install ldap.${CEND}"
    return 1
  fi

  # LDAP is built from the matching, trusted PHP source tree. Install both the
  # OpenLDAP and SASL headers so the module is useful for modern directory
  # services without depending on an LDAP server being installed locally.
  # LDAP 使用对应 PHP 官方源码构建，并显式安装 OpenLDAP/SASL 开发头文件；
  # 仅安装客户端能力，不会在本机部署 LDAP 服务端。
  if [ "${PM}" = 'yum' ]; then
    yum -y install openldap-devel cyrus-sasl-devel || return 1
  else
    apt-get --no-install-recommends -y install libldap2-dev libsasl2-dev ||
      return 1
  fi

  php_extension_dir=$("${php_install_dir}/bin/php-config" --extension-dir) ||
    return 1
  php_detail_ver=$("${php_install_dir}/bin/php-config" --version) || return 1

  (
    cd "${oneinstack_dir}/src" || return 1
    src_url="https://www.php.net/distributions/php-${php_detail_ver}.tar.gz"
    [ "${php_detail_ver}" = "${php85_ver}" ] &&
      src_checksum=${php85_checksum:-}
    Download_src no_kill || return 1
    tar xzf "php-${php_detail_ver}.tar.gz" || return 1
    cd "php-${php_detail_ver}/ext/ldap" || return 1

    "${php_install_dir}/bin/phpize" --clean >/dev/null 2>&1 || true
    "${php_install_dir}/bin/phpize" || return 1
    if [ "${PM}" = 'yum' ]; then
      ./configure \
        --with-php-config="${php_install_dir}/bin/php-config" \
        --with-ldap \
        --with-ldap-sasl \
        --with-libdir=lib64 || return 1
    else
      deb_multiarch=$(dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null)
      [ -n "${deb_multiarch}" ] ||
        deb_multiarch=$(gcc -print-multiarch 2>/dev/null)
      if [ -z "${deb_multiarch}" ] ||
        [ ! -d "/usr/lib/${deb_multiarch}" ]; then
        echo "${CFAILURE}Unable to determine the Debian multiarch LDAP library directory.${CEND}"
        return 1
      fi
      ./configure \
        --with-php-config="${php_install_dir}/bin/php-config" \
        --with-ldap=/usr \
        --with-ldap-sasl \
        --with-libdir="lib/${deb_multiarch}" || return 1
    fi
    make -j "${THREAD}" && make install
  ) || return 1

  if [ -f "${php_extension_dir}/ldap.so" ]; then
    echo 'extension=ldap.so' > "${php_install_dir}/etc/php.d/04-ldap.ini"
    echo "${CSUCCESS}PHP ldap module installed successfully! ${CEND}"
    return 0
  fi

  echo "${CFAILURE}PHP ldap module install failed, Please contact the author! ${CEND}"
  grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
  return 1
}

Uninstall_pecl_ldap() {
  if [ -e "${php_install_dir}/etc/php.d/04-ldap.ini" ]; then
    rm -f "${php_install_dir}/etc/php.d/04-ldap.ini"
    echo
    echo "${CMSG}PHP ldap module uninstall completed${CEND}"
  else
    echo
    echo "${CWARNING}PHP ldap module does not exist! ${CEND}"
  fi
}
