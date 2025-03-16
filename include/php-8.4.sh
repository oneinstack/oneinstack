#!/bin/bash

Install_PHP84() {
  pushd ${oneinstack_dir}/src > /dev/null
  
  if [ ! -e "${php_install_dir}/bin/phpize" ]; then
    PHP_version=8.4.4
    PHP_main_ver=84
    
    # 下载和校验
    src_url=https://www.php.net/distributions/php-${PHP_version}.tar.gz && Download_src
    
    # 安装依赖
    Install_PHP_Dependent
    
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
      
      # PHP-FPM配置
      \cp sapi/fpm/php-fpm.conf.in ${php_install_dir}/etc/php-fpm.conf
      \cp sapi/fpm/www.conf.in ${php_install_dir}/etc/php-fpm.d/www.conf
      sed -i "s@^;pid = run/php-fpm.pid@pid = run/php-fpm.pid@" ${php_install_dir}/etc/php-fpm.conf
      
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