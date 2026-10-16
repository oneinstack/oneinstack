#!/bin/bash
# Author:  OneinStack
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Install_pecl_msgpack() {
  if [ -e "${php_install_dir}/bin/phpize" ]; then
    pushd ${oneinstack_dir}/src > /dev/null
    phpExtensionDir=$(${php_install_dir}/bin/php-config --extension-dir)
    PHP_detail_ver=$(${php_install_dir}/bin/php-config --version)
    PHP_main_ver=${PHP_detail_ver%.*}
    if [[ "${PHP_main_ver}" =~ ^5\.[3-6]$ ]]; then
      src_url=https://pecl.php.net/get/msgpack-0.5.7.tgz && Download_src
      tar xzf msgpack-0.5.7.tgz
      pushd msgpack-0.5.7 > /dev/null
    elif [[ "${PHP_main_ver}" =~ ^7\.[0-4]$ ]]; then
      src_url=https://pecl.php.net/get/msgpack-${msgpack_oldver}.tgz && Download_src
      tar xzf msgpack-${msgpack_oldver}.tgz
      pushd msgpack-${msgpack_oldver} > /dev/null
    else
      src_url=https://pecl.php.net/get/msgpack-${msgpack_ver}.tgz && Download_src
      tar xzf msgpack-${msgpack_ver}.tgz
      pushd msgpack-${msgpack_ver} > /dev/null
    fi
    ${php_install_dir}/bin/phpize
    ./configure --with-php-config=${php_install_dir}/bin/php-config
    make -j ${THREAD} && make install
    popd > /dev/null
    if [ -f "${phpExtensionDir}/msgpack.so" ]; then
      echo 'extension=msgpack.so' > ${php_install_dir}/etc/php.d/04-msgpack.ini
      echo "${CSUCCESS}PHP msgpack module installed successfully! ${CEND}"
      rm -rf msgpack-${msgpack_ver} msgpack-${msgpack_oldver} msgpack-0.5.7
    else
      echo "${CFAILURE}PHP msgpack module install failed, Please contact the author! ${CEND}" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
    fi
    popd > /dev/null
  fi
}

Uninstall_pecl_msgpack() {
  if [ -e "${php_install_dir}/etc/php.d/04-msgpack.ini" ]; then
    rm -f ${php_install_dir}/etc/php.d/04-msgpack.ini
    echo; echo "${CMSG}PHP msgpack module uninstall completed${CEND}"
  else
    echo; echo "${CWARNING}PHP msgpack module does not exist! ${CEND}"
  fi
}
