#!/bin/bash
# Author:  OneinStack
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Install_pecl_igbinary() {
  if [ -e "${php_install_dir}/bin/phpize" ]; then
    pushd ${oneinstack_dir}/src > /dev/null
    phpExtensionDir=$(${php_install_dir}/bin/php-config --extension-dir)
    PHP_detail_ver=$(${php_install_dir}/bin/php-config --version)
    PHP_main_ver=${PHP_detail_ver%.*}
    if [[ "${PHP_main_ver}" =~ ^5\.[3-6]$ ]]; then
      src_url=https://pecl.php.net/get/igbinary-2.0.8.tgz && Download_src
      tar xzf igbinary-2.0.8.tgz
      pushd igbinary-2.0.8 > /dev/null
    else
      src_url=https://pecl.php.net/get/igbinary-${igbinary_ver}.tgz && Download_src
      tar xzf igbinary-${igbinary_ver}.tgz
      pushd igbinary-${igbinary_ver} > /dev/null
    fi
    ${php_install_dir}/bin/phpize
    ./configure --with-php-config=${php_install_dir}/bin/php-config
    make -j ${THREAD} && make install
    popd > /dev/null
    if [ -f "${phpExtensionDir}/igbinary.so" ]; then
      echo 'extension=igbinary.so' > ${php_install_dir}/etc/php.d/04-igbinary.ini
      echo "${CSUCCESS}PHP igbinary module installed successfully! ${CEND}"
      rm -rf igbinary-${igbinary_ver} igbinary-2.0.8
    else
      echo "${CFAILURE}PHP igbinary module install failed, Please contact the author! ${CEND}" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
    fi
    popd > /dev/null
  fi
}

Uninstall_pecl_igbinary() {
  if [ -e "${php_install_dir}/etc/php.d/04-igbinary.ini" ]; then
    rm -f ${php_install_dir}/etc/php.d/04-igbinary.ini
    echo; echo "${CMSG}PHP igbinary module uninstall completed${CEND}"
  else
    echo; echo "${CWARNING}PHP igbinary module does not exist! ${CEND}"
  fi
}
