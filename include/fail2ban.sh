#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Install_fail2ban() {
  pushd ${oneinstack_dir}/src > /dev/null
  src_url=http://mirrors.linuxeye.com/oneinstack/src/fail2ban-${fail2ban_ver}.tar.gz && Download_src
  tar xzf fail2ban-${fail2ban_ver}.tar.gz
  pushd fail2ban-${fail2ban_ver} > /dev/null
  sed -i 's@for i in xrange(50)@for i in range(50)@' fail2ban/__init__.py
  ${python_install_dir}/bin/python setup.py install
  /bin/cp build/fail2ban.service /lib/systemd/system/
  systemctl enable fail2ban
  [ -z "`grep ^Port /etc/ssh/sshd_config`" ] && now_ssh_port=22 || now_ssh_port=`grep ^Port /etc/ssh/sshd_config | awk '{print $2}' | head -1`
  if [ "${PM}" == 'yum' ]; then
  cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
ignoreip = 127.0.0.1/8
bantime  = 86400
findtime = 600
maxretry = 5
backend = auto
banaction = firewallcmd-ipset
action = %(action_mwl)s

[sshd]
enabled = true
filter  = sshd
port    = ${now_ssh_port}
action = %(action_mwl)s
logpath = /var/log/secure
bantime  = 86400
findtime = 600
maxretry = 5
EOF
  elif [ "${PM}" == 'apt-get' ]; then
    if ufw status | grep -wq inactive; then
      ufw default allow incoming
      ufw --force enable
    fi
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
ignoreip = 127.0.0.1/8
bantime  = 86400
findtime = 600
maxretry = 5
backend = auto
banaction = ufw
action = %(action_mwl)s

[sshd]
enabled = true
filter  = sshd
port    = ${now_ssh_port}
action = %(action_mwl)s
logpath = /var/log/auth.log
bantime  = 86400
findtime = 600
maxretry = 5
EOF
  fi
  cat > /etc/logrotate.d/fail2ban << EOF
/var/log/fail2ban.log {
    missingok
    notifempty
    postrotate
      ${python_install_dir}/bin/fail2ban-client flushlogs >/dev/null || true
    endscript
}
EOF
  kill -9 `ps -ef | grep fail2ban | grep -v grep | awk '{print $2}'` > /dev/null 2>&1
  systemctl start fail2ban
  popd > /dev/null
  if [ -e "${python_install_dir}/bin/fail2ban-server" ]; then
    echo; echo "${CSUCCESS}fail2ban installed successfully! ${CEND}"
  else
    echo; echo "${CFAILURE}fail2ban install failed, Please try again! ${CEND}"
  fi
  popd > /dev/null
}

Uninstall_fail2ban() {
  service fail2ban stop
  ${python_install_dir}/bin/pip uninstall -y fail2ban > /dev/null 2>&1
  rm -rf /etc/init.d/fail2ban /etc/fail2ban /etc/logrotate.d/fail2ban /var/log/fail2ban.* /var/run/fail2ban
  echo; echo "${CMSG}fail2ban uninstall completed${CEND}";
}
