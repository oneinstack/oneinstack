#!/bin/bash
# Author:  OneinStack
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Install_pecl_grpc() {
  if [ -e "${php_install_dir}/bin/phpize" ]; then
    pushd ${oneinstack_dir}/src > /dev/null
    phpExtensionDir=$(${php_install_dir}/bin/php-config --extension-dir)
    src_url=https://pecl.php.net/get/grpc-${grpc_ver}.tgz && Download_src
    tar xzf grpc-${grpc_ver}.tgz
    pushd grpc-${grpc_ver} > /dev/null
    ${php_install_dir}/bin/phpize
    ./configure --with-php-config=${php_install_dir}/bin/php-config
    make -j ${THREAD} && make install
    popd > /dev/null
    if [ -f "${phpExtensionDir}/grpc.so" ]; then
      echo 'extension=grpc.so' > ${php_install_dir}/etc/php.d/06-grpc.ini
      echo "${CSUCCESS}PHP grpc module installed successfully! ${CEND}"
      rm -rf grpc-${grpc_ver}
    else
      echo "${CFAILURE}PHP grpc module install failed, Please contact the author! ${CEND}" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
    fi
    popd > /dev/null
  fi
}

Uninstall_pecl_grpc() {
  if [ -e "${php_install_dir}/etc/php.d/06-grpc.ini" ]; then
    rm -f ${php_install_dir}/etc/php.d/06-grpc.ini
    echo; echo "${CMSG}PHP grpc module uninstall completed${CEND}"
  else
    echo; echo "${CWARNING}PHP grpc module does not exist! ${CEND}"
  fi
}
