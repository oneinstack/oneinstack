#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Build_PHP_pgsql_extension() {
  local extension_name="$1"
  local configure_option="$2"
  local pg_config_dir="$3"

  (
    cd "${oneinstack_dir}/src/php-${PHP_detail_ver}/ext/${extension_name}" ||
      return 1
    "${php_install_dir}/bin/phpize" --clean >/dev/null 2>&1 || true
    "${php_install_dir}/bin/phpize" || return 1
    PATH="${pg_config_dir}:${PATH}" ./configure \
      --with-php-config="${php_install_dir}/bin/php-config" \
      "${configure_option}" || return 1
    make -j "${THREAD}" && make install
  )
}

Install_pecl_pgsql() {
  local pg_config_path pg_config_dir phpExtensionDir

  if [ ! -x "${php_install_dir}/bin/phpize" ] ||
    [ ! -x "${php_install_dir}/bin/php-config" ]; then
    echo "${CFAILURE}PHP phpize and php-config are required to install pgsql.${CEND}"
    return 1
  fi

  # Only the PostgreSQL client development files are required. The PHP driver
  # must remain independent from a local PostgreSQL server installation.
  # 这里只安装 PostgreSQL 客户端开发文件，PHP 驱动不再依赖本机数据库服务端。
  if [ "${PM}" = 'yum' ]; then
    yum -y install postgresql-devel ||
      yum -y install libpq-devel ||
      return 1
  else
    apt-get --no-install-recommends -y install libpq-dev || return 1
  fi

  pg_config_path=$(command -v pg_config 2>/dev/null)
  [ -n "${pg_config_path}" ] ||
    pg_config_path="${pgsql_install_dir}/bin/pg_config"
  if [ ! -x "${pg_config_path}" ]; then
    echo "${CFAILURE}pg_config was not found after installing PostgreSQL client headers.${CEND}"
    return 1
  fi
  pg_config_dir=${pg_config_path%/*}

  phpExtensionDir=$("${php_install_dir}/bin/php-config" --extension-dir) ||
    return 1
  PHP_detail_ver=$("${php_install_dir}/bin/php-config" --version) || return 1

  (
    cd "${oneinstack_dir}/src" || return 1
    src_url="https://www.php.net/distributions/php-${PHP_detail_ver}.tar.gz"
    [ "${PHP_detail_ver}" = "${php85_ver}" ] &&
      src_checksum=${php85_checksum:-}
    Download_src no_kill || return 1
    tar xzf "php-${PHP_detail_ver}.tar.gz"
  ) || return 1

  Build_PHP_pgsql_extension pgsql --with-pgsql "${pg_config_dir}" ||
    return 1
  Build_PHP_pgsql_extension pdo_pgsql --with-pdo-pgsql "${pg_config_dir}" ||
    return 1

  if [ -f "${phpExtensionDir}/pgsql.so" ] &&
    [ -f "${phpExtensionDir}/pdo_pgsql.so" ]; then
    {
      echo 'extension=pgsql.so'
      echo 'extension=pdo_pgsql.so'
    } > "${php_install_dir}/etc/php.d/07-pgsql.ini"
    echo "${CSUCCESS}PHP pgsql and pdo_pgsql modules installed successfully! ${CEND}"
    return 0
  fi

  echo "${CFAILURE}PHP pgsql module install failed, Please contact the author! ${CEND}"
  grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
  return 1
}

Uninstall_pecl_pgsql() {
  if [ -e "${php_install_dir}/etc/php.d/07-pgsql.ini" ]; then
    rm -f "${php_install_dir}/etc/php.d/07-pgsql.ini"
    echo
    echo "${CMSG}PHP pgsql and pdo_pgsql modules uninstall completed${CEND}"
  else
    echo
    echo "${CWARNING}PHP pgsql modules do not exist! ${CEND}"
  fi
}
