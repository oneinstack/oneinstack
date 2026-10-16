#!/bin/bash
# Author:  OneinStack
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Install_pecl_xlswriter() {
  if [ -e "${php_install_dir}/bin/phpize" ]; then
    pushd ${oneinstack_dir}/src > /dev/null
    phpExtensionDir=$(${php_install_dir}/bin/php-config --extension-dir)
    PHP_detail_ver=$(${php_install_dir}/bin/php-config --version)
    PHP_main_ver=${PHP_detail_ver%.*}
    src_url=https://pecl.php.net/get/xlswriter-${xlswriter_ver}.tgz && Download_src
    tar xzf xlswriter-${xlswriter_ver}.tgz
    pushd xlswriter-${xlswriter_ver} > /dev/null
    ${php_install_dir}/bin/phpize
    ./configure --with-php-config=${php_install_dir}/bin/php-config --enable-reader
    make -j ${THREAD} && make install
    popd > /dev/null
    if [ -f "${phpExtensionDir}/xlswriter.so" ]; then
      echo 'extension=xlswriter.so' > ${php_install_dir}/etc/php.d/06-xlswriter.ini
      echo "${CSUCCESS}PHP xlswriter module installed successfully! ${CEND}"
      rm -rf xlswriter-${xlswriter_ver}
    else
      echo "${CFAILURE}PHP xlswriter module install failed, Please contact the author! ${CEND}" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
    fi
    popd > /dev/null
  fi
}

Uninstall_pecl_xlswriter() {
  if [ -e "${php_install_dir}/etc/php.d/06-xlswriter.ini" ]; then
    rm -f ${php_install_dir}/etc/php.d/06-xlswriter.ini
    echo; echo "${CMSG}PHP xlswriter module uninstall completed${CEND}"
  else
    echo; echo "${CWARNING}PHP xlswriter module does not exist! ${CEND}"
  fi
}
