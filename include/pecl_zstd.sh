#!/bin/bash
# Author:  OneinStack
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Install_pecl_zstd() {
  if [ -e "${php_install_dir}/bin/phpize" ]; then
    pushd ${oneinstack_dir}/src > /dev/null
    phpExtensionDir=$(${php_install_dir}/bin/php-config --extension-dir)
    PHP_detail_ver=$(${php_install_dir}/bin/php-config --version)
    PHP_main_ver=${PHP_detail_ver%.*}
    if [[ "${PHP_main_ver}" =~ ^7\.[0-4]$|^8\.[0-5]$ ]]; then
      src_url=https://pecl.php.net/get/zstd-${zstd_ver}.tgz && Download_src
      tar xzf zstd-${zstd_ver}.tgz
      pushd zstd-${zstd_ver} > /dev/null
      ${php_install_dir}/bin/phpize
      ./configure --with-php-config=${php_install_dir}/bin/php-config
      make -j ${THREAD} && make install
      popd > /dev/null
      if [ -f "${phpExtensionDir}/zstd.so" ]; then
        echo 'extension=zstd.so' > ${php_install_dir}/etc/php.d/04-zstd.ini
        echo "${CSUCCESS}PHP zstd module installed successfully! ${CEND}"
        rm -rf zstd-${zstd_ver}
      else
        echo "${CFAILURE}PHP zstd module install failed, Please contact the author! ${CEND}" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
      fi
    else
      echo; echo "${CWARNING}Your php ${PHP_detail_ver} does not support zstd! ${CEND}"
    fi
    popd > /dev/null
  fi
}

Uninstall_pecl_zstd() {
  if [ -e "${php_install_dir}/etc/php.d/04-zstd.ini" ]; then
    rm -f ${php_install_dir}/etc/php.d/04-zstd.ini
    echo; echo "${CMSG}PHP zstd module uninstall completed${CEND}"
  else
    echo; echo "${CWARNING}PHP zstd module does not exist! ${CEND}"
  fi
}
