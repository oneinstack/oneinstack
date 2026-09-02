#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Install_ClickHouse() {
  pushd ${oneinstack_dir}/src > /dev/null

  id -u clickhouse >/dev/null 2>&1
  [ $? -ne 0 ] && useradd -M -s /sbin/nologin clickhouse

  mkdir -p ${clickhouse_install_dir}/{bin,etc/clickhouse-server,etc/clickhouse-client}
  mkdir -p ${clickhouse_data_dir}/{tmp,user_files,format_schemas}
  mkdir -p /var/log/clickhouse-server /etc/clickhouse-server /etc/clickhouse-client

  # Extract prebuilt static binaries
  tar xzf clickhouse-common-static-${clickhouse_ver}-${SYS_ARCH}.tgz
  tar xzf clickhouse-server-${clickhouse_ver}-${SYS_ARCH}.tgz
  tar xzf clickhouse-client-${clickhouse_ver}-${SYS_ARCH}.tgz

  if [ -f "clickhouse-common-static-${clickhouse_ver}-${SYS_ARCH}/usr/bin/clickhouse" ]; then
    /bin/cp clickhouse-common-static-${clickhouse_ver}-${SYS_ARCH}/usr/bin/clickhouse ${clickhouse_install_dir}/bin/
    chmod +x ${clickhouse_install_dir}/bin/clickhouse

    # Create symlinks for clickhouse components
    ln -sf clickhouse ${clickhouse_install_dir}/bin/clickhouse-server
    ln -sf clickhouse ${clickhouse_install_dir}/bin/clickhouse-client
    ln -sf clickhouse ${clickhouse_install_dir}/bin/clickhouse-local
    ln -sf clickhouse ${clickhouse_install_dir}/bin/clickhouse-benchmark

    ln -sf ${clickhouse_install_dir}/bin/clickhouse /usr/local/bin/clickhouse
    ln -sf ${clickhouse_install_dir}/bin/clickhouse-server /usr/local/bin/clickhouse-server
    ln -sf ${clickhouse_install_dir}/bin/clickhouse-client /usr/local/bin/clickhouse-client

    # Copy and setup configuration files
    if [ -d "clickhouse-server-${clickhouse_ver}-${SYS_ARCH}/etc/clickhouse-server" ]; then
      /bin/cp -R clickhouse-server-${clickhouse_ver}-${SYS_ARCH}/etc/clickhouse-server/* ${clickhouse_install_dir}/etc/clickhouse-server/
      /bin/cp -R clickhouse-server-${clickhouse_ver}-${SYS_ARCH}/etc/clickhouse-server/* /etc/clickhouse-server/
    fi

    if [ -d "clickhouse-client-${clickhouse_ver}-${SYS_ARCH}/etc/clickhouse-client" ]; then
      /bin/cp -R clickhouse-client-${clickhouse_ver}-${SYS_ARCH}/etc/clickhouse-client/* ${clickhouse_install_dir}/etc/clickhouse-client/
      /bin/cp -R clickhouse-client-${clickhouse_ver}-${SYS_ARCH}/etc/clickhouse-client/* /etc/clickhouse-client/
    fi

    # Adjust paths in config.xml
    if [ -f "/etc/clickhouse-server/config.xml" ]; then
      sed -i "s@<path>/var/lib/clickhouse/</path>@<path>${clickhouse_data_dir}/</path>@g" /etc/clickhouse-server/config.xml
      sed -i "s@<tmp_path>/var/lib/clickhouse/tmp/</tmp_path>@<tmp_path>${clickhouse_data_dir}/tmp/</tmp_path>@g" /etc/clickhouse-server/config.xml
      sed -i "s@<user_files_path>/var/lib/clickhouse/user_files/</user_files_path>@<user_files_path>${clickhouse_data_dir}/user_files/</user_files_path>@g" /etc/clickhouse-server/config.xml
      sed -i "s@<!-- <listen_host>::</listen_host> -->@<listen_host>0.0.0.0</listen_host>@g" /etc/clickhouse-server/config.xml
      sed -i "s@<!-- <listen_host>0.0.0.0</listen_host> -->@<listen_host>0.0.0.0</listen_host>@g" /etc/clickhouse-server/config.xml
    fi

    # Set password if specified
    if [ -n "${dbclickhousepwd}" ] && [ -f "/etc/clickhouse-server/users.xml" ]; then
      sed -i "s@<!-- <password></password> -->@<password>${dbclickhousepwd}</password>@g" /etc/clickhouse-server/users.xml
      sed -i "s@<password></password>@<password>${dbclickhousepwd}</password>@g" /etc/clickhouse-server/users.xml
    fi

    # Set permissions
    chown -R clickhouse:clickhouse ${clickhouse_install_dir} ${clickhouse_data_dir} /var/log/clickhouse-server /etc/clickhouse-server /etc/clickhouse-client

    # Systemd service
    cat > /lib/systemd/system/clickhouse-server.service << EOF
[Unit]
Description=ClickHouse Server (analytical database management system)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=clickhouse
Group=clickhouse
Restart=always
RestartSec=30
RuntimeMaxSec=86400
ExecStart=${clickhouse_install_dir}/bin/clickhouse-server --config-file=/etc/clickhouse-server/config.xml
LimitNOFILE=500000
LimitNPROC=500000
LimitMEMLOCK=infinity
CapabilityBoundingSet=CAP_NET_ADMIN CAP_IPC_LOCK CAP_SYS_NICE

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable clickhouse-server
    systemctl start clickhouse-server

    sleep 3
    if systemctl is-active clickhouse-server >/dev/null 2>&1 || [ -n "\`pgrep clickhouse-server\`" ]; then
      echo "\${CSUCCESS}ClickHouse server installed successfully! \${CEND}"
    else
      echo "\${CWARNING}ClickHouse server started with warnings, please check log: /var/log/clickhouse-server/clickhouse-server.err.log \${CEND}"
    fi

    rm -rf clickhouse-common-static-\${clickhouse_ver}-\${SYS_ARCH} clickhouse-server-\${clickhouse_ver}-\${SYS_ARCH} clickhouse-client-\${clickhouse_ver}-\${SYS_ARCH}
  else
    rm -rf \${clickhouse_install_dir}
    echo "\${CFAILURE}ClickHouse install failed, Please contact the author! \${CEND}"
    kill -9 \$\$; exit 1;
  fi

  popd > /dev/null
}

Uninstall_ClickHouse() {
  if [ -d "\${clickhouse_install_dir}" ] || [ -f "/lib/systemd/system/clickhouse-server.service" ]; then
    systemctl stop clickhouse-server >/dev/null 2>&1
    systemctl disable clickhouse-server >/dev/null 2>&1
    rm -f /lib/systemd/system/clickhouse-server.service
    systemctl daemon-reload
    rm -rf \${clickhouse_install_dir} /etc/clickhouse-server /etc/clickhouse-client /var/log/clickhouse-server
    rm -f /usr/local/bin/clickhouse /usr/local/bin/clickhouse-server /usr/local/bin/clickhouse-client
    echo; echo "\${CMSG}ClickHouse uninstall completed! \${CEND}"
  else
    echo; echo "\${CWARNING}ClickHouse does not exist! \${CEND}"
  fi
}
