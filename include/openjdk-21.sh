#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Install_OpenJDK21() {
  if [ "${Family}" == 'rhel' ]; then
    if [[ "${RHEL_ver}" =~ ^[7-8]$ ]]; then
      cat > /etc/yum.repos.d/adoptium.repo << EOF
[Adoptium]
name=Adoptium
baseurl=https://mirrors.tuna.tsinghua.edu.cn/Adoptium/rpm/rhel\$releasever-\$basearch/
enabled=1
gpgcheck=0
EOF
      yum -y install temurin-21-jdk
      JAVA_HOME=/usr/lib/jvm/temurin-21-jdk
    else
      yum -y install java-21-openjdk-devel
      JAVA_HOME=/usr/lib/jvm/java-21-openjdk
    fi
  elif [ "${Family}" == 'debian' ]; then
    if [[ "${Debian_ver}" =~ ^9$|^10$|^11$ ]]; then
      cat ${oneinstack_dir}/src/adoptium.key | sudo apt-key add -
      apt-add-repository --yes https://mirrors.tuna.tsinghua.edu.cn/Adoptium/deb
      apt -y update
      apt-get --no-install-recommends -y install temurin-21-jdk
      JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-${SYS_ARCH}
    else
      apt-get --no-install-recommends -y install openjdk-21-jdk
      JAVA_HOME=/usr/lib/jvm/java-21-openjdk-${SYS_ARCH}
    fi
  elif [ "${Family}" == 'ubuntu' ]; then
    if [[ "${Ubuntu_ver}" =~ ^16$|^18$|^20$ ]]; then
      cat ${oneinstack_dir}/src/adoptium.key | sudo apt-key add -
      apt-add-repository --yes https://mirrors.tuna.tsinghua.edu.cn/Adoptium/deb
      apt -y update
      apt-get --no-install-recommends -y install temurin-21-jdk
      JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-${SYS_ARCH}
    else
      apt-get --no-install-recommends -y install openjdk-21-jdk
      JAVA_HOME=/usr/lib/jvm/java-21-openjdk-${SYS_ARCH}
    fi
  fi
  if [ -e "${JAVA_HOME}/bin/java" ]; then
    cat > /etc/profile.d/openjdk.sh << EOF
export JAVA_HOME=${JAVA_HOME}
export CLASSPATH=\$JAVA_HOME/lib/tools.jar:\$JAVA_HOME/lib/dt.jar:\$JAVA_HOME/lib
EOF
    . /etc/profile.d/openjdk.sh
    echo "${CSUCCESS}OpenJDK21 installed successfully! ${CEND}"
  else
    echo "${CFAILURE}OpenJDK21 install failed, Please contact the author! ${CEND}" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
    kill -9 $$; exit 1;
  fi
}
