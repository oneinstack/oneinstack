#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Install_Caddy() {

  pushd ${oneinstack_dir}/src > /dev/null
  id -g ${run_group} >/dev/null 2>&1
  [ $? -ne 0 ] && groupadd ${run_group}
  id -u ${run_user} >/dev/null 2>&1
  [ $? -ne 0 ] && useradd -g ${run_group} -M -s /sbin/nologin ${run_user}

  tar xzf caddy_${caddy_ver}_linux_amd64.tar.gz

  #move caddy to /usr/local/caddy/bin
  [ ! -d "${caddy_install_dir}/bin" ] && mkdir -p ${caddy_install_dir}/bin
  /bin/cp caddy ${caddy_install_dir}/bin

  chmod +x ${caddy_install_dir}/bin/caddy

  [ -z "`grep ^'export PATH=' /etc/profile`" ] && echo "export PATH=${caddy_install_dir}/bin:\$PATH" >> /etc/profile
  [ -n "`grep ^'export PATH=' /etc/profile`" -a -z "`grep ${caddy_install_dir} /etc/profile`" ] && sed -i "s@^export PATH=\(.*\)@export PATH=${caddy_install_dir}/bin:\1@" /etc/profile
  . /etc/profile

  #make soft link
  # [ ! -L "/usr/local/bin/caddy" ] && ln -s ${caddy_install_dir}/bin/caddy /usr/local/bin/caddy

  #move caddyfile to /usr/local/caddy/conf
  [ ! -d "${caddy_install_dir}/conf/vhost" ] && mkdir -p ${caddy_install_dir}/conf/vhost
  /bin/cp ../config/Caddyfile ${caddy_install_dir}/conf/
  sed -i "s@/usr/local/caddy@${caddy_install_dir}@g" ${caddy_install_dir}/conf/Caddyfile

  #move caddy.service to /lib/systemd/system
  /bin/cp ../init.d/caddy.service /lib/systemd/system/

  #modify caddy.service
  sed -i "s@/usr/local/caddy@${caddy_install_dir}@g" /lib/systemd/system/caddy.service
  sed -i "s@User=caddy@User=${run_user}@g" /lib/systemd/system/caddy.service
  sed -i "s@Group=caddy@Group=${run_group}@g" /lib/systemd/system/caddy.service
  chown -R ${run_user}:${run_group} ${caddy_install_dir}

  #设置caddy开机启动
  systemctl daemon-reload
  systemctl enable caddy

  #start caddy service
  systemctl restart caddy || systemctl start caddy

  local caddy_started=0
  for ((i=1; i<=5; i++)); do
    if systemctl is-active caddy >/dev/null 2>&1; then
      caddy_started=1
      break
    fi
    sleep 1
  done

  if [ ${caddy_started} -eq 0 ]; then
    echo "${CFAILURE}Caddy start failed! Service is not active. ${CEND}"
    systemctl status caddy --no-pager
    kill -9 $$; exit 1
  fi

  echo "${CSUCCESS}Caddy installed successfully! ${CEND}"
}
