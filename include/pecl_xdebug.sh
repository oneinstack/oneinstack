#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Install_pecl_xdebug() {
  if [ ! -e "${php_install_dir}/bin/phpize" ]; then
    echo "${CFAILURE}PHP phpize is required to install xdebug.${CEND}"
    return 1
  fi

    pushd ${oneinstack_dir}/src > /dev/null || return 1
    phpExtensionDir=$(${php_install_dir}/bin/php-config --extension-dir)
    PHP_detail_ver=$(${php_install_dir}/bin/php-config --version)
    PHP_main_ver=${PHP_detail_ver%.*}
    if [[ "${PHP_main_ver}" =~ ^7\.[0-4]$|^8\.[0-5]$ ]]; then
      if [[ "${PHP_main_ver}" =~ ^7\.[0-1]$ ]]; then
        src_url=https://pecl.php.net/get/xdebug-${xdebug_oldver}.tgz
        Download_src no_kill || return 1
        tar xzf xdebug-${xdebug_oldver}.tgz || return 1
        pushd xdebug-${xdebug_oldver} > /dev/null || return 1
      else
        src_url=https://pecl.php.net/get/xdebug-${xdebug_ver}.tgz
        src_checksum=${xdebug_checksum:-}
        Download_src no_kill || return 1
        tar xzf xdebug-${xdebug_ver}.tgz || return 1
        pushd xdebug-${xdebug_ver} > /dev/null || return 1
      fi
      ${php_install_dir}/bin/phpize || return 1
      ./configure --with-php-config=${php_install_dir}/bin/php-config || return 1
      make -j ${THREAD} && make install || return 1
      popd > /dev/null
      if [ -f "${phpExtensionDir}/xdebug.so" ]; then
        [ ! -e /tmp/xdebug ] && { mkdir /tmp/xdebug; chown ${run_user}:${run_group} /tmp/xdebug; }
        if [[ "${PHP_main_ver}" =~ ^7\.[0-1]$ ]]; then
          cat > ${php_install_dir}/etc/php.d/08-xdebug.ini << EOF
[xdebug]
zend_extension=xdebug.so
xdebug.trace_output_dir=/tmp/xdebug
xdebug.profiler_output_dir = /tmp/xdebug
xdebug.profiler_enable = On
xdebug.profiler_enable_trigger = 1
EOF
        else
          cat > ${php_install_dir}/etc/php.d/08-xdebug.ini << EOF
[xdebug]
zend_extension=xdebug.so
xdebug.mode=profile
xdebug.output_dir=/tmp/xdebug
xdebug.start_with_request=trigger
EOF
        fi
        echo "${CSUCCESS}PHP xdebug module installed successfully! ${CEND}"
        rm -rf xdebug-${xdebug_ver} xdebug-${xdebug_oldver}
      else
        echo "${CFAILURE}PHP xdebug module install failed, Please contact the author! ${CEND}"
        grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
        return 1
      fi
    else
      echo "${CWARNING}Your php ${PHP_detail_ver} does not support xdebug! ${CEND}"
      return 1
    fi
    popd > /dev/null
}

Uninstall_pecl_xdebug() {
  if [ -e "${php_install_dir}/etc/php.d/08-xdebug.ini" ]; then
    rm -rf ${php_install_dir}/etc/php.d/08-xdebug.ini /tmp/{xdebug,webgrind} ${wwwroot_dir}/default/webgrind
    echo; echo "${CMSG}PHP xdebug module uninstall completed${CEND}"
  else
    echo; echo "${CWARNING}PHP xdebug module does not exist! ${CEND}"
  fi
}
