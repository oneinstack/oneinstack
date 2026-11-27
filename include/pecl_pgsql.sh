#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Install_pecl_pgsql() {
  if [ -e "${php_install_dir}/bin/phpize" ]; then
    if ${php_install_dir}/bin/php -m 2>/dev/null | grep -qiw '^pgsql$' && ${php_install_dir}/bin/php -m 2>/dev/null | grep -qiw '^pdo_pgsql$'; then
      echo "${CSUCCESS}PHP pgsql module is already enabled! ${CEND}"
      return 0
    fi
    if [ -f "${php_install_dir}/.install_method" ] && command -v dnf >/dev/null 2>&1; then
      local _php_method _remi_pkg
      _php_method=$(awk -F= '/^method=/{print $2}' "${php_install_dir}/.install_method" 2>/dev/null)
      _remi_pkg=$(awk -F= '/^remi_pkg=/{print $2}' "${php_install_dir}/.install_method" 2>/dev/null)
      if [ "${_php_method}" == "dnf" ] && [ -n "${_remi_pkg}" ]; then
        type PHP_DNF_Build_Repo_Args >/dev/null 2>&1 || . "${oneinstack_dir}/include/php_dnf.sh"
        PHP_DNF_Build_Repo_Args
        dnf -y ${PHP_DNF_REPO_ARGS} install "${_remi_pkg}-php-pgsql" >/dev/null 2>&1 || true
        if ${php_install_dir}/bin/php -m 2>/dev/null | grep -qiw '^pgsql$' && ${php_install_dir}/bin/php -m 2>/dev/null | grep -qiw '^pdo_pgsql$'; then
          echo "${CSUCCESS}PHP pgsql module installed successfully via DNF! ${CEND}"
          return 0
        fi
      fi
    fi
    pushd ${oneinstack_dir}/src > /dev/null
    phpExtensionDir=`${php_install_dir}/bin/php-config --extension-dir`
    PHP_detail_ver=$(${php_install_dir}/bin/php-config --version)
    src_url=https://www.php.net/distributions/php-${PHP_detail_ver}.tar.gz && Download_src
    tar xzf php-${PHP_detail_ver}.tar.gz
    pushd php-${PHP_detail_ver}/ext/pgsql > /dev/null
    ${php_install_dir}/bin/phpize
    ./configure --with-pgsql=${pgsql_install_dir} --with-php-config=${php_install_dir}/bin/php-config
    make -j ${THREAD} && make install
    popd > /dev/null
    pushd php-${PHP_detail_ver}/ext/pdo_pgsql > /dev/null
    ${php_install_dir}/bin/phpize
    ./configure --with-pdo-pgsql=${pgsql_install_dir} --with-php-config=${php_install_dir}/bin/php-config
    make -j ${THREAD} && make install
    popd > /dev/null
    if [ -f "${phpExtensionDir}/pgsql.so" -a -f "${phpExtensionDir}/pdo_pgsql.so" ]; then
      echo 'extension=pgsql.so' > ${php_install_dir}/etc/php.d/07-pgsql.ini
      echo 'extension=pdo_pgsql.so' >> ${php_install_dir}/etc/php.d/07-pgsql.ini
      echo "${CSUCCESS}PHP pgsql module installed successfully! ${CEND}"
      rm -rf php-${PHP_detail_ver}
    else
      echo "${CFAILURE}PHP pgsql module install failed, Please contact the author! ${CEND}" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
    fi
    popd > /dev/null
  fi
}

Uninstall_pecl_pgsql() {
  if [ -e "${php_install_dir}/etc/php.d/07-pgsql.ini" ]; then
    rm -f ${php_install_dir}/etc/php.d/07-pgsql.ini
    echo; echo "${CMSG}PHP pgsql module uninstall completed${CEND}"
  elif [ -f "${php_install_dir}/.install_method" ] && command -v dnf >/dev/null 2>&1; then
    local _php_method _remi_pkg
    _php_method=$(awk -F= '/^method=/{print $2}' "${php_install_dir}/.install_method" 2>/dev/null)
    _remi_pkg=$(awk -F= '/^remi_pkg=/{print $2}' "${php_install_dir}/.install_method" 2>/dev/null)
    if [ "${_php_method}" == "dnf" ] && [ -n "${_remi_pkg}" ] && rpm -q "${_remi_pkg}-php-pgsql" >/dev/null 2>&1; then
      dnf -y remove "${_remi_pkg}-php-pgsql"
      echo; echo "${CMSG}PHP pgsql module uninstall completed${CEND}"
    else
      echo; echo "${CWARNING}PHP pgsql module does not exist! ${CEND}"
    fi
  else
    echo; echo "${CWARNING}PHP pgsql module does not exist! ${CEND}"
  fi
}
