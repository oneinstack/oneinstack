#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Upgrade_PHP() {
  pushd ${oneinstack_dir}/src > /dev/null
  [ ! -e "${php_install_dir}" ] && echo "${CWARNING}PHP is not installed on your system! ${CEND}" && exit 1
  OLD_php_ver=`${php_install_dir}/bin/php-config --version`
  php_branch_ver=$(echo ${OLD_php_ver%.*} | tr -d '.')
  eval default_php_ver="\${php${php_branch_ver}_ver}"
  pythonCtl=python
  command -v python3 > /dev/null 2>&1 && pythonCtl=python3
  Latest_php_ver=`curl --connect-timeout 2 -m 3 -s "https://www.php.net/releases/index.php?json&version=${OLD_php_ver%.*}" | ${pythonCtl} -mjson.tool 2>/dev/null | awk '/"version"/{print $2}' | head -n 1 | sed 's/[",]//g'`
  Latest_php_ver=${Latest_php_ver:-${default_php_ver:-5.5.38}}
  echo
  echo "Current PHP Version: ${CMSG}$OLD_php_ver${CEND}"
  while :; do echo
    [ "${php_flag}" != 'y' ] && read -e -p "Please input upgrade PHP Version(Default: $Latest_php_ver): " NEW_php_ver
    NEW_php_ver=${NEW_php_ver:-${Latest_php_ver}}
    if [ "${NEW_php_ver%.*}" == "${OLD_php_ver%.*}" ]; then
      [ ! -e "php-${NEW_php_ver}.tar.gz" ] && src_url=https://www.php.net/distributions/php-${NEW_php_ver}.tar.gz && Download_src
      if [ -e "php-${NEW_php_ver}.tar.gz" ]; then
        echo "Download [${CMSG}php-${NEW_php_ver}.tar.gz${CEND}] successfully! "
      else
        echo "${CWARNING}PHP version does not exist! ${CEND}"
      fi
      break
    else
      echo "${CWARNING}input error! ${CEND}Please only input '${CMSG}${OLD_php_ver%.*}.xx${CEND}'"
      [ "${php_flag}" == 'y' ] && exit
    fi
  done

  if [ -e "php-${NEW_php_ver}.tar.gz" ]; then
    echo "[${CMSG}php-${NEW_php_ver}.tar.gz${CEND}] found"
    if [ "${php_flag}" != 'y' ]; then
      echo "Press Ctrl+c to cancel or Press any key to continue..."
      char=`get_char`
    fi
    tar xzf php-${NEW_php_ver}.tar.gz
    if [[ "${NEW_php_ver}" =~ ^5\.[3-5]\. ]]; then
      src_url=${mirror_link}/oneinstack/src/fpm-race-condition.patch && Download_src
      patch -d php-${NEW_php_ver} -p0 < fpm-race-condition.patch
    elif [[ "${NEW_php_ver}" =~ ^7\.4\. ]]; then
      src_url=${mirror_link}/oneinstack/src/php-7.4-CVE-2026-109618-109619.patch && Download_src
      patch -d php-${NEW_php_ver} -p1 < php-7.4-CVE-2026-109618-109619.patch
    elif [[ "${NEW_php_ver}" =~ ^8\.0\. ]]; then
      src_url=${mirror_link}/oneinstack/src/php-8.0-CVE-2026-109618-109619.patch && Download_src
      patch -d php-${NEW_php_ver} -p1 < php-8.0-CVE-2026-109618-109619.patch
    elif [[ "${NEW_php_ver}" =~ ^8\.1\. ]]; then
      src_url=${mirror_link}/oneinstack/src/php-8.1-CVE-2026-109618-109619.patch && Download_src
      patch -d php-${NEW_php_ver} -p1 < php-8.1-CVE-2026-109618-109619.patch
    fi
    pushd php-${NEW_php_ver}
    if [[ "${OLD_php_ver%.*}" =~ ^7.[1-4]$|^8.[0-1]$ ]] && [ -e ext/openssl/openssl.c ] && ! grep -Eqi '^#ifdef RSA_SSLV23_PADDING' ext/openssl/openssl.c; then
      sed -i '/OPENSSL_SSLV23_PADDING/i#ifdef RSA_SSLV23_PADDING' ext/openssl/openssl.c
      sed -i '/OPENSSL_SSLV23_PADDING/a#endif' ext/openssl/openssl.c
    fi
    [ -e ext/libxml/libxml.c ] && sed -i 's/ATTRIBUTE_UNUSED/__attribute__((unused))/g' ext/libxml/libxml.c
    if [ -e ext/openssl/php_openssl.h ] && ! grep -q '^#ifndef ERR_NUM_ERRORS' ext/openssl/php_openssl.h; then
      sed -i '/struct php_openssl_errors {/i #ifndef ERR_NUM_ERRORS\n#define ERR_NUM_ERRORS 16\n#endif' ext/openssl/php_openssl.h
    fi
    for f in ext/openssl/xp_ssl.c ext/openssl/openssl.c; do
      if [ -e "${f}" ] && ! grep -q 'ASN1_STRING_get0_data(const ASN1_STRING' ${f} && ! grep -q 'define ASN1_STRING_get0_data' ${f}; then
        sed -i '1i #include <openssl/opensslv.h>\n#if OPENSSL_VERSION_NUMBER < 0x10100000L && !defined(LIBRESSL_VERSION_NUMBER)\n#define ASN1_STRING_get0_data ASN1_STRING_data\n#endif' ${f}
      fi
    done
    if [ -e ext/openssl/xp_ssl.c ]; then
      sed -i 's/san->d.iPAddress->length/ASN1_STRING_length(san->d.iPAddress)/g' ext/openssl/xp_ssl.c
      sed -i 's/san->d.iPAddress->data/ASN1_STRING_get0_data(san->d.iPAddress)/g' ext/openssl/xp_ssl.c
    fi
    if [ -e ext/openssl/openssl.c ]; then
      sed -i 's/(char \*)str->data, str->length/(char *)ASN1_STRING_get0_data(str), ASN1_STRING_length(str)/g' ext/openssl/openssl.c
      sed -i 's/timestr->data/ASN1_STRING_get0_data(timestr)/g' ext/openssl/openssl.c
      sed -i 's/extension_data->data/ASN1_STRING_get0_data(extension_data)/g' ext/openssl/openssl.c
      sed -i 's/extension_data->length/ASN1_STRING_length(extension_data)/g' ext/openssl/openssl.c
    fi
    [ -e ext/dom/lexbor/lexbor/selectors-adapted/selectors.c ] && sed -i 's@#include <libxml/dict.h>@#include <libxml/tree.h>\n#include <libxml/dict.h>@' ext/dom/lexbor/lexbor/selectors-adapted/selectors.c
    [ -e ext/hash/php_hash_sha.h ] && sed -i 's@^#  define PHP_HASH_INTRIN_SHA_RESOLVER 1@#if !defined(__GNUC__) || __GNUC__ >= 5 || (__GNUC__ == 4 \&\& __GNUC_MINOR__ >= 9)\n#  define PHP_HASH_INTRIN_SHA_RESOLVER 1\n#endif@' ext/hash/php_hash_sha.h
    [ -e Zend/zend_portability.h ] && sed -i 's@typedef std::max_align_t zend_max_align_t;@typedef max_align_t zend_max_align_t;@' Zend/zend_portability.h
    [ -e ext/pdo_sqlite/pdo_sqlite.c ] && sed -i 's@sqlite3_db_config(sqlite_handle, SQLITE_DBCONFIG_ENABLE_LOAD_EXTENSION, \([01]\), NULL)@sqlite3_enable_load_extension(sqlite_handle, \1)@g' ext/pdo_sqlite/pdo_sqlite.c
    [ -f configure ] && sed -i 's@libxml-2.0 >= 2.9.4@libxml-2.0 >= 2.9.0@g; s@zlib >= 1.2.11@zlib >= 1.2.7@g' configure
    make clean
    export PKG_CONFIG_PATH=${openssl_install_dir}/lib/pkgconfig:${curl_install_dir}/lib/pkgconfig:${freetype_install_dir}/lib/pkgconfig:/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH
    ${php_install_dir}/bin/php -i |grep 'Configure Command' | awk -F'=>' '{print $2}' | bash
    [ -f Makefile ] && sed -i 's@-Wl,-z,max-page-size=[0-9]\+@@g; s@-Wl,-zmax-page-size=[0-9]\+@@g; s@-Wl,-zcommon-page-size=[0-9]\+@@g; s@-z,max-page-size=[0-9]\+@@g' Makefile
    make EXTRA_CFLAGS="${compat_cflags}" ZEND_EXTRA_LIBS='-liconv' -j ${THREAD}
    if [ -e "${apache_install_dir}/bin/httpd" ]; then
      echo "Stoping apache..."
      systemctl stop httpd 2>/dev/null || service httpd stop
      make install
      echo "Starting apache..."
      systemctl start httpd 2>/dev/null || service httpd start
    else
      echo "Stoping php-fpm..."
      systemctl stop php-fpm 2>/dev/null || service php-fpm stop
      make install
      echo "Starting php-fpm..."
      systemctl start php-fpm 2>/dev/null || service php-fpm start
    fi
    popd > /dev/null
    echo "You have ${CMSG}successfully${CEND} upgrade from ${CWARNING}$OLD_php_ver${CEND} to ${CWARNING}${NEW_php_ver}${CEND}"
    rm -rf php-${NEW_php_ver}
  fi
  popd > /dev/null
}
