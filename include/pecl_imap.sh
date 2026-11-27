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
    if ${php_install_dir}/bin/php -m 2>/dev/null | grep -qiw '^imap$'; then
      echo "${CSUCCESS}PHP imap module is already enabled! ${CEND}"
      return 0
    fi
    if [ -f "${php_install_dir}/.install_method" ]; then
      local _php_method _remi_pkg _apt_pkg
      _php_method=$(awk -F= '/^method=/{print $2}' "${php_install_dir}/.install_method" 2>/dev/null)
      _remi_pkg=$(awk -F= '/^remi_pkg=/{print $2}' "${php_install_dir}/.install_method" 2>/dev/null)
      _apt_pkg=$(awk -F= '/^apt_pkg=/{print $2}' "${php_install_dir}/.install_method" 2>/dev/null)
      if [ "${_php_method}" == "dnf" ] && [ -n "${_remi_pkg}" ] && command -v dnf >/dev/null 2>&1; then
        type PHP_DNF_Build_Repo_Args >/dev/null 2>&1 || . "${oneinstack_dir}/include/php_dnf.sh"
        PHP_DNF_Build_Repo_Args
        dnf -y ${PHP_DNF_REPO_ARGS} install "${_remi_pkg}-php-imap" >/dev/null 2>&1 || \
          dnf -y ${PHP_DNF_REPO_ARGS} install "${_remi_pkg}-php-pecl-imap" >/dev/null 2>&1 || true
        if ${php_install_dir}/bin/php -m 2>/dev/null | grep -qiw '^imap$'; then
          echo "${CSUCCESS}PHP imap module installed successfully via DNF! ${CEND}"
          return 0
        fi
      elif [ "${_php_method}" == "apt" ] && [ -n "${_apt_pkg}" ] && command -v apt-get >/dev/null 2>&1; then
        DEBIAN_FRONTEND=noninteractive apt-get --no-install-recommends -y install "${_apt_pkg}-imap" >/dev/null 2>&1 || true
        if ${php_install_dir}/bin/php -m 2>/dev/null | grep -qiw '^imap$'; then
          echo "${CSUCCESS}PHP imap module installed successfully via APT! ${CEND}"
          return 0
        fi
      fi
    fi
    pushd ${oneinstack_dir}/src > /dev/null
    if [ "${PM}" == 'yum' ]; then
      if [ "${RHEL_ver}" == '9' ]; then
        [ ! -e /etc/yum.repos.d/remi.repo ] && cat > /etc/yum.repos.d/remi.repo << EOF
[remi]
name=Remi's RPM repository for Enterprise Linux 9 - \$basearch
mirrorlist=http://cdn.remirepo.net/enterprise/9/remi/\$basearch/mirror
enabled=0
gpgcheck=0
EOF
        dnf -y --enablerepo=remi install uw-imap-devel
      else
        yum -y install libc-client-devel
        [ ! -e /usr/lib/libc-client.so ] && ln -s /usr/lib64/libc-client.so /usr/lib/libc-client.so
      fi
    else
      apt-get -y install libc-client2007e-dev
    fi
    phpExtensionDir=$(${php_install_dir}/bin/php-config --extension-dir)
    PHP_detail_ver=$(${php_install_dir}/bin/php-config --version)
    src_url=https://www.php.net/distributions/php-${PHP_detail_ver}.tar.gz && Download_src
    tar xzf php-${PHP_detail_ver}.tar.gz
    pushd php-${PHP_detail_ver}/ext/imap > /dev/null
    ${php_install_dir}/bin/phpize
    ./configure --with-php-config=${php_install_dir}/bin/php-config --with-kerberos --with-imap --with-imap-ssl
    make -j ${THREAD} && make install
    popd > /dev/null
    if [ -f "${phpExtensionDir}/imap.so" ]; then
      echo 'extension=imap.so' > ${php_install_dir}/etc/php.d/04-imap.ini
      echo "${CSUCCESS}PHP imap module installed successfully! ${CEND}"
      rm -rf php-${PHP_detail_ver}
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
  elif [ -f "${php_install_dir}/.install_method" ]; then
    local _php_method _remi_pkg _apt_pkg
    _php_method=$(awk -F= '/^method=/{print $2}' "${php_install_dir}/.install_method" 2>/dev/null)
    _remi_pkg=$(awk -F= '/^remi_pkg=/{print $2}' "${php_install_dir}/.install_method" 2>/dev/null)
    _apt_pkg=$(awk -F= '/^apt_pkg=/{print $2}' "${php_install_dir}/.install_method" 2>/dev/null)
    if [ "${_php_method}" == "dnf" ] && [ -n "${_remi_pkg}" ] && command -v dnf >/dev/null 2>&1 && (rpm -q "${_remi_pkg}-php-imap" >/dev/null 2>&1 || rpm -q "${_remi_pkg}-php-pecl-imap" >/dev/null 2>&1); then
      dnf -y remove "${_remi_pkg}-php-imap" "${_remi_pkg}-php-pecl-imap"
      echo; echo "${CMSG}PHP imap module uninstall completed${CEND}"
    elif [ "${_php_method}" == "apt" ] && [ -n "${_apt_pkg}" ] && command -v apt-get >/dev/null 2>&1 && dpkg -s "${_apt_pkg}-imap" >/dev/null 2>&1; then
      DEBIAN_FRONTEND=noninteractive apt-get -y purge "${_apt_pkg}-imap"
      echo; echo "${CMSG}PHP imap module uninstall completed${CEND}"
    else
      echo; echo "${CWARNING}PHP imap module does not exist! ${CEND}"
    fi
  else
    echo; echo "${CWARNING}PHP imap module does not exist! ${CEND}"
  fi
}
