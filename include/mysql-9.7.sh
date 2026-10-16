#!/bin/bash
# MySQL 9.7 LTS installer for modern x86_64 Linux distributions.

Install_MySQL97() {
  local mysql97_package="mysql-${mysql97_ver}-linux-glibc2.28-x86_64"
  local existing_entry mysql_ready=0

  MySQL97_OS_Supported || {
    echo "${CFAILURE}MySQL 9.7 requires x86_64 with RHEL 8+, Debian 12+, or Ubuntu 22+. ${CEND}"
    return 1
  }
  [ "${dbinstallmethod}" != '1' ] && {
    echo "${CFAILURE}MySQL 9.7 supports binary installation only. ${CEND}"
    return 1
  }

  existing_entry=$(find "${mysql_install_dir}" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)
  [ -n "${existing_entry}" ] && {
    echo "${CFAILURE}MySQL 9.7 program directory is not empty: ${mysql_install_dir}${CEND}"
    echo "Existing entry: ${existing_entry}"
    return 1
  }
  existing_entry=$(find "${mysql_data_dir}" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)
  [ -n "${existing_entry}" ] && {
    echo "${CFAILURE}MySQL 9.7 data directory is not empty: ${mysql_data_dir}${CEND}"
    echo "Existing entry: ${existing_entry}"
    return 1
  }

  pushd "${oneinstack_dir}/src" > /dev/null || return 1
  id -u mysql > /dev/null 2>&1 || useradd -M -s /sbin/nologin mysql

  mkdir -p "${mysql_install_dir}" "${mysql_data_dir}"
  chown mysql:mysql -R "${mysql_data_dir}"
  tar xJf "${mysql97_package}.tar.xz" || {
    echo "${CFAILURE}Unable to extract the MySQL 9.7 package. ${CEND}"
    return 1
  }
  mv "${mysql97_package}"/* "${mysql_install_dir}/" || {
    echo "${CFAILURE}Unable to place the MySQL 9.7 installation files. ${CEND}"
    return 1
  }
  [ -d "${mysql_install_dir}/support-files" ] || {
    echo "${CFAILURE}MySQL 9.7 installation files are incomplete. ${CEND}"
    return 1
  }

  if [ -e "${mysql_install_dir}/bin/mysqld_safe" ]; then
    sed -i 's@executing mysqld_safe@executing mysqld_safe\nexport LD_PRELOAD=/usr/local/lib/libjemalloc.so@' "${mysql_install_dir}/bin/mysqld_safe"
    sed -i "s@/usr/local/mysql@${mysql_install_dir}@g" "${mysql_install_dir}/bin/mysqld_safe"
  fi
  sed -i "s+^dbrootpwd.*+dbrootpwd='${dbrootpwd}'+" ../options.conf

  /bin/cp "${mysql_install_dir}/support-files/mysql.server" /etc/init.d/mysqld
  sed -i "s@^basedir=.*@basedir=${mysql_install_dir}@" /etc/init.d/mysqld
  sed -i "s@^datadir=.*@datadir=${mysql_data_dir}@" /etc/init.d/mysqld
  chmod +x /etc/init.d/mysqld
  [ "${PM}" == 'yum' ] && { chkconfig --add mysqld; chkconfig mysqld on; }
  [ "${PM}" == 'apt-get' ] && update-rc.d mysqld defaults

  cat > /etc/my.cnf << EOF
[client]
port = 3306
socket = /tmp/mysql.sock
default-character-set = utf8mb4

[mysql]
prompt="MySQL [\\d]> "
no-auto-rehash

[mysqld]
port = 3306
socket = /tmp/mysql.sock
basedir = ${mysql_install_dir}
datadir = ${mysql_data_dir}
pid-file = ${mysql_data_dir}/mysql.pid
user = mysql
bind-address = 127.0.0.1
mysqlx = OFF
server-id = 1
character-set-server = utf8mb4
collation-server = utf8mb4_0900_ai_ci
skip-name-resolve
max_connections = 1000
max_connect_errors = 6000
open_files_limit = 65535
table_open_cache = 128
max_allowed_packet = 500M
max_heap_table_size = 8M
tmp_table_size = 16M
thread_cache_size = 8
log_bin = mysql-bin
binlog_expire_logs_seconds = 604800
log_error = ${mysql_data_dir}/mysql-error.log
slow_query_log = 1
long_query_time = 1
slow_query_log_file = ${mysql_data_dir}/mysql-slow.log
performance_schema = OFF
default_storage_engine = InnoDB
innodb_file_per_table = 1
innodb_buffer_pool_size = 64M
innodb_flush_log_at_trx_commit = 2
innodb_lock_wait_timeout = 120
interactive_timeout = 28800
wait_timeout = 28800

[mysqldump]
quick
max_allowed_packet = 500M
EOF

  sed -i "s@^max_connections.*@max_connections = $((${Mem}/3))@" /etc/my.cnf
  if [ "${Mem}" -gt 1500 ] && [ "${Mem}" -le 2500 ]; then
    sed -i 's@^thread_cache_size.*@thread_cache_size = 16@' /etc/my.cnf
    sed -i 's@^innodb_buffer_pool_size.*@innodb_buffer_pool_size = 128M@' /etc/my.cnf
    sed -i 's@^tmp_table_size.*@tmp_table_size = 32M@' /etc/my.cnf
    sed -i 's@^table_open_cache.*@table_open_cache = 256@' /etc/my.cnf
  elif [ "${Mem}" -gt 2500 ] && [ "${Mem}" -le 3500 ]; then
    sed -i 's@^thread_cache_size.*@thread_cache_size = 32@' /etc/my.cnf
    sed -i 's@^innodb_buffer_pool_size.*@innodb_buffer_pool_size = 512M@' /etc/my.cnf
    sed -i 's@^tmp_table_size.*@tmp_table_size = 64M@' /etc/my.cnf
    sed -i 's@^table_open_cache.*@table_open_cache = 512@' /etc/my.cnf
  elif [ "${Mem}" -gt 3500 ]; then
    sed -i 's@^thread_cache_size.*@thread_cache_size = 64@' /etc/my.cnf
    sed -i 's@^innodb_buffer_pool_size.*@innodb_buffer_pool_size = 1024M@' /etc/my.cnf
    sed -i 's@^tmp_table_size.*@tmp_table_size = 128M@' /etc/my.cnf
    sed -i 's@^table_open_cache.*@table_open_cache = 1024@' /etc/my.cnf
  fi

  "${mysql_install_dir}/bin/mysqld" --defaults-file=/etc/my.cnf \
    --log-error=/dev/stderr --validate-config || {
    echo "${CFAILURE}MySQL 9.7 configuration validation failed. ${CEND}"
    return 1
  }
  "${mysql_install_dir}/bin/mysqld" --no-defaults --initialize-insecure \
    --user=mysql --basedir="${mysql_install_dir}" --datadir="${mysql_data_dir}" || {
    echo "${CFAILURE}MySQL 9.7 data directory initialization failed. ${CEND}"
    [ -f "${mysql_data_dir}/mysql-error.log" ] && tail -n 80 "${mysql_data_dir}/mysql-error.log"
    return 1
  }

  [ "${Wsl}" == true ] && chmod 600 /etc/my.cnf
  chown mysql:mysql -R "${mysql_data_dir}"
  [ -d /etc/mysql ] && /bin/mv /etc/mysql{,_bk}
  service mysqld start || {
    echo "${CFAILURE}MySQL 9.7 service failed to start.${CEND}"
    [ -f "${mysql_data_dir}/mysql-error.log" ] && tail -n 80 "${mysql_data_dir}/mysql-error.log"
    return 1
  }

  for mysql_wait in {1..30}; do
    "${mysql_install_dir}/bin/mysqladmin" --protocol=socket -uroot ping > /dev/null 2>&1 && {
      mysql_ready=1
      break
    }
    sleep 1
  done
  [ "${mysql_ready}" == '1' ] || {
    echo "${CFAILURE}MySQL 9.7 did not become ready; check ${mysql_data_dir}/mysql-error.log. ${CEND}"
    return 1
  }

  "${mysql_install_dir}/bin/mysql" --protocol=socket -uroot << EOF || {
CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED BY '${dbrootpwd}';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${dbrootpwd}';
EOF
    echo "${CFAILURE}MySQL 9.7 root account initialization failed. ${CEND}"
    return 1
  }

  [ -z "$(grep ^'export PATH=' /etc/profile)" ] && echo "export PATH=${mysql_install_dir}/bin:\$PATH" >> /etc/profile
  [ -n "$(grep ^'export PATH=' /etc/profile)" ] && [ -z "$(grep "${mysql_install_dir}" /etc/profile)" ] && \
    sed -i "s@^export PATH=\(.*\)@export PATH=${mysql_install_dir}/bin:\1@" /etc/profile
  rm -rf /etc/ld.so.conf.d/{mysql,mariadb,percona}*.conf
  [ -e "${mysql_install_dir}/my.cnf" ] && rm -f "${mysql_install_dir}/my.cnf"
  echo "${mysql_install_dir}/lib" > /etc/ld.so.conf.d/z-mysql.conf
  ldconfig
  service mysqld stop || {
    echo "${CFAILURE}MySQL 9.7 service failed to stop after initialization.${CEND}"
    return 1
  }

  rm -rf "${mysql97_package}"
  popd > /dev/null
  echo "${CSUCCESS}MySQL ${mysql97_ver} LTS installed successfully. ${CEND}"
}
