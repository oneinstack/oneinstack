#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://blog.linuxeye.com
#
# Version: 1.0-Alpha Jun 15,2015 lj2007331 AT gmail.com
# Notes: OneinStack for CentOS/RadHat 5+ Debian 6+ and Ubuntu 12+
#
# Project home page:
#       http://oneinstack.com

Install-JDK-1-7(){
cd $oneinstack_dir/src
. ../functions/download.sh
. ../functions/check_os.sh
. ../options.conf

if [ `getconf WORD_BIT` == 32 ] && [ `getconf LONG_BIT` == 64 ];then
	SYS_BIG_FLAG=x64
else
	SYS_BIG_FLAG=i586
fi

JDK_VERSION="jdk-`echo $jdk_7_version | awk -F. '{print $2}'`u`echo $jdk_7_version | awk -F. '{print $3}'`"
JAVA_dir=/usr/java
JDK_NAME="jdk1.`echo $jdk_7_version | awk -F. '{print $2}'`.0_`echo $jdk_7_version | awk -F. '{print $3}'`"
JDK_PATH=$JAVA_dir/$JDK_NAME
src_url=http://mirrors.linuxeye.com/jdk/${JDK_VERSION}-linux-$SYS_BIG_FLAG.tar.gz && Download_src

OS_CentOS='[ -n "`rpm -qa | grep jdk`" ] && rpm -e `rpm -qa | grep jdk`'
OS_command

tar xzf ${JDK_VERSION}-linux-$SYS_BIG_FLAG.tar.gz

if [ -d "$JDK_NAME" ];then
	rm -rf $JAVA_dir; mkdir -p $JAVA_dir
	mv $JDK_NAME $JAVA_dir 
        [ -z "`grep ^'export JAVA_HOME=' /etc/profile`" ] && { [ -z "`grep ^'export PATH=' /etc/profile`" ] && echo  "export JAVA_HOME=$JDK_PATH" >> /etc/profile || sed -i "s@^export PATH=@export JAVA_HOME=$JDK_PATH\nexport PATH=@" /etc/profile; } || sed -i "s@^export JAVA_HOME=.*@export JAVA_HOME=$JDK_PATH@" /etc/profile
        [ -z "`grep ^'export CLASSPATH=' /etc/profile`" ] && sed -i "s@export JAVA_HOME=\(.*\)@export JAVA_HOME=\1\nexport CLASSPATH=\$JAVA_HOME/lib/tools.jar:\$JAVA_HOME/lib/dt.jar:\$JAVA_HOME/lib@" /etc/profile
	[ -n "`grep ^'export PATH=' /etc/profile`" -a -z "`grep '$JAVA_HOME/bin' /etc/profile`" ] && sed -i "s@^export PATH=\(.*\)@export PATH=\$JAVA_HOME/bin:\1@" /etc/profile
	[ -z "`grep ^'export PATH=' /etc/profile | grep '$JAVA_HOME/bin'`" ] && echo 'export PATH=$JAVA_HOME/bin:$PATH' >> /etc/profile
        . /etc/profile
        echo -e "\033[32m$JDK_VERSION install successfully! \033[0m"
fi
}
