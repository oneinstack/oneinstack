#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Install_pecl_swoole() {
  local swoole_configure_args

  if [ ! -e "${php_install_dir}/bin/phpize" ]; then
    echo "${CFAILURE}PHP phpize is required to install swoole.${CEND}"
    return 1
  fi

    pushd ${oneinstack_dir}/src > /dev/null || return 1
    phpExtensionDir=$(${php_install_dir}/bin/php-config --extension-dir)
    PHP_detail_ver=$(${php_install_dir}/bin/php-config --version)
    PHP_main_ver=${PHP_detail_ver%.*}
    if [[ "${PHP_main_ver}" =~ ^5.[3-6]$ ]]; then
      src_url=https://pecl.php.net/get/swoole-1.10.5.tgz && Download_src
      tar xzf swoole-1.10.5.tgz || return 1
      pushd swoole-1.10.5 > /dev/null || return 1
      ${php_install_dir}/bin/phpize || return 1
      ./configure --with-php-config=${php_install_dir}/bin/php-config \
        --enable-openssl --with-openssl-dir=${openssl_install_dir} || return 1
    elif [[ "${PHP_main_ver}" =~ ^7.[0-1]$ ]]; then
      src_url=https://pecl.php.net/get/swoole-4.5.2.tgz && Download_src
      tar xzf swoole-4.5.2.tgz || return 1
      pushd swoole-4.5.2 > /dev/null || return 1
      ${php_install_dir}/bin/phpize || return 1
      ./configure --with-php-config=${php_install_dir}/bin/php-config \
        --enable-openssl --with-openssl-dir=${openssl_install_dir} || return 1
    elif [[ "${PHP_main_ver}" =~ ^7.[2-4]$ ]]; then
      src_url=https://pecl.php.net/get/swoole-${swoole_oldver}.tgz && Download_src
      tar xzf swoole-${swoole_oldver}.tgz || return 1
      pushd swoole-${swoole_oldver} > /dev/null || return 1
      ${php_install_dir}/bin/phpize || return 1
      ./configure --with-php-config=${php_install_dir}/bin/php-config \
        --enable-openssl --with-openssl-dir=${openssl_install_dir} \
        --enable-http2 --enable-swoole-json --enable-swoole-curl || return 1
    elif [ "${PHP_main_ver}" == '8.5' ]; then
      src_url=https://pecl.php.net/get/swoole-${swoole_up_ver}.tgz
      src_checksum=${swoole_up_checksum:-}
      Download_src no_kill || return 1
      tar xzf swoole-${swoole_up_ver}.tgz || return 1
      pushd swoole-${swoole_up_ver} > /dev/null || return 1
      ${php_install_dir}/bin/phpize || return 1
      # Swoole 6 removed --enable-openssl, --enable-http2 and
      # --enable-swoole-json. With no custom prefix it discovers system
      # OpenSSL through pkg-config.
      # Swoole 6 已移除上述旧参数；没有自编译 OpenSSL 时通过 pkg-config
      # 使用系统库，不能强行指向不存在的 /usr/local/openssl。
      swoole_configure_args=(
        "--with-php-config=${php_install_dir}/bin/php-config"
        "--enable-swoole-curl"
      )
      if [ -f "${openssl_install_dir}/include/openssl/ssl.h" ] &&
        { [ -f "${openssl_install_dir}/lib/libssl.so" ] ||
          [ -f "${openssl_install_dir}/lib/libssl.a" ] ||
          [ -f "${openssl_install_dir}/lib64/libssl.so" ] ||
          [ -f "${openssl_install_dir}/lib64/libssl.a" ]; }; then
        swoole_configure_args+=("--with-openssl-dir=${openssl_install_dir}")
      fi
      ./configure "${swoole_configure_args[@]}" || return 1
    else
      src_url=https://pecl.php.net/get/swoole-${swoole_ver}.tgz && Download_src
      tar xzf swoole-${swoole_ver}.tgz || return 1
      pushd swoole-${swoole_ver} > /dev/null || return 1
      ${php_install_dir}/bin/phpize || return 1
      swoole_configure_args=(
        "--with-php-config=${php_install_dir}/bin/php-config"
        "--enable-swoole-curl"
      )
      if [ -f "${openssl_install_dir}/include/openssl/ssl.h" ] &&
        { [ -f "${openssl_install_dir}/lib/libssl.so" ] ||
          [ -f "${openssl_install_dir}/lib/libssl.a" ] ||
          [ -f "${openssl_install_dir}/lib64/libssl.so" ] ||
          [ -f "${openssl_install_dir}/lib64/libssl.a" ]; }; then
        swoole_configure_args+=("--with-openssl-dir=${openssl_install_dir}")
      fi
      ./configure "${swoole_configure_args[@]}" || return 1
    fi
    make -j ${THREAD} && make install || return 1
    popd > /dev/null
    if [ -f "${phpExtensionDir}/swoole.so" ]; then
      echo 'extension=swoole.so' > ${php_install_dir}/etc/php.d/06-swoole.ini
      echo "${CSUCCESS}PHP swoole module installed successfully! ${CEND}"
      rm -rf swoole-${swoole_up_ver} swoole-${swoole_ver} swoole-${swoole_oldver} swoole-1.10.5 swoole-4.5.2
    else
      echo "${CFAILURE}PHP swoole module install failed, Please contact the author! ${CEND}"
      grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
      return 1
    fi
    popd > /dev/null
}

Uninstall_pecl_swoole() {
  if [ -e "${php_install_dir}/etc/php.d/06-swoole.ini" ]; then
    rm -f ${php_install_dir}/etc/php.d/06-swoole.ini
    echo; echo "${CMSG}PHP swoole module uninstall completed${CEND}"
  else
    echo; echo "${CWARNING}PHP swoole module does not exist! ${CEND}"
  fi
}
