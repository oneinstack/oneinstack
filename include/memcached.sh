#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Install_memcached_server() {
  pushd ${oneinstack_dir}/src > /dev/null
  # memcached server
  id -u memcached >/dev/null 2>&1
  [ $? -ne 0 ] && useradd -M -s /sbin/nologin memcached

  tar xzf memcached-${memcached_ver}.tar.gz
  pushd memcached-${memcached_ver} > /dev/null
  [ ! -d "${memcached_install_dir}" ] && mkdir -p ${memcached_install_dir}
  ./configure --prefix=${memcached_install_dir}
  make -j ${THREAD} && make install
  popd > /dev/null
  if [ -f "${memcached_install_dir}/bin/memcached" ]; then
    echo "${CSUCCESS}memcached installed successfully! ${CEND}"
    rm -rf memcached-${memcached_ver}
    ln -s ${memcached_install_dir}/bin/memcached /usr/bin/memcached
    /bin/cp ../init.d/memcached.service /lib/systemd/system/
    systemctl enable memcached
    systemctl start memcached
    rm -rf memcached-${memcached_ver}
  else
    rm -rf ${memcached_install_dir}
    echo "${CFAILURE}memcached-server install failed, Please contact the author! ${CEND}" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
    kill -9 $$; exit 1;
  fi
  popd > /dev/null
}

Install_pecl_memcache() {
  if [ -e "${php_install_dir}/bin/phpize" ]; then
    pushd ${oneinstack_dir}/src > /dev/null
    phpExtensionDir=$(${php_install_dir}/bin/php-config --extension-dir)
    PHP_detail_ver=$(${php_install_dir}/bin/php-config --version)
    PHP_main_ver=${PHP_detail_ver%.*}
    if [ "$(${php_install_dir}/bin/php-config --version | awk -F. '{print $1}')" == '5' ]; then
      tar xzf memcache-3.0.8.tgz
      pushd memcache-3.0.8 > /dev/null
    elif [ "$(${php_install_dir}/bin/php-config --version | awk -F. '{print $1}')" == '7' ]; then
      tar xzf memcache-${pecl_memcache_oldver}.tgz
      pushd memcache-${pecl_memcache_oldver} > /dev/null
    else
      #git clone https://github.com/websupport-sk/pecl-memcache.git
      tar xzf memcache-${pecl_memcache_ver}.tgz
      pushd memcache-${pecl_memcache_ver} > /dev/null
    fi
    ${php_install_dir}/bin/phpize
    ./configure --with-php-config=${php_install_dir}/bin/php-config
    make -j ${THREAD} && make install
    popd > /dev/null
    if [ -f "${phpExtensionDir}/memcache.so" ]; then
      echo "extension=memcache.so" > ${php_install_dir}/etc/php.d/05-memcache.ini
      echo "${CSUCCESS}PHP memcache module installed successfully! ${CEND}"
      rm -rf memcache-${pecl_memcache_ver} memcache-${pecl_memcache_oldver} memcache-3.0.8
    else
      echo "${CFAILURE}PHP memcache module install failed, Please contact the author! ${CEND}" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
    fi
    popd > /dev/null
  fi
}

Install_pecl_memcached() {
  local libmemcached_dir
  local cmake_bin=cmake
  local cmake_version cmake_major cmake_minor

  if [ ! -e "${php_install_dir}/bin/phpize" ]; then
    echo "${CFAILURE}PHP phpize is required to install memcached.${CEND}"
    return 1
  fi

    pushd ${oneinstack_dir}/src > /dev/null || return 1
    phpExtensionDir=$(${php_install_dir}/bin/php-config --extension-dir)
    libmemcached_dir=/usr/local/libmemcached

    # php-memcached is distributed by PECL, but it still needs the native
    # libmemcached library. Build the tagged upstream replacement locally
    # instead of trusting an opaque binary or a third-party source mirror.
    # php-memcached 本体使用 PECL；其原生依赖则固定官方标签源码并在本地编译，
    # 不使用不透明二进制包或第三方源码镜像。
    if [ "${PM}" == 'apt-get' ]; then
      apt-get --no-install-recommends -y install \
        cmake g++ pkg-config flex bison libsasl2-dev libevent-dev || return 1
    else
      yum -y install cmake gcc-c++ pkgconfig flex bison \
        cyrus-sasl-devel libevent-devel || return 1
      command -v cmake3 >/dev/null 2>&1 && cmake_bin=cmake3
    fi
    command -v "${cmake_bin}" >/dev/null 2>&1 || {
      echo "${CFAILURE}CMake is required to build libmemcached.${CEND}"
      return 1
    }
    cmake_version=$("${cmake_bin}" --version | awk 'NR == 1 {print $3}')
    cmake_major=${cmake_version%%.*}
    cmake_minor=${cmake_version#*.}
    cmake_minor=${cmake_minor%%.*}
    if [ -z "${cmake_major}" ] || [ -z "${cmake_minor}" ] ||
      [ "${cmake_major}" -lt 3 ] ||
      { [ "${cmake_major}" -eq 3 ] && [ "${cmake_minor}" -lt 9 ]; }; then
      echo "${CFAILURE}libmemcached ${libmemcached_ver} requires CMake 3.9 or newer.${CEND}"
      return 1
    fi

    src_url=https://github.com/awesomized/libmemcached/archive/refs/tags/${libmemcached_ver}.tar.gz
    src_name=libmemcached-${libmemcached_ver}.tar.gz
    src_checksum=${libmemcached_checksum:-}
    Download_src no_kill || return 1
    rm -rf libmemcached-${libmemcached_ver}
    tar xzf libmemcached-${libmemcached_ver}.tar.gz || return 1
    mkdir -p "libmemcached-${libmemcached_ver}/build" || return 1
    pushd "libmemcached-${libmemcached_ver}/build" > /dev/null || return 1
    "${cmake_bin}" .. \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX="${libmemcached_dir}" \
      -DBUILD_SHARED_LIBS=ON \
      -DBUILD_TESTING=OFF \
      -DBUILD_DOCS=OFF \
      -DENABLE_SASL=ON || return 1
    make -j "${THREAD}" && make install || return 1
    popd > /dev/null
    rm -rf libmemcached-${libmemcached_ver}

    if [ -d /etc/ld.so.conf.d ]; then
      {
        [ -d "${libmemcached_dir}/lib" ] && echo "${libmemcached_dir}/lib"
        [ -d "${libmemcached_dir}/lib64" ] && echo "${libmemcached_dir}/lib64"
      } > /etc/ld.so.conf.d/oneinstack-libmemcached.conf
      ldconfig || return 1
    fi

    if [ "$(${php_install_dir}/bin/php-config --version | awk -F. '{print $1}')" == '5' ]; then
      src_url=https://pecl.php.net/get/memcached-${pecl_memcached_oldver}.tgz
      Download_src no_kill || return 1
      tar xzf memcached-${pecl_memcached_oldver}.tgz || return 1
      pushd memcached-${pecl_memcached_oldver} > /dev/null || return 1
    else
      src_url=https://pecl.php.net/get/memcached-${pecl_memcached_ver}.tgz
      src_checksum=${pecl_memcached_checksum:-}
      Download_src no_kill || return 1
      tar xzf memcached-${pecl_memcached_ver}.tgz || return 1
      pushd memcached-${pecl_memcached_ver} > /dev/null || return 1
    fi
    ${php_install_dir}/bin/phpize || return 1
    ./configure --with-php-config=${php_install_dir}/bin/php-config \
      --with-libmemcached-dir="${libmemcached_dir}" --enable-memcached-sasl || return 1
    make -j ${THREAD} && make install || return 1
    popd > /dev/null
    if [ -f "${phpExtensionDir}/memcached.so" ]; then
      cat > ${php_install_dir}/etc/php.d/05-memcached.ini << EOF
extension=memcached.so
memcached.use_sasl=1
EOF
      echo "${CSUCCESS}PHP memcached module installed successfully! ${CEND}"
      rm -rf memcached-${pecl_memcached_oldver} memcached-${pecl_memcached_ver}
    else
      echo "${CFAILURE}PHP memcached module install failed, Please contact the author! ${CEND}"
      grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
      return 1
    fi
    popd > /dev/null
}

Uninstall_pecl_memcache() {
  if [ -e "${php_install_dir}/etc/php.d/05-memcache.ini" ]; then
    rm -f ${php_install_dir}/etc/php.d/05-memcache.ini
    echo; echo "${CMSG}PHP memcache module uninstall completed${CEND}"
  else
    echo; echo "${CWARNING}PHP memcache module does not exist! ${CEND}"
  fi
}

Uninstall_pecl_memcached() {
  if [ -e "${php_install_dir}/etc/php.d/05-memcached.ini" ]; then
    rm -f ${php_install_dir}/etc/php.d/05-memcached.ini
    echo; echo "${CMSG}PHP memcached module uninstall completed${CEND}"
  else
    echo; echo "${CWARNING}PHP memcached module does not exist! ${CEND}"
  fi
}
