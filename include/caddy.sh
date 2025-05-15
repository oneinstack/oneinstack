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
  # Define the user and group that will run Caddy
  CADDY_USER="caddy"
  CADDY_GROUP="caddy"

  pushd ${oneinstack_dir}/src > /dev/null

  # Create Caddy user and group if they don't exist
  if ! getent group ${CADDY_GROUP} >/dev/null; then
    groupadd --system ${CADDY_GROUP}
  fi

  if ! id -u ${CADDY_USER} >/dev/null 2>&1; then
    useradd --system \
      --gid ${CADDY_GROUP} \
      --home-dir /var/lib/${CADDY_USER} \
      --shell /usr/sbin/nologin \
      --comment "Caddy web server" \
      ${CADDY_USER}
  fi

  # Extract and install Caddy
  tar xzf caddy-${caddy_ver}.tar.gz
  [ ! -d "${caddy_install_dir}/bin" ] && mkdir -p ${caddy_install_dir}/bin
  /bin/cp caddy ${caddy_install_dir}/bin
  chmod +x ${caddy_install_dir}/bin/caddy

  # Set up environment PATH
  [ -z "`grep ^'export PATH=' /etc/profile`" ] && echo "export PATH=${caddy_install_dir}/bin:\$PATH" >> /etc/profile
  [ -n "`grep ^'export PATH=' /etc/profile`" -a -z "`grep ${caddy_install_dir} /etc/profile`" ] && sed -i "s@^export PATH=\(.*\)@export PATH=${caddy_install_dir}/bin:\1@" /etc/profile
  . /etc/profile

  # Create symlink
  [ ! -L "/usr/local/bin/caddy" ] && ln -s ${caddy_install_dir}/bin/caddy /usr/local/bin/caddy

  # Set up configuration directory
  [ ! -d "${caddy_install_dir}/conf" ] && mkdir -p ${caddy_install_dir}/conf
  /bin/cp ../config/Caddyfile ${caddy_install_dir}/conf/

  # Set up systemd service
  /bin/cp ../init.d/caddy.service /lib/systemd/system/

  # Modify service file with correct paths and user/group
  sed -i "s@/usr/local/caddy@${caddy_install_dir}@g" /lib/systemd/system/caddy.service
  sed -i "s@User=.*@User=${CADDY_USER}@" /lib/systemd/system/caddy.service
  sed -i "s@Group=.*@Group=${CADDY_GROUP}@" /lib/systemd/system/caddy.service

  # Set proper permissions
  chown -R ${CADDY_USER}:${CADDY_GROUP} ${caddy_install_dir}
  chmod 755 ${caddy_install_dir}

  # Create basic Caddyfile if not exists
  if [ ! -f "${caddy_install_dir}/conf/Caddyfile" ]; then
    echo ":80 {
      respond \"Hello, Caddy is working!\"
    }" > ${caddy_install_dir}/conf/Caddyfile
    chown ${CADDY_USER}:${CADDY_GROUP} ${caddy_install_dir}/conf/Caddyfile
  fi

  # Enable and start service
  systemctl daemon-reload
  systemctl enable caddy

  if ! systemctl start caddy; then
    echo "${CFAILURE}Caddy failed to start! Checking logs...${CEND}"
    journalctl -u caddy --no-pager -n 20
    exit 1
  fi

  echo "${CSUCCESS}Caddy installed and started successfully!${CEND}"
  echo "Caddy version: $(caddy version)"
}