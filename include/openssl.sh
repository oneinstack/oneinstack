#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

if openssl version | grep -Eqi 'OpenSSL 1.0.2*'; then
  php5_with_openssl="--with-openssl"
  php70_with_openssl="--with-openssl"
  php71_with_openssl="--with-openssl"
  php72_with_openssl="--with-openssl"
  php73_with_openssl="--with-openssl"
  php74_with_openssl="--with-openssl"
  php80_with_openssl="--with-openssl"
  php81_with_openssl="--with-openssl"
  php82_with_openssl="--with-openssl"
  php83_with_openssl="--with-openssl"
  php84_with_openssl="--with-openssl"
  php85_with_openssl="--with-openssl"

  php5_with_ssl="--with-ssl"
  php70_with_ssl="--with-ssl"
  php71_with_ssl="--with-ssl"
  php72_with_ssl="--with-ssl"
  php73_with_ssl="--with-ssl"
  php74_with_ssl="--with-ssl"
  php80_with_ssl="--with-ssl"
  php81_with_ssl="--with-ssl"
  php82_with_ssl="--with-ssl"
  php83_with_ssl="--with-ssl"
  php84_with_ssl="--with-ssl=${openssl_install_dir}"
  php85_with_ssl="--with-ssl=${openssl_install_dir}"

  php5_with_curl="--with-curl"
  php70_with_curl="--with-curl"
  php71_with_curl="--with-curl"
  php72_with_curl="--with-curl"
  php73_with_curl="--with-curl"
  php74_with_curl="--with-curl"
  php80_with_curl="--with-curl"
  php81_with_curl="--with-curl"
  php82_with_curl="--with-curl"
  php83_with_curl="--with-curl"
  php84_with_curl="--with-curl"
  php85_with_curl="--with-curl"
  [[ ${php_option} =~ ^1[4-5]$ ]] || [[ "${mphp_ver}" =~ ^8[4-5]$ ]] && with_openssl11_flag=y
  curl_ver=${curl_oldver}
elif openssl version | grep -Eqi 'OpenSSL 1.1.*'; then
  php5_with_openssl="--with-openssl=${openssl_install_dir}"
  php70_with_openssl="--with-openssl"
  php71_with_openssl="--with-openssl"
  php72_with_openssl="--with-openssl"
  php73_with_openssl="--with-openssl"
  php74_with_openssl="--with-openssl"
  php80_with_openssl="--with-openssl"
  php81_with_openssl="--with-openssl"
  php82_with_openssl="--with-openssl"
  php83_with_openssl="--with-openssl"
  php84_with_openssl="--with-openssl"
  php85_with_openssl="--with-openssl"

  php5_with_ssl="--with-ssl=${openssl_install_dir}"
  php70_with_ssl="--with-ssl"
  php71_with_ssl="--with-ssl"
  php72_with_ssl="--with-ssl"
  php73_with_ssl="--with-ssl"
  php74_with_ssl="--with-ssl"
  php80_with_ssl="--with-ssl"
  php81_with_ssl="--with-ssl"
  php82_with_ssl="--with-ssl"
  php83_with_ssl="--with-ssl"
  php84_with_ssl="--with-ssl"
  php85_with_ssl="--with-ssl"

  php5_with_curl="--with-curl=${curl_install_dir}"
  php70_with_curl="--with-curl"
  php71_with_curl="--with-curl"
  php72_with_curl="--with-curl"
  php73_with_curl="--with-curl"
  php74_with_curl="--with-curl"
  php80_with_curl="--with-curl"
  php81_with_curl="--with-curl"
  php82_with_curl="--with-curl"
  php83_with_curl="--with-curl"
  php84_with_curl="--with-curl"
  php85_with_curl="--with-curl"
  [[ ${php_option} =~ ^[1-4]$ ]] || [[ "${mphp_ver}" =~ ^5[3-6]$ ]] && with_old_openssl_flag=y
  curl_ver=${curl_oldver}
elif openssl version | grep -Eqi 'OpenSSL [3-9]\.'; then
  php5_with_openssl="--with-openssl=${openssl_install_dir}"
  php70_with_openssl="--with-openssl=${openssl_install_dir}"
  php71_with_openssl="--with-openssl"
  php72_with_openssl="--with-openssl"
  php73_with_openssl="--with-openssl"
  php74_with_openssl="--with-openssl"
  php80_with_openssl="--with-openssl"
  php81_with_openssl="--with-openssl"
  php82_with_openssl="--with-openssl"
  php83_with_openssl="--with-openssl"
  php84_with_openssl="--with-openssl"
  php85_with_openssl="--with-openssl"

  php5_with_ssl="--with-ssl=${openssl_install_dir}"
  php70_with_ssl="--with-ssl=${openssl_install_dir}"
  php71_with_ssl="--with-ssl"
  php72_with_ssl="--with-ssl"
  php73_with_ssl="--with-ssl"
  php74_with_ssl="--with-ssl"
  php80_with_ssl="--with-ssl"
  php81_with_ssl="--with-ssl"
  php82_with_ssl="--with-ssl"
  php83_with_ssl="--with-ssl"
  php84_with_ssl="--with-ssl"
  php85_with_ssl="--with-ssl"

  php5_with_curl="--with-curl=${curl_install_dir}"
  php70_with_curl="--with-curl=${curl_install_dir}"
  php71_with_curl="--with-curl"
  php72_with_curl="--with-curl"
  php73_with_curl="--with-curl"
  php74_with_curl="--with-curl"
  php80_with_curl="--with-curl"
  php81_with_curl="--with-curl"
  php82_with_curl="--with-curl"
  php83_with_curl="--with-curl"
  php84_with_curl="--with-curl"
  php85_with_curl="--with-curl"
  if [[ ${php_option} =~ ^[1-5]$ ]] || [[ "${mphp_ver}" =~ ^5[3-6]$|^70$ ]]; then
    with_old_openssl_flag=y
    curl_ver=${curl_oldver}
  fi
else
  php5_with_openssl="--with-openssl=${openssl_install_dir}"
  php70_with_openssl="--with-openssl=${openssl_install_dir}"
  php71_with_openssl="--with-openssl=${openssl_install_dir}"
  php72_with_openssl="--with-openssl=${openssl_install_dir}"
  php73_with_openssl="--with-openssl=${openssl_install_dir}"
  php74_with_openssl="--with-openssl=${openssl_install_dir} --with-openssl-dir=${openssl_install_dir}"
  php80_with_openssl="--with-openssl=${openssl_install_dir} --with-openssl-dir=${openssl_install_dir}"
  php81_with_openssl="--with-openssl=${openssl_install_dir} --with-openssl-dir=${openssl_install_dir}"
  php82_with_openssl="--with-openssl=${openssl_install_dir} --with-openssl-dir=${openssl_install_dir}"
  php83_with_openssl="--with-openssl=${openssl_install_dir} --with-openssl-dir=${openssl_install_dir}"
  php84_with_openssl="--with-openssl=${openssl_install_dir} --with-openssl-dir=${openssl_install_dir}"
  php85_with_openssl="--with-openssl=${openssl_install_dir} --with-openssl-dir=${openssl_install_dir}"

  php5_with_ssl="--with-ssl=${openssl_install_dir}"
  php70_with_ssl="--with-ssl=${openssl_install_dir}"
  php71_with_ssl="--with-ssl=${openssl_install_dir}"
  php72_with_ssl="--with-ssl=${openssl_install_dir}"
  php73_with_ssl="--with-ssl=${openssl_install_dir}"
  php74_with_ssl="--with-ssl=${openssl_install_dir}"
  php80_with_ssl="--with-ssl=${openssl_install_dir}"
  php81_with_ssl="--with-ssl=${openssl_install_dir}"
  php82_with_ssl="--with-ssl=${openssl_install_dir}"
  php83_with_ssl="--with-ssl=${openssl_install_dir}"
  php84_with_ssl="--with-ssl=${openssl_install_dir}"
  php85_with_ssl="--with-ssl=${openssl_install_dir}"

  php5_with_curl="--with-curl=${curl_install_dir}"
  php70_with_curl="--with-curl=${curl_install_dir}"
  php71_with_curl="--with-curl=${curl_install_dir}"
  php72_with_curl="--with-curl=${curl_install_dir}"
  php73_with_curl="--with-curl=${curl_install_dir}"
  php74_with_curl="--with-curl=${curl_install_dir}"
  php80_with_curl="--with-curl=${curl_install_dir}"
  php81_with_curl="--with-curl=${curl_install_dir}"
  php82_with_curl="--with-curl=${curl_install_dir}"
  php83_with_curl="--with-curl=${curl_install_dir}"
  php84_with_curl="--with-curl=${curl_install_dir}"
  php85_with_curl="--with-curl=${curl_install_dir}"
  if [[ ${php_option} =~ ^[1-9]$|^1[0-5]$ ]] || [ -n "${mphp_ver}" ] || [ "${apache_flag}" == 'y' ]; then
    with_old_openssl_flag=y
    curl_ver=${curl_oldver}
  fi
fi

Install_openSSL() {
  if [ "${with_old_openssl_flag}" == 'y' ]; then
    if [ ! -e "${openssl_install_dir}/lib/libssl.a" ]; then
      pushd ${oneinstack_dir}/src > /dev/null
      tar xzf openssl-${openssl102_ver}.tar.gz
      pushd openssl-${openssl102_ver} > /dev/null
      make clean
      ./config -Wl,-rpath=${openssl_install_dir}/lib -fPIC --prefix=${openssl_install_dir} --openssldir=${openssl_install_dir}
      make depend
      make -j ${THREAD} && make install
      popd > /dev/null
      if [ -f "${openssl_install_dir}/lib/libcrypto.a" ]; then
        echo "${CSUCCESS}openSSL installed successfully! ${CEND}"
        /bin/cp cacert.pem ${openssl_install_dir}/cert.pem
        rm -rf openssl-${openssl102_ver}
      else
        echo "${CFAILURE}openSSL install failed, Please contact the author! ${CEND}" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
        kill -9 $$; exit 1;
      fi
      popd > /dev/null
    fi
  elif [ "${with_openssl11_flag}" == 'y' ]; then
    if [ ! -e "${openssl_install_dir}/lib/libssl.a" ]; then
      pushd ${oneinstack_dir}/src > /dev/null
      tar xzf openssl-${openssl11_ver}.tar.gz
      pushd openssl-${openssl11_ver} > /dev/null
      make clean
      ./config -Wl,-rpath=${openssl_install_dir}/lib -fPIC --prefix=${openssl_install_dir} --openssldir=${openssl_install_dir}
      make -j ${THREAD} && make install_sw install_ssldirs
      popd > /dev/null
      if [ -f "${openssl_install_dir}/lib/libcrypto.a" ]; then
        echo "${CSUCCESS}openSSL installed successfully! ${CEND}"
        /bin/cp cacert.pem ${openssl_install_dir}/cert.pem
        [ -z "`grep ${openssl_install_dir}/lib /etc/ld.so.conf.d/*.conf 2>/dev/null`" ] && echo "${openssl_install_dir}/lib" > /etc/ld.so.conf.d/openssl.conf
        ldconfig
        rm -rf openssl-${openssl11_ver}
      else
        echo "${CFAILURE}openSSL install failed, Please contact the author! ${CEND}" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
        kill -9 $$; exit 1;
      fi
      popd > /dev/null
    fi
  fi
}
