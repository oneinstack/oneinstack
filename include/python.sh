#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Install_Python() {
  if [ -e "${python_install_dir}/bin/python" ]; then
    echo "${CWARNING}Python already installed! ${CEND}"
  else
    pushd ${oneinstack_dir}/src > /dev/null

    if [ "${PM}" == 'yum' ]; then
      [ -z "`grep -w epel /etc/yum.repos.d/*.repo`" ] && yum -y install epel-release
      pkgList="gcc dialog augeas-libs openssl openssl-devel libffi-devel redhat-rpm-config ca-certificates"
      for Package in ${pkgList}; do
        yum -y install ${Package}
      done
    elif [ "${PM}" == 'apt-get' ]; then
      pkgList="gcc dialog libaugeas0 augeas-lenses libssl-dev libffi-dev ca-certificates"
      for Package in ${pkgList}; do
        apt-get -y install $Package
      done
    fi

    # Install Python3
    if [ ! -e "${python_install_dir}/bin/python" -a ! -e "${python_install_dir}/bin/python3" ] ;then
      src_url=http://mirrors.linuxeye.com/oneinstack/src/Python-${python_ver}.tgz && Download_src
      tar xzf Python-${python_ver}.tgz
      pushd Python-${python_ver} > /dev/null
      ./configure --prefix=${python_install_dir}
      make && make install
      [ ! -e "${python_install_dir}/bin/python" -a -e "${python_install_dir}/bin/python3" ] && ln -s ${python_install_dir}/bin/python{3,}
      [ ! -e "${python_install_dir}/bin/pip" -a -e "${python_install_dir}/bin/pip3" ] && ln -s ${python_install_dir}/bin/pip{3,}
      popd > /dev/null
    fi

    if [ ! -e "${python_install_dir}/bin/pip" ]; then
      src_url=http://mirrors.linuxeye.com/oneinstack/src/setuptools-${setuptools_ver}.tar.gz && Download_src
      src_url=http://mirrors.linuxeye.com/oneinstack/src/pip-${pip_ver}.tar.gz && Download_src
      tar xzf setuptools-${setuptools_ver}.tar.gz
      tar xzf pip-${pip_ver}.tar.gz
      pushd setuptools-${setuptools_ver} > /dev/null
      ${python_install_dir}/bin/python setup.py install
      popd > /dev/null
      pushd pip-${pip_ver} > /dev/null
      ${python_install_dir}/bin/python setup.py install
      popd > /dev/null
    fi

    if [ ! -e "/root/.pip/pip.conf" ] ;then
      if [ "${OUTIP_STATE}"x == "China"x ]; then
        [ ! -d "/root/.pip" ] && mkdir /root/.pip
        echo -e "[global]\nindex-url = https://pypi.tuna.tsinghua.edu.cn/simple" > /root/.pip/pip.conf
      fi
    fi

    if [ -e "${python_install_dir}/bin/python3" ]; then
      echo "${CSUCCESS}Python ${python_ver} installed successfully! ${CEND}"
      rm -rf Python-${python_ver}
    fi
    popd > /dev/null
  fi
}

Uninstall_Python() {
  if [ -e "${python_install_dir}/bin/python" ]; then
    echo "${CMSG}Python uninstall completed${CEND}"
    rm -rf ${python_install_dir}
  fi
}
