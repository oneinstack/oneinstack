#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Install_pecl_imap() {
  if [ -e "${php_install_dir}/bin/phpize" ]; then
    pushd ${oneinstack_dir}/src > /dev/null
    if [ "${PM}" == 'yum' ]; then
      if [ "${RHEL_ver}" == '9' ]; then
        # The official release package installs the signed repository configuration and GPG key.
        # 官方 release 包负责安装带签名校验的仓库配置和 GPG 密钥。
        dnf -y install https://rpms.remirepo.net/enterprise/remi-release-9.rpm &&
          dnf -y --enablerepo=remi install uw-imap-devel || return 1
      else
        yum -y install libc-client-devel
        [ ! -e /usr/lib/libc-client.so ] && ln -s /usr/lib64/libc-client.so /usr/lib/libc-client.so
      fi
    else
      apt-get -y install libc-client2007e-dev
    fi
    phpExtensionDir=$(${php_install_dir}/bin/php-config --extension-dir)
    PHP_detail_ver=$(${php_install_dir}/bin/php-config --version)
    PHP_main_ver=${PHP_detail_ver%.*}
    if [[ "${PHP_main_ver}" =~ ^8\.[4-5]$ ]]; then
      # IMAP was unbundled from PHP 8.4 and is maintained as a PECL extension.
      # IMAP 从 PHP 8.4 起移出主源码，改用 PECL 扩展。
      src_url=https://pecl.php.net/get/imap-${pecl_imap_ver}.tgz && Download_src
      tar xzf imap-${pecl_imap_ver}.tgz
      pushd imap-${pecl_imap_ver} > /dev/null
    else
      src_url=https://secure.php.net/distributions/php-${PHP_detail_ver}.tar.gz && Download_src
      tar xzf php-${PHP_detail_ver}.tar.gz
      pushd php-${PHP_detail_ver}/ext/imap > /dev/null
    fi
    ${php_install_dir}/bin/phpize
    ./configure --with-php-config=${php_install_dir}/bin/php-config --with-kerberos --with-imap --with-imap-ssl
    make -j ${THREAD} && make install
    popd > /dev/null
    if [ -f "${phpExtensionDir}/imap.so" ]; then
      echo 'extension=imap.so' > ${php_install_dir}/etc/php.d/04-imap.ini
      echo "${CSUCCESS}PHP imap module installed successfully! ${CEND}"
      rm -rf php-${PHP_detail_ver} imap-${pecl_imap_ver}
    else
      echo "${CFAILURE}PHP imap module install failed, Please contact the author! ${CEND}" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
    fi
    popd > /dev/null
  fi
}

Uninstall_pecl_imap() {
  if [ -e "${php_install_dir}/etc/php.d/04-imap.ini" ]; then
    rm -f ${php_install_dir}/etc/php.d/04-imap.ini
    echo; echo "${CMSG}PHP imap module uninstall completed${CEND}"
  else
    echo; echo "${CWARNING}PHP imap module does not exist! ${CEND}"
  fi
}
