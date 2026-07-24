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
  if [ ! -e "${php_install_dir}/bin/phpize" ]; then
    echo "${CFAILURE}PHP phpize is required to install fileinfo.${CEND}"
    return 1
  fi

  if "${php_install_dir}/bin/php" -r "exit(extension_loaded('fileinfo') ? 0 : 1);"; then
    echo "${CSUCCESS}PHP fileinfo module is already built in and loaded.${CEND}"
    return 0
  fi

  pushd ${oneinstack_dir}/src > /dev/null || return 1
    phpExtensionDir=$(${php_install_dir}/bin/php-config --extension-dir)
    PHP_detail_ver=$(${php_install_dir}/bin/php-config --version)
    PHP_main_ver=${PHP_detail_ver%.*}
    src_url=https://www.php.net/distributions/php-${PHP_detail_ver}.tar.gz
    [ "${PHP_detail_ver}" = "${php85_ver}" ] && src_checksum=${php85_checksum:-}
    Download_src no_kill || return 1
    tar xzf php-${PHP_detail_ver}.tar.gz || return 1
    pushd php-${PHP_detail_ver}/ext/fileinfo > /dev/null || return 1
    ${php_install_dir}/bin/phpize || return 1
    ./configure --with-php-config=${php_install_dir}/bin/php-config || return 1
    # PHP 8.4+ requires a C11 compiler; retain the legacy C99 workaround only for older PHP.
    # PHP 8.4+ 要求 C11 编译器，仅对旧版 PHP 保留 C99 兼容处理。
    [[ ! "${PHP_main_ver}" =~ ^8\.[4-5]$ ]] && sed -i 's@^CFLAGS =.*@CFLAGS = -std=c99 -g@' Makefile
    make -j ${THREAD} && make install || return 1
    popd > /dev/null
    if [ -f "${phpExtensionDir}/fileinfo.so" ]; then
      echo 'extension=fileinfo.so' > ${php_install_dir}/etc/php.d/04-fileinfo.ini
      echo "${CSUCCESS}PHP fileinfo module installed successfully! ${CEND}"
      rm -rf php-${PHP_detail_ver}
    else
      echo "${CFAILURE}PHP fileinfo module install failed, Please contact the author! ${CEND}"
      grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
      return 1
    fi
    popd > /dev/null
}

Uninstall_pecl_fileinfo() {
  if [ -e "${php_install_dir}/etc/php.d/04-fileinfo.ini" ]; then
    rm -f ${php_install_dir}/etc/php.d/04-fileinfo.ini
    echo; echo "${CMSG}PHP fileinfo module uninstall completed${CEND}"
  else
    echo; echo "${CWARNING}PHP fileinfo module does not exist! ${CEND}"
  fi
}
