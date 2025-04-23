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
  if [ -e "${php_install_dir}/bin/phpize" ]; then
    pushd ${oneinstack_dir}/src > /dev/null
    phpExtensionDir=$(${php_install_dir}/bin/php-config --extension-dir)
    PHP_detail_ver=$(${php_install_dir}/bin/php-config --version)
    PHP_main_ver=${PHP_detail_ver%.*}
    if [[ "${PHP_main_ver}" =~ ^7.[0-4]$|^8.[0-2]$ ]]; then
      if [[ "${PHP_main_ver}" =~ ^7.[0-1]$ ]]; then
        src_url=https://pecl.php.net/get/xdebug-${xdebug_oldver}.tgz && Download_src
        tar xzf xdebug-${xdebug_oldver}.tgz
        pushd xdebug-${xdebug_oldver} > /dev/null
      else
        src_url=https://pecl.php.net/get/xdebug-${xdebug_ver}.tgz && Download_src
        tar xzf xdebug-${xdebug_ver}.tgz
        pushd xdebug-${xdebug_ver} > /dev/null
      fi
      ${php_install_dir}/bin/phpize
      ./configure --with-php-config=${php_install_dir}/bin/php-config
      make -j ${THREAD} && make install
      popd > /dev/null
      if [ -f "${phpExtensionDir}/xdebug.so" ]; then
        src_url=${mirror_link}/oneinstack/src/webgrind-master.zip && Download_src
        unzip -q webgrind-master.zip
        /bin/mv webgrind-master ${wwwroot_dir}/default/webgrind
        [ ! -e /tmp/xdebug ] && { mkdir /tmp/xdebug; chown ${run_user}:${run_group} /tmp/xdebug; }
        [ ! -e /tmp/webgrind ] && { mkdir /tmp/webgrind; chown ${run_user}:${run_group} /tmp/webgrind; }
        chown -R ${run_user}:${run_group} ${wwwroot_dir}/default/webgrind
        sed -i 's@static $storageDir.*@static $storageDir = "/tmp/webgrind";@' ${wwwroot_dir}/default/webgrind/config.php
        sed -i 's@static $profilerDir.*@static $profilerDir = "/tmp/xdebug";@' ${wwwroot_dir}/default/webgrind/config.php
        cat > ${php_install_dir}/etc/php.d/08-xdebug.ini << EOF
[xdebug]
zend_extension=xdebug.so
xdebug.trace_output_dir=/tmp/xdebug
xdebug.profiler_output_dir = /tmp/xdebug
xdebug.profiler_enable = On
xdebug.profiler_enable_trigger = 1
EOF
        echo "${CSUCCESS}PHP xdebug module installed successfully! ${CEND}"
        echo; echo "Webgrind URL: ${CMSG}http://{Public IP}/webgrind ${CEND}"
        rm -rf xdebug-${xdebug_ver} xdebug-${xdebug_oldver}
      else
        echo "${CFAILURE}PHP xdebug module install failed, Please contact the author! ${CEND}" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
      fi
    else
      echo "${CWARNING}Your php ${PHP_detail_ver} does not support xdebug! ${CEND}";
    fi
    popd > /dev/null
  fi
}

Uninstall_pecl_xdebug() {
  if [ -e "${php_install_dir}/etc/php.d/08-xdebug.ini" ]; then
    rm -rf ${php_install_dir}/etc/php.d/08-xdebug.ini /tmp/{xdebug,webgrind} ${wwwroot_dir}/default/webgrind
    echo; echo "${CMSG}PHP xdebug module uninstall completed${CEND}"
  else
    echo; echo "${CWARNING}PHP xdebug module does not exist! ${CEND}"
  fi
}
