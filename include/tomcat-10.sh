#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Install_Tomcat10() {
  pushd ${oneinstack_dir}/src > /dev/null
  . /etc/profile
  id -g ${run_group} >/dev/null 2>&1
  [ $? -ne 0 ] && groupadd ${run_group}
  id -u ${run_user} >/dev/null 2>&1
  [ $? -ne 0 ] && useradd -g ${run_group} -M -s /bin/bash ${run_user} || { [ -z "$(grep ^${run_user} /etc/passwd | grep '/bin/bash')" ] && usermod -g ${run_group} -s /bin/bash ${run_user}; }

  # install apr
  if [ ! -e "${apr_install_dir}/bin/apr-1-config" ]; then
    tar xzf apr-${apr_ver}.tar.gz
    pushd apr-${apr_ver} > /dev/null
    ./configure --prefix=${apr_install_dir}
    make -j ${THREAD} && make install
    popd > /dev/null
    rm -rf apr-${apr_ver}
  fi

  tar xzf apache-tomcat-${tomcat10_ver}.tar.gz
  [ ! -d "${tomcat_install_dir}" ] && mkdir -p ${tomcat_install_dir}
  /bin/cp -R apache-tomcat-${tomcat10_ver}/* ${tomcat_install_dir}
  rm -rf ${tomcat_install_dir}/webapps/{docs,examples,host-manager,manager,ROOT/*}

  if [ ! -e "${tomcat_install_dir}/conf/server.xml" ]; then
    rm -rf ${tomcat_install_dir}
    echo "${CFAILURE}Tomcat install failed, Please contact the author! ${CEND}" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
    kill -9 $$; exit 1;
  fi

  pushd ${tomcat_install_dir}/bin > /dev/null
  tar xzf tomcat-native.tar.gz
  pushd tomcat-native-*-src/native > /dev/null
  if [ "${armplatform}" == "y" ]; then
    ./configure --prefix=${apr_install_dir} --with-apr=${apr_install_dir}
  else
    ./configure --prefix=${apr_install_dir} --with-apr=${apr_install_dir} --with-ssl=${openssl_install_dir}
  fi
  make -j ${THREAD} && make install
  popd > /dev/null
  rm -rf tomcat-native-*
  if [ -e "${apr_install_dir}/lib/libtcnative-1.la" ]; then
    [ ${Mem} -le 768 ] && let Xms_Mem="${Mem}/3" || Xms_Mem=256
    let XmxMem="${Mem}/2"
    cat > ${tomcat_install_dir}/bin/setenv.sh << EOF
JAVA_OPTS='-Djava.security.egd=file:/dev/./urandom -server -Xms${Xms_Mem}m -Xmx${XmxMem}m -Dfile.encoding=UTF-8'
CATALINA_OPTS="-Djava.library.path=${apr_install_dir}/lib"
# -Djava.rmi.server.hostname=$IPADDR
# -Dcom.sun.management.jmxremote.password.file=\$CATALINA_BASE/conf/jmxremote.password
# -Dcom.sun.management.jmxremote.access.file=\$CATALINA_BASE/conf/jmxremote.access
# -Dcom.sun.management.jmxremote.ssl=false"
EOF
    chmod +x ./*.sh
    /bin/mv ${tomcat_install_dir}/conf/server.xml{,_bk}
    popd # goto ${oneinstack_dir}/src
    /bin/cp ${oneinstack_dir}/config/server.xml ${tomcat_install_dir}/conf
    sed -i "s@/usr/local/tomcat@${tomcat_install_dir}@g" ${tomcat_install_dir}/conf/server.xml

    if [ ! -e "${nginx_install_dir}/sbin/nginx" -a ! -e "${tengine_install_dir}/sbin/nginx" -a ! -e "${openresty_install_dir}/nginx/sbin/nginx" -a ! -e "${apache_install_dir}/bin/httpd" ]; then
      if [ "${PM}" == 'yum' ]; then
        if [ "`firewall-cmd --state`" == "running" ]; then
          firewall-cmd --permanent --zone=public --add-port=8080/tcp
          firewall-cmd --reload
	fi
      elif [ "${PM}" == 'apt-get' ]; then
        if ufw status | grep -wq active; then
            ufw allow 8080/tcp
        fi
      fi
    fi

    [ ! -d "${tomcat_install_dir}/conf/vhost" ] && mkdir ${tomcat_install_dir}/conf/vhost
    cat > ${tomcat_install_dir}/conf/vhost/localhost.xml << EOF
<Host name="localhost" appBase="${wwwroot_dir}/default" unpackWARs="true" autoDeploy="true">
  <Context path="" docBase="${wwwroot_dir}/default" reloadable="false" crossContext="true"/>
  <Valve className="org.apache.catalina.valves.AccessLogValve" directory="logs"
    prefix="localhost_access_log" suffix=".txt" pattern="%h %l %u %t &quot;%r&quot; %s %b" />
  <Valve className="org.apache.catalina.valves.RemoteIpValve" remoteIpHeader="X-Forwarded-For"
    protocolHeader="X-Forwarded-Proto" protocolHeaderHttpsValue="https"/>
</Host>
EOF
    # logrotate tomcat catalina.out
    cat > /etc/logrotate.d/tomcat << EOF
${tomcat_install_dir}/logs/catalina.out {
  daily
  rotate 5
  missingok
  dateext
  compress
  notifempty
  copytruncate
}
EOF
    [ -z "$(grep '<user username="admin" password=' ${tomcat_install_dir}/conf/tomcat-users.xml)" ] && sed -i "s@^</tomcat-users>@<role rolename=\"admin-gui\"/>\n<role rolename=\"admin-script\"/>\n<role rolename=\"manager-gui\"/>\n<role rolename=\"manager-script\"/>\n<user username=\"admin\" password=\"$(cat /dev/urandom | head -1 | md5sum | head -c 10)\" roles=\"admin-gui,admin-script,manager-gui,manager-script\"/>\n</tomcat-users>@" ${tomcat_install_dir}/conf/tomcat-users.xml
    cat > ${tomcat_install_dir}/conf/jmxremote.access << EOF
monitorRole   readonly
controlRole   readwrite \
              create javax.management.monitor.*,javax.management.timer.* \
              unregister
EOF
    cat > ${tomcat_install_dir}/conf/jmxremote.password << EOF
monitorRole  $(cat /dev/urandom | head -1 | md5sum | head -c 8)
# controlRole   R&D
EOF
    chown -R ${run_user}:${run_group} ${tomcat_install_dir}
    /bin/cp ${oneinstack_dir}/init.d/Tomcat-init /etc/init.d/tomcat
    sed -i "s@JAVA_HOME=.*@JAVA_HOME=${JAVA_HOME}@" /etc/init.d/tomcat
    sed -i "s@^CATALINA_HOME=.*@CATALINA_HOME=${tomcat_install_dir}@" /etc/init.d/tomcat
    sed -i "s@^TOMCAT_USER=.*@TOMCAT_USER=${run_user}@" /etc/init.d/tomcat
    [ "${PM}" == 'yum' ] && { chkconfig --add tomcat; chkconfig tomcat on; }
    [ "${PM}" == 'apt-get' ] && update-rc.d tomcat defaults
    echo "${CSUCCESS}Tomcat installed successfully! ${CEND}"
    rm -rf apache-tomcat-${tomcat10_ver}
  else
    popd > /dev/null
    echo "${CFAILURE}Tomcat install failed, Please contact the author! ${CEND}" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
  fi
  service tomcat start
  popd > /dev/null
}

1. 在安装前添加JDK版本检查：
   if [ "$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d. -f1)" -lt 11 ]; then
     echo "Tomcat 10.1 requires JDK 11 or higher"
     exit 1
   fi

2. 在启动服务前添加JAVA_HOME验证：
   if [ -z "${JAVA_HOME}" ]; then
     echo "JAVA_HOME environment variable is not set"
     exit 1
   fi
