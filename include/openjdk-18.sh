#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Install_OpenJDK18() {
  pushd ${oneinstack_dir}/src > /dev/null

  # 下载OpenJDK 18
  if [ "${OS}" == "CentOS" ] || [ "${OS}" == "RHEL" ]; then
    # CentOS/RHEL
    if [ "${OS_VER}" == "7" ]; then
      yum -y install java-18-openjdk java-18-openjdk-devel
    elif [ "${OS_VER}" == "8" ]; then
      dnf -y install java-18-openjdk java-18-openjdk-devel
    fi
  elif [ "${OS}" == "Debian" ] || [ "${OS}" == "Ubuntu" ]; then
    # Debian/Ubuntu
    apt-get update
    apt-get -y install openjdk-18-jdk
  fi

  # 设置JAVA_HOME
  if [ -d "/usr/lib/jvm/java-18-openjdk" ]; then
    JAVA_HOME="/usr/lib/jvm/java-18-openjdk"
  elif [ -d "/usr/lib/jvm/java-18-openjdk-amd64" ]; then
    JAVA_HOME="/usr/lib/jvm/java-18-openjdk-amd64"
  fi

  # 配置环境变量
  if [ -n "${JAVA_HOME}" ]; then
    [ -z "`grep ^'export JAVA_HOME=' /etc/profile`" ] && echo "export JAVA_HOME=${JAVA_HOME}" >> /etc/profile
    [ -z "`grep ^'export CLASSPATH=' /etc/profile`" ] && echo "export CLASSPATH=.:\${JAVA_HOME}/lib/dt.jar:\${JAVA_HOME}/lib/tools.jar" >> /etc/profile
    [ -z "`grep ^'export PATH=' /etc/profile`" ] && echo "export PATH=\${JAVA_HOME}/bin:\$PATH" >> /etc/profile
    [ -n "`grep ^'export PATH=' /etc/profile`" -a -z "`grep \${JAVA_HOME} /etc/profile`" ] && sed -i "s@^export PATH=\(.*\)@export PATH=\${JAVA_HOME}/bin:\1@" /etc/profile
    . /etc/profile

    # 验证安装
    java -version
    if [ $? -eq 0 ]; then
      echo "${CSUCCESS}OpenJDK 18 installed successfully! ${CEND}"
    else
      echo "${CFAILURE}OpenJDK 18 install failed, Please Contact the author! ${CEND}"
      kill -9 $$; exit 1;
    fi
  else
    echo "${CFAILURE}OpenJDK 18 install failed, Please Contact the author! ${CEND}"
    kill -9 $$; exit 1;
  fi

  popd > /dev/null
} 