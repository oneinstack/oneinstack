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
      # 配置文件
      mkdir -p ${php_install_dir}/etc/php.d
      \cp php.ini-production ${php_install_dir}/etc/php.ini

      # 设置php.ini配置
      tee -a ${php_install_dir}/etc/php.ini <<EOF

; 内存限制
memory_limit = 256M

; 输出缓冲
output_buffering = On

; 输出缓冲
output_buffering =

; 短标签
short_open_tag = On

; 暴露php出错信息
expose_php = Off

; 请求顺序
request_order = "CGP"

; 时区
date.timezone = ${timezone}

; 最大上传大小
post_max_size = 100M

; 最大上传大小
upload_max_filesize = 50M

; 最大执行时间
max_execution_time = 600

; 输出缓冲
realpath_cache_size = 2M

; 禁用函数
disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,ini_alter,ini_restore,dl,readlink,symlink,popepassthru,stream_socket_server,fsocket,popen
EOF

      if [ -e /usr/sbin/sendmail ]; then
        tee -a ${php_install_dir}/etc/php.ini <<EOF

; 发送邮件
sendmail_path = /usr/sbin/sendmail -t -i
EOF
      fi
      
      # PHP-FPM配置
      \cp sapi/fpm/php-fpm.conf.in ${php_install_dir}/etc/php-fpm.conf
      \cp sapi/fpm/www.conf.in ${php_install_dir}/etc/php-fpm.d/www.conf
      #sed -i "s@^;pid = run/php-fpm.pid@pid = run/php-fpm.pid@" ${php_install_dir}/etc/php-fpm.conf

      # 设置php-fpm.conf配置
      sed -i "s@^include=@;include=@" ${php_install_dir}/etc/php-fpm.conf
      tee -a ${php_install_dir}/etc/php-fpm.conf <<EOF

; 进程ID
pid = run/php-fpm.pid

; 错误日志
error_log = log/php-fpm.log

; 日志级别
log_level = warning

; 紧急重启阈值
emergency_restart_threshold = 30

; 紧急重启间隔
emergency_restart_interval = 60s

; 进程控制超时
process_control_timeout = 5s

; 守护进程
daemonize = yes

; 加载扩展配置
include=${php_install_dir}/etc/php-fpm.d/*.conf
EOF

      # 设置php-fpm.d/www.conf配置
      tee -a ${php_install_dir}/etc/php-fpm.d/www.conf <<EOF

[${run_user}]
; 监听
listen = /dev/shm/php-cgi.sock

; 监听队列
listen.backlog = -1

; 允许客户端
listen.allowed_clients = 127.0.0.1

; 监听用户
listen.owner = ${run_user}

; 监听组
listen.group = ${run_group}

; 监听模式
listen.mode = 0666

; 用户
user = ${run_user}

; 组
group = ${run_group}

; 进程管理
pm = dynamic

; 最大进程数
pm.max_children = 12

; 启动进程数
pm.start_servers = 8

; 最小空闲进程数
pm.min_spare_servers = 6

; 最大空闲进程数
pm.max_spare_servers = 12

; 最大请求数
pm.max_requests = 2048

; 进程空闲超时
pm.process_idle_timeout = 10s

; 请求超时
request_terminate_timeout = 120

; 慢日志超时
request_slowlog_timeout = 0

; 状态路径
pm.status_path = /php-fpm_status

; 慢日志
slowlog = var/log/slow.log

; 文件限制
rlimit_files = 51200

; 核心限制
rlimit_core = 0

; 捕获工作者输出
catch_workers_output = yes

; 环境变量
env[HOSTNAME] = $HOSTNAME
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] = /tmp
EOF

      # 设置php-fpm内存优化
      if [ $Mem -gt 8500 ]; then
        tee -a ${php_install_dir}/etc/php-fpm.conf <<EOF

; 最大进程数
pm.max_children = 80

; 启动进程数
pm.start_servers = 60

; 最小空闲进程数
pm.min_spare_servers = 50

; 最大空闲进程数
pm.max_spare_servers = 80
EOF
      elif [ $Mem -gt 6500 ]; then
        tee -a ${php_install_dir}/etc/php-fpm.conf <<EOF

; 最大进程数
pm.max_children = 70

; 启动进程数
pm.start_servers = 50

; 最小空闲进程数
pm.min_spare_servers = 40

; 最大空闲进程数
pm.max_spare_servers = 70
EOF
      elif [ $Mem -gt 4500 ]; then
        tee -a ${php_install_dir}/etc/php-fpm.conf <<EOF

; 最大进程数
pm.max_children = 60

; 启动进程数
pm.start_servers = 40

; 最小空闲进程数
pm.min_spare_servers = 30

; 最大空闲进程数
pm.max_spare_servers = 60
EOF
      elif [ $Mem -gt 3000 ]; then
        tee -a ${php_install_dir}/etc/php-fpm.conf <<EOF

; 最大进程数
pm.max_children = 50

; 启动进程数
pm.start_servers = 30

; 最小空闲进程数
pm.min_spare_servers = 20

; 最大空闲进程数
pm.max_spare_servers = 50
EOF
      else
        tee -a ${php_install_dir}/etc/php-fpm.conf <<EOF

; 最大进程数
pm.max_children = $(($Mem/3/20))

; 启动进程数
pm.start_servers = $(($Mem/3/30))

; 最小空闲进程数
pm.min_spare_servers = $(($Mem/3/40))

; 最大空闲进程数
pm.max_spare_servers = $(($Mem/3/20))
EOF
      fi
      
      # 启动脚本
      \cp ${oneinstack_dir}/init.d/php-fpm.service /lib/systemd/system/
      sed -i "s@/usr/local/php@${php_install_dir}@g" /lib/systemd/system/php-fpm.service
      systemctl enable php-fpm

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
