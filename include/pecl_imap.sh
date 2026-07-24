#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Install_UW_IMAP_From_Debian_Source() {
  local uw_imap_prefix=/usr/local/uw-imap
  local uw_imap_upstream_ver=${uw_imap_debian_ver%-*}
  local uw_imap_source_dir=uw-imap-${uw_imap_upstream_ver}
  local uw_imap_gcc14_patch=${oneinstack_dir}/src/uw-imap-gcc14.patch

  if [ -f "${uw_imap_prefix}/lib/libc-client.a" ] &&
    [ -f "${uw_imap_prefix}/include/c-client/c-client.h" ]; then
    return 0
  fi

  # Debian 13 removed the binary development package. Build Debian's patched
  # source package from the official archive with repository-pinned hashes.
  # Debian 13 已移除二进制开发包；从 Debian 官方归档取得带补丁的源码，
  # 并使用仓库固定的 SHA-256 校验后构建私有 c-client。
  apt-get --no-install-recommends -y install \
    dpkg-dev build-essential libpam0g-dev libssl-dev libkrb5-dev comerr-dev || return 1

  src_url=https://deb.debian.org/debian/pool/main/u/uw-imap/uw-imap_${uw_imap_debian_ver}.dsc
  src_checksum=sha256=${uw_imap_dsc_sha256}
  Download_src no_kill || return 1
  src_url=https://deb.debian.org/debian/pool/main/u/uw-imap/uw-imap_${uw_imap_upstream_ver}.orig.tar.gz
  src_checksum=sha256=${uw_imap_orig_sha256}
  Download_src no_kill || return 1
  src_url=https://deb.debian.org/debian/pool/main/u/uw-imap/uw-imap_${uw_imap_debian_ver}.debian.tar.xz
  src_checksum=sha256=${uw_imap_debian_sha256}
  Download_src no_kill || return 1

  rm -rf "${uw_imap_source_dir}"
  dpkg-source -x "uw-imap_${uw_imap_debian_ver}.dsc" || return 1
  # Debian 7 predates GCC 14's strict C diagnostics. Apply the complete fix
  # later shipped as Debian/Ubuntu 7.1, rather than suppressing compiler errors.
  # Debian 7 源码早于 GCC 14；应用发行版完整修复，不能用降级警告掩盖类型问题。
  if [ "$(File_SHA256 "${uw_imap_gcc14_patch}")" != "${uw_imap_gcc14_patch_sha256}" ]; then
    echo "${CFAILURE}UW-IMAP GCC 14 patch verification failed.${CEND}"
    return 1
  fi
  patch --batch --forward -d "${uw_imap_source_dir}" -p1 < "${uw_imap_gcc14_patch}" || return 1
  pushd "${uw_imap_source_dir}" > /dev/null || return 1
  touch ip6
  # UW-IMAP's build target mutates shared files (OSTYPE, osdepbas.c, and
  # symlinks) across several prerequisites and recursive make processes. It is
  # not parallel-safe; inherited jobserver flags reproduce "Already built" and
  # "osdepbas.c not found" races. Force the complete c-client build serially.
  # UW-IMAP 多个目标会并发改写同一批文件，必须清除外部并行参数并全程串行。
  MAKEFLAGS= make -j1 VERSION=2007e EXTRAAUTHENTICATORS=gss \
    EXTRACFLAGS='-fPIC -D_REENTRANT -DDISABLE_POP_PROXY' ldb || return 1

  install -d "${uw_imap_prefix}/lib" "${uw_imap_prefix}/include/c-client" || return 1
  install -m 0644 c-client/c-client.a "${uw_imap_prefix}/lib/libc-client.a" || return 1
  install -m 0644 c-client/*.h "${uw_imap_prefix}/include/c-client/" || return 1
  popd > /dev/null
  rm -rf "${uw_imap_source_dir}"
}

Install_pecl_imap() {
  local imap_prefix

  if [ ! -e "${php_install_dir}/bin/phpize" ]; then
    echo "${CFAILURE}PHP phpize is required to install imap.${CEND}"
    return 1
  fi

    pushd ${oneinstack_dir}/src > /dev/null || return 1
    if [ "${PM}" == 'yum' ]; then
      if [ "${RHEL_ver}" == '9' ]; then
        # The official release package installs the signed repository configuration and GPG key.
        # 官方 release 包负责安装带签名校验的仓库配置和 GPG 密钥。
        dnf -y install https://rpms.remirepo.net/enterprise/remi-release-9.rpm &&
          dnf -y --enablerepo=remi install uw-imap-devel || return 1
      else
        yum -y install libc-client-devel || return 1
        [ ! -e /usr/lib/libc-client.so ] && ln -s /usr/lib64/libc-client.so /usr/lib/libc-client.so
      fi
      imap_prefix=/usr
    elif [ "${Family}" == 'debian' ] && [ "${Debian_ver:-0}" -ge 13 ]; then
      Install_UW_IMAP_From_Debian_Source || return 1
      imap_prefix=/usr/local/uw-imap
    else
      apt-get --no-install-recommends -y install libc-client2007e-dev || return 1
      imap_prefix=/usr
    fi
    phpExtensionDir=$(${php_install_dir}/bin/php-config --extension-dir)
    PHP_detail_ver=$(${php_install_dir}/bin/php-config --version)
    PHP_main_ver=${PHP_detail_ver%.*}
    if [[ "${PHP_main_ver}" =~ ^8\.[4-5]$ ]]; then
      # IMAP was unbundled from PHP 8.4 and is maintained as a PECL extension.
      # IMAP 从 PHP 8.4 起移出主源码，改用 PECL 扩展。
      src_url=https://pecl.php.net/get/imap-${pecl_imap_ver}.tgz
      src_checksum=${pecl_imap_checksum:-}
      Download_src no_kill || return 1
      tar xzf imap-${pecl_imap_ver}.tgz || return 1
      pushd imap-${pecl_imap_ver} > /dev/null || return 1
    else
      src_url=https://www.php.net/distributions/php-${PHP_detail_ver}.tar.gz
      [ "${PHP_detail_ver}" = "${php85_ver}" ] && src_checksum=${php85_checksum:-}
      Download_src no_kill || return 1
      tar xzf php-${PHP_detail_ver}.tar.gz || return 1
      pushd php-${PHP_detail_ver}/ext/imap > /dev/null || return 1
    fi
    ${php_install_dir}/bin/phpize || return 1
    ./configure --with-php-config=${php_install_dir}/bin/php-config \
      --with-kerberos --with-imap="${imap_prefix}" --with-imap-ssl || return 1
    make -j ${THREAD} && make install || return 1
    popd > /dev/null
    if [ -f "${phpExtensionDir}/imap.so" ]; then
      echo 'extension=imap.so' > ${php_install_dir}/etc/php.d/04-imap.ini
      echo "${CSUCCESS}PHP imap module installed successfully! ${CEND}"
      rm -rf php-${PHP_detail_ver} imap-${pecl_imap_ver}
    else
      echo "${CFAILURE}PHP imap module install failed, Please contact the author! ${CEND}"
      grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
      return 1
    fi
    popd > /dev/null
}

Uninstall_pecl_imap() {
  if [ -e "${php_install_dir}/etc/php.d/04-imap.ini" ]; then
    rm -f ${php_install_dir}/etc/php.d/04-imap.ini
    echo; echo "${CMSG}PHP imap module uninstall completed${CEND}"
  else
    echo; echo "${CWARNING}PHP imap module does not exist! ${CEND}"
  fi
}
