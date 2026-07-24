#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Install_ImageMagick() {
  if [ -x "${imagick_install_dir}/bin/magick" ]; then
    echo "${CWARNING}ImageMagick already installed! ${CEND}"
  else
    [ -d "${imagick_install_dir}" ] && rm -rf "${imagick_install_dir}"
    pushd ${oneinstack_dir}/src > /dev/null || return 1
    src_url=https://download.imagemagick.org/archive/releases/ImageMagick-${imagemagick_ver}.tar.gz
    src_checksum=${imagemagick_checksum:-}
    Download_src no_kill || return 1
    tar xzf ImageMagick-${imagemagick_ver}.tar.gz || return 1
    pushd ImageMagick-${imagemagick_ver} > /dev/null || return 1
    ./configure --prefix=${imagick_install_dir} --enable-shared --enable-static || return 1
    make -j ${THREAD} && make install || return 1
    popd > /dev/null
    rm -rf ImageMagick-${imagemagick_ver}
    popd > /dev/null
    if [ ! -x "${imagick_install_dir}/bin/magick" ]; then
      echo "${CFAILURE}ImageMagick installation did not produce a usable binary.${CEND}"
      return 1
    fi
  fi

  # Make the non-system ImageMagick libraries visible to PHP at runtime.
  # 让动态链接器能够找到非系统目录中的 ImageMagick 库，避免 imagick.so 编译成功却无法加载。
  if [ -d /etc/ld.so.conf.d ]; then
    {
      [ -d "${imagick_install_dir}/lib" ] && echo "${imagick_install_dir}/lib"
      [ -d "${imagick_install_dir}/lib64" ] && echo "${imagick_install_dir}/lib64"
    } > /etc/ld.so.conf.d/oneinstack-imagemagick.conf
    ldconfig || return 1
  fi
}

Uninstall_ImageMagick() {
  if [ -d "${imagick_install_dir}" ]; then
    rm -rf ${imagick_install_dir}
    echo; echo "${CMSG}ImageMagick uninstall completed${CEND}"
  fi
}

Install_pecl_imagick() {
  if [ ! -e "${php_install_dir}/bin/phpize" ]; then
    echo "${CFAILURE}PHP phpize is required to install imagick.${CEND}"
    return 1
  fi

    pushd ${oneinstack_dir}/src > /dev/null || return 1
    PHP_detail_ver=$(${php_install_dir}/bin/php-config --version)
    PHP_main_ver=${PHP_detail_ver%.*}
    phpExtensionDir=`${php_install_dir}/bin/php-config --extension-dir`
    if [[ "${PHP_main_ver}" =~ ^5.3$ ]]; then
      src_url=https://pecl.php.net/get/imagick-${imagick_oldver}.tgz
      Download_src no_kill || return 1
      tar xzf imagick-${imagick_oldver}.tgz || return 1
      pushd imagick-${imagick_oldver} > /dev/null || return 1
    else
      src_url=https://pecl.php.net/get/imagick-${imagick_ver}.tgz
      src_checksum=${imagick_checksum:-}
      Download_src no_kill || return 1
      tar xzf imagick-${imagick_ver}.tgz || return 1
      pushd imagick-${imagick_ver} > /dev/null || return 1
    fi
    export PKG_CONFIG_PATH="${imagick_install_dir}/lib/pkgconfig:/usr/local/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
    ${php_install_dir}/bin/phpize || return 1
    ./configure --with-php-config=${php_install_dir}/bin/php-config --with-imagick=${imagick_install_dir} || return 1
    make -j ${THREAD} && make install || return 1
    popd > /dev/null
    if [ -f "${phpExtensionDir}/imagick.so" ]; then
      echo 'extension=imagick.so' > ${php_install_dir}/etc/php.d/03-imagick.ini
      echo "${CSUCCESS}PHP imagick module installed successfully! ${CEND}"
      rm -rf imagick-${imagick_ver} imagick-${imagick_oldver}
    else
      echo "${CFAILURE}PHP imagick module install failed, Please contact the author! ${CEND}"
      grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
      return 1
    fi
    popd > /dev/null
}

Uninstall_pecl_imagick() {
  if [ -e "${php_install_dir}/etc/php.d/03-imagick.ini" ]; then
    rm -f ${php_install_dir}/etc/php.d/03-imagick.ini
    echo; echo "${CMSG}PHP imagick module uninstall completed${CEND}"
  else
    echo; echo "${CWARNING}PHP imagick module does not exist! ${CEND}"
  fi
}
