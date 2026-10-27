#!/bin/bash
# Author:  OneinStack
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Install_valkey_server() {
  pushd ${oneinstack_dir}/src > /dev/null
  tar xzf valkey-${valkey_ver}.tar.gz
  pushd valkey-${valkey_ver} > /dev/null
  make -C src OPTIMIZATION="-O3 -fno-omit-frame-pointer" -j ${THREAD}
  if [ -f "src/valkey-server" ]; then
    mkdir -p ${valkey_install_dir}/{bin,etc,var}
    /bin/cp src/{valkey-benchmark,valkey-check-aof,valkey-check-rdb,valkey-cli,valkey-sentinel,valkey-server} ${valkey_install_dir}/bin/
    /bin/cp valkey.conf ${valkey_install_dir}/etc/
    ln -sf ${valkey_install_dir}/bin/* /usr/local/bin/
    sed -i 's@pidfile.*@pidfile /var/run/valkey/valkey.pid@' ${valkey_install_dir}/etc/valkey.conf
    sed -i "s@logfile.*@logfile ${valkey_install_dir}/var/valkey.log@" ${valkey_install_dir}/etc/valkey.conf
    sed -i "s@^dir.*@dir ${valkey_install_dir}/var@" ${valkey_install_dir}/etc/valkey.conf
    sed -i 's@daemonize no@daemonize yes@' ${valkey_install_dir}/etc/valkey.conf
    sed -i "s@^# bind 127.0.0.1.*@bind 127.0.0.1 -::1@" ${valkey_install_dir}/etc/valkey.conf
    valkey_maxmemory=`expr ${Mem:-1024} / 8`000000
    [ -z "`grep ^maxmemory ${valkey_install_dir}/etc/valkey.conf`" ] && sed -i "s@maxmemory <bytes>@maxmemory <bytes>\nmaxmemory ${valkey_maxmemory}@" ${valkey_install_dir}/etc/valkey.conf
    sed -i 's@^loadmodule @#loadmodule @g' ${valkey_install_dir}/etc/valkey.conf
    local valkey_port=6379
    if [ -e "${redis_install_dir}/bin/redis-server" ] || ss -tnl 2>/dev/null | grep -q ':6379 '; then
      valkey_port=6380
      sed -i "s@^port 6379@port ${valkey_port}@" ${valkey_install_dir}/etc/valkey.conf
    fi
    echo "${CSUCCESS}Valkey-server installed successfully! ${CEND}"
    popd > /dev/null
    rm -rf valkey-${valkey_ver}
    id -u valkey >/dev/null 2>&1
    [ $? -ne 0 ] && useradd -M -s /sbin/nologin valkey
    chown -R valkey:valkey ${valkey_install_dir}/{var,etc}

    /bin/cp ../init.d/valkey-server.service /lib/systemd/system/
    sed -i "s@/usr/local/valkey@${valkey_install_dir}@g" /lib/systemd/system/valkey-server.service
    systemctl daemon-reload 2>/dev/null || true
    systemctl enable valkey-server 2>/dev/null || true
    if ! systemctl restart valkey-server 2>/dev/null && ! systemctl start valkey-server 2>/dev/null; then
      mkdir -p /var/run/valkey
      chown -R valkey:valkey /var/run/valkey
      LC_ALL=C su -s /bin/sh valkey -c "${valkey_install_dir}/bin/valkey-server ${valkey_install_dir}/etc/valkey.conf"
    fi
    local valkey_started=0
    for ((i=1; i<=5; i++)); do
      if ${valkey_install_dir}/bin/valkey-cli -p ${valkey_port} ping 2>/dev/null | grep -q 'PONG'; then
        valkey_started=1
        break
      fi
      sleep 1
    done
    if [ ${valkey_started} -eq 0 ]; then
      echo "${CFAILURE}Valkey-server start failed! valkey-cli ping did not return PONG. ${CEND}"
      systemctl status valkey-server --no-pager 2>/dev/null || true
      kill -9 $$; exit 1;
    fi
  else
    rm -rf ${valkey_install_dir}
    echo "${CFAILURE}Valkey-server install failed, Please contact the author! ${CEND}" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
    kill -9 $$; exit 1;
  fi
  popd > /dev/null
}

Uninstall_valkey_server() {
  if [ -e "${valkey_install_dir}/bin/valkey-server" ]; then
    systemctl stop valkey-server
    systemctl disable valkey-server
    rm -f /lib/systemd/system/valkey-server.service
    rm -rf ${valkey_install_dir} /var/run/valkey
    echo; echo "${CMSG}Valkey server uninstall completed${CEND}"
  else
    echo; echo "${CWARNING}Valkey server does not exist! ${CEND}"
  fi
}
