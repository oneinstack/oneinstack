#!/bin/bash

Install_PHP84() {
  # Check CentOS version
  if [ -f /etc/redhat-release ]; then
    OS_VERSION=$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release | cut -d'.' -f1)
    if [ "${OS_VERSION}" -lt "8" ]; then
      echo "${CFAILURE}Error: PHP 8.4 cannot be installed on CentOS ${OS_VERSION}. Minimum required version is CentOS 8.${CEND}"
      kill -9 $$; exit 1;
    fi
  fi

  pushd ${oneinstack_dir}/src > /dev/null
  
  if [ ! -e "${php_install_dir}/bin/phpize" ]; then
    PHP_version=8.4.4
    PHP_main_ver=84
    
    # 下载和校验
    src_url=https://www.php.net/distributions/php-${PHP_version}.tar.gz && Download_src
    
    # 编译安装
    tar xzf php-${PHP_version}.tar.gz
    pushd php-${PHP_version} > /dev/null
    make clean
    [ ! -d "${php_install_dir}" ] && mkdir -p ${php_install_dir}
    
    # PHP 8.4 特定的编译选项
    ./configure --prefix=${php_install_dir} \
    --with-config-file-path=${php_install_dir}/etc \
    --with-config-file-scan-dir=${php_install_dir}/etc/php.d \
    --with-fpm-user=${run_user} \
    --with-fpm-group=${run_user} \
    --enable-mysqlnd \
    --with-mysqli=mysqlnd \
    --with-pdo-mysql=mysqlnd \
    --with-sqlite3 \
    --with-pdo-sqlite \
    --with-openssl \
    --with-zlib \
    --with-zip \
    --with-curl \
    --with-iconv \
    --with-gettext \
    --with-readline \
    --with-ldapsasl \
    --with-sodium \
    --enable-bcmath \
    --enable-fpm \
    --enable-xml \
    --enable-sysvsem \
    --enable-sysvshm \
    --enable-sysvmsg \
    --enable-shmop \
    --enable-sockets \
    --enable-mbstring \
    --enable-pcntl \
    --enable-soap \
    --enable-gd \
    --enable-intl \
    --enable-opcache \
    --enable-ftp \
    --enable-exif \
    --enable-calendar \
    --without-pear \
    --disable-phar \
    --disable-rpath

    make -j ${THREAD} && make install
    
    if [ -e "${php_install_dir}/bin/phpize" ]; then
      # php.ini配置
      mkdir -p ${php_install_dir}/etc/php.d
      \cp php.ini-production ${php_install_dir}/etc/php.ini
      tee -a ${php_install_dir}/etc/php.ini <<EOF

; Modify php.ini Config by User
memory_limit = 512M
output_buffering = On
short_open_tag = On
expose_php = Off
request_order = "CGP"
date.timezone = ${timezone}
post_max_size = 128M
upload_max_filesize = 128M
max_execution_time = 300
realpath_cache_size = 2M
disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,ini_alter,ini_restore,dl,readlink,symlink,popepassthru,stream_socket_server,fsocket,popen
max_file_uploads = 20
max_input_time = 300
EOF

      if [ -e /usr/sbin/sendmail ]; then
        tee -a ${php_install_dir}/etc/php.ini <<EOF
sendmail_path = /usr/sbin/sendmail -t -i
EOF
      fi
      
      # php-fpm.conf配置
      \cp sapi/fpm/php-fpm.conf.in ${php_install_dir}/etc/php-fpm.conf
      \cp sapi/fpm/www.conf.in ${php_install_dir}/etc/php-fpm.d/www.conf
      sed -i "s@^include=@;include=@" ${php_install_dir}/etc/php-fpm.conf
      tee -a ${php_install_dir}/etc/php-fpm.conf <<EOF

; Modify php-fpm.conf Config by User
pid = run/php-fpm.pid
error_log = log/php-fpm.log
log_level = warning
emergency_restart_threshold = 30
emergency_restart_interval = 60s
process_control_timeout = 5s
daemonize = yes
include=${php_install_dir}/etc/php-fpm.d/*.conf
EOF

      # php-fpm.d/www.conf配置
      tee -a ${php_install_dir}/etc/php-fpm.d/www.conf <<EOF

; Modify php-fpm.d/www.conf Config by User
[${run_user}]
listen = /dev/shm/php-cgi.sock
listen.backlog = 65535
listen.allowed_clients = 127.0.0.1
listen.owner = ${run_user}
listen.group = ${run_group}
listen.mode = 0666

user = ${run_user}
group = ${run_group}

pm = dynamic
pm.max_children = 20
pm.start_servers = 15
pm.min_spare_servers = 10
pm.max_spare_servers = 20
pm.max_requests = 10240
pm.process_idle_timeout = 10s
pm.status_path = /php-fpm_status

request_terminate_timeout = 300
request_slowlog_timeout = 10s
slowlog = var/log/slow.log
rlimit_files = 65535
rlimit_core = 0
catch_workers_output = yes

php_admin_value[error_log] = var/log/php-fpm.error.log
php_admin_flag[log_errors] = on

php_admin_value[opcache.enable] = 1
php_admin_value[opcache.memory_consumption] = 128
php_admin_value[opcache.interned_strings_buffer] = 16
php_admin_value[opcache.max_accelerated_files] = 10000
php_admin_value[opcache.validate_timestamps] = 1
php_admin_value[opcache.revalidate_freq] = 60

env[HOSTNAME] = $HOSTNAME
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] = /tmp

; Recommended, if you need to adjust, please modify the following parameters.
EOF

      # php-fpm内存优化
      if [ $Mem -gt 8500 ]; then
        tee -a ${php_install_dir}/etc/php-fpm.d/www.conf <<EOF
pm.max_children = 80
pm.start_servers = 60
pm.min_spare_servers = 50
pm.max_spare_servers = 80
EOF
      elif [ $Mem -gt 6500 ]; then
        tee -a ${php_install_dir}/etc/php-fpm.d/www.conf <<EOF
pm.max_children = 70
pm.start_servers = 50
pm.min_spare_servers = 40
pm.max_spare_servers = 70
EOF
      elif [ $Mem -gt 4500 ]; then
        tee -a ${php_install_dir}/etc/php-fpm.d/www.conf <<EOF
pm.max_children = 60
pm.start_servers = 40
pm.min_spare_servers = 30
pm.max_spare_servers = 60
EOF
      elif [ $Mem -gt 3000 ]; then
        tee -a ${php_install_dir}/etc/php-fpm.d/www.conf <<EOF
pm.max_children = 50
pm.start_servers = 30
pm.min_spare_servers = 20
pm.max_spare_servers = 50
EOF
      else
        tee -a ${php_install_dir}/etc/php-fpm.d/www.conf <<EOF
pm.max_children = $(($Mem/3/20))
pm.start_servers = $(($Mem/3/30))
pm.min_spare_servers = $(($Mem/3/40))
pm.max_spare_servers = $(($Mem/3/20))
EOF
      fi
      
      # 启动脚本
      \cp ${oneinstack_dir}/init.d/php-fpm.service /lib/systemd/system/
      sed -i "s@/usr/local/php@${php_install_dir}@g" /lib/systemd/system/php-fpm.service
      systemctl enable --now php-fpm.service

      # 检测php-fpm是否启动成功，没有成功则重启php-fpm再试一次，如果还不成功则退出
      systemctl status php-fpm.service | grep "Active: active (running)"
      if [ $? -ne 0 ]; then
        systemctl restart php-fpm.service
        systemctl status php-fpm.service | grep "Active: active (running)"
        if [ $? -ne 0 ]; then
          echo "${CFAILURE}PHP ${PHP_version} install failed, Please Contact the author! ${CEND}"
          kill -9 $$; exit 1;
        fi
      fi

      # 环境变量
      echo "export PATH=${php_install_dir}/bin:\$PATH" > /etc/profile.d/php.sh
      
      echo "${CSUCCESS}PHP ${PHP_version} installed successfully! ${CEND}"
      rm -rf php-${PHP_version}
    else
      rm -rf ${php_install_dir}
      echo "${CFAILURE}PHP ${PHP_version} install failed, Please Contact the author! ${CEND}"
      kill -9 $$; exit 1;
    fi
    popd > /dev/null
  fi
  popd > /dev/null
}
