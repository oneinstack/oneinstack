#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Install_PHP85() {
  if [ "${Family}" == 'rhel' ] && [ "${RHEL_ver:-0}" -lt 8 ]; then
    echo "${CFAILURE}Error: PHP 8.5 cannot be installed on RHEL/CentOS ${RHEL_ver}. Minimum required version is 8.${CEND}"
    kill -9 $$; exit 1;
  fi

  pushd ${oneinstack_dir}/src > /dev/null
  if [ ! -e "/usr/local/lib/libiconv.la" ]; then
    tar xzf libiconv-${libiconv_ver}.tar.gz
    pushd libiconv-${libiconv_ver} > /dev/null
    ./configure
    make -j ${THREAD} && make install
    popd > /dev/null
    rm -rf libiconv-${libiconv_ver}
  fi

  if [ ! -e "${curl_install_dir}/lib/libcurl.la" ]; then
    tar xzf curl-${curl_ver}.tar.gz
    pushd curl-${curl_ver} > /dev/null
    [ -e "/usr/local/lib/libnghttp2.so" ] && with_nghttp2='--with-nghttp2=/usr/local'
    ./configure --prefix=${curl_install_dir} ${php85_with_ssl} ${with_nghttp2} --without-libpsl
    make -j ${THREAD} && make install
    popd > /dev/null
    rm -rf curl-${curl_ver}
  fi

  if [ ! -e "${freetype_install_dir}/lib/libfreetype.la" ]; then
    tar xzf freetype-${freetype_ver}.tar.gz
    pushd freetype-${freetype_ver} > /dev/null
    ./configure --prefix=${freetype_install_dir} --enable-freetype-config
    make -j ${THREAD} && make install
    ln -sf ${freetype_install_dir}/include/freetype2/* /usr/include/
    [ -d /usr/lib/pkgconfig ] && /bin/cp ${freetype_install_dir}/lib/pkgconfig/freetype2.pc /usr/lib/pkgconfig/
    popd > /dev/null
    rm -rf freetype-${freetype_ver}
  fi

  if [ ! -e "/usr/local/lib/pkgconfig/libargon2.pc" ]; then
    tar xzf argon2-${argon2_ver}.tar.gz
    pushd argon2-${argon2_ver} > /dev/null
    make -j ${THREAD} && make install
    [ ! -d /usr/local/lib/pkgconfig ] && mkdir -p /usr/local/lib/pkgconfig
    /bin/cp libargon2.pc /usr/local/lib/pkgconfig/
    popd > /dev/null
    rm -rf argon2-${argon2_ver}
  fi

  if [ ! -e "/usr/local/lib/libsodium.la" ]; then
    tar xzf libsodium-${libsodium_up_ver}.tar.gz
    pushd libsodium-${libsodium_up_ver} > /dev/null
    ./configure --disable-dependency-tracking --enable-minimal
    make -j ${THREAD} && make install
    popd > /dev/null
    rm -rf libsodium-${libsodium_up_ver}
  fi

  if [ ! -e "/usr/local/lib/libzip.la" -a ! -e "/usr/local/lib/libzip.so" ]; then
    tar xzf libzip-${libzip_ver}.tar.gz
    pushd libzip-${libzip_ver} > /dev/null
    if [ -e "./configure" ]; then
      ./configure
      make -j ${THREAD} && make install
    else
      mkdir -p build && pushd build > /dev/null
      # libzip 1.10+ requires CMake 3.14+; CentOS 7 ships CMake 2.8 as cmake and 3.x as cmake3
      [ -e "/usr/bin/cmake3" ] && CMAKE=cmake3 || CMAKE=cmake
      ${CMAKE} -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_INSTALL_LIBDIR=lib -DBUILD_OSSFUZZ=OFF -DBUILD_REGRESS=OFF -DBUILD_EXAMPLES=OFF -DBUILD_DOC=OFF ..
      make -j ${THREAD} && make install
      popd > /dev/null
    fi
    popd > /dev/null
    rm -rf libzip-${libzip_ver}
  fi

  if [ ! -e "/usr/local/include/mhash.h" -a ! -e "/usr/include/mhash.h" ]; then
    tar xzf mhash-${mhash_ver}.tar.gz
    pushd mhash-${mhash_ver} > /dev/null
    /bin/cp /usr/share/misc/config.guess /usr/share/misc/config.sub . 2>/dev/null
    CFLAGS="-O2 ${compat_cflags}" ./configure
    make -j ${THREAD} && make install
    popd > /dev/null
    rm -rf mhash-${mhash_ver}
  fi

  [ -z "`grep /usr/local/lib /etc/ld.so.conf.d/*.conf`" ] && echo '/usr/local/lib' > /etc/ld.so.conf.d/local.conf
  ldconfig

  if [ "${PM}" == 'yum' ]; then
    [ ! -e "/lib64/libpcre.so.1" ] && ln -s /lib64/libpcre.so.0.0.1 /lib64/libpcre.so.1
    [ ! -e "/usr/lib/libc-client.so" ] && ln -s /usr/lib64/libc-client.so /usr/lib/libc-client.so
  fi

  id -g ${run_group} >/dev/null 2>&1
  [ $? -ne 0 ] && groupadd ${run_group}
  id -u ${run_user} >/dev/null 2>&1
  [ $? -ne 0 ] && useradd -g ${run_group} -M -s /sbin/nologin ${run_user}

  tar xzf php-${php85_ver}.tar.gz
  pushd php-${php85_ver} > /dev/null
  [ -e ext/libxml/libxml.c ] && sed -i 's/ATTRIBUTE_UNUSED/__attribute__((unused))/g' ext/libxml/libxml.c
  if [ -e ext/openssl/php_openssl.h ] && ! grep -q '^#ifndef ERR_NUM_ERRORS' ext/openssl/php_openssl.h; then
    sed -i '/struct php_openssl_errors {/i #ifndef ERR_NUM_ERRORS\n#define ERR_NUM_ERRORS 16\n#endif' ext/openssl/php_openssl.h
  fi
  # ASN1_STRING_get0_data() only exists in OpenSSL 1.1.0+; map it for OpenSSL 1.0.x (e.g. CentOS 7 system OpenSSL 1.0.2).
  # PHP 7.x openssl.c already ships its own static fallback, so only patch files that lack one.
  for f in ext/openssl/xp_ssl.c ext/openssl/openssl.c; do
    if [ -e "${f}" ] && ! grep -q 'ASN1_STRING_get0_data(const ASN1_STRING' ${f} && ! grep -q 'define ASN1_STRING_get0_data' ${f}; then
      sed -i '1i #include <openssl/opensslv.h>\n#if OPENSSL_VERSION_NUMBER < 0x10100000L && !defined(LIBRESSL_VERSION_NUMBER)\n#define ASN1_STRING_get0_data ASN1_STRING_data\n#endif' ${f}
    fi
  done
  if [ -e ext/openssl/xp_ssl.c ]; then
    sed -i 's/san->d.iPAddress->length/ASN1_STRING_length(san->d.iPAddress)/g' ext/openssl/xp_ssl.c
    sed -i 's/san->d.iPAddress->data/ASN1_STRING_get0_data(san->d.iPAddress)/g' ext/openssl/xp_ssl.c
  fi
  if [ -e ext/openssl/openssl.c ]; then
    sed -i 's/(char \*)str->data, str->length/(char *)ASN1_STRING_get0_data(str), ASN1_STRING_length(str)/g' ext/openssl/openssl.c
    sed -i 's/timestr->data/ASN1_STRING_get0_data(timestr)/g' ext/openssl/openssl.c
    sed -i 's/extension_data->data/ASN1_STRING_get0_data(extension_data)/g' ext/openssl/openssl.c
    sed -i 's/extension_data->length/ASN1_STRING_length(extension_data)/g' ext/openssl/openssl.c
  fi
  make clean
  export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig/:$PKG_CONFIG_PATH
  [ ! -d "${php_install_dir}" ] && mkdir -p ${php_install_dir}
  [ "${phpcache_option}" == '1' ] && phpcache_arg='--enable-opcache' || phpcache_arg='--disable-opcache'
  if [ "${apache_mode_option}" == '2' ]; then
    ./configure --prefix=${php_install_dir} --with-config-file-path=${php_install_dir}/etc \
    --with-config-file-scan-dir=${php_install_dir}/etc/php.d \
    --with-apxs2=${apache_install_dir}/bin/apxs ${phpcache_arg} --disable-fileinfo \
    --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd \
    --with-iconv=/usr/local --with-freetype --with-jpeg --with-zlib \
    --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-exif \
    --enable-sysvsem ${php85_with_curl} --enable-mbregex \
    --enable-mbstring --with-password-argon2 --with-sodium=/usr/local --enable-gd ${php85_with_openssl} \
    --with-mhash --enable-pcntl --enable-sockets --enable-ftp --enable-intl --with-xsl \
    --with-gettext --with-zip=/usr/local --enable-soap --disable-debug ${php_modules_options}
  else
    ./configure --prefix=${php_install_dir} --with-config-file-path=${php_install_dir}/etc \
    --with-config-file-scan-dir=${php_install_dir}/etc/php.d \
    --with-fpm-user=${run_user} --with-fpm-group=${run_group} --enable-fpm ${phpcache_arg} --disable-fileinfo \
    --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd \
    --with-iconv=/usr/local --with-freetype --with-jpeg --with-zlib \
    --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-exif \
    --enable-sysvsem ${php85_with_curl} --enable-mbregex \
    --enable-mbstring --with-password-argon2 --with-sodium=/usr/local --enable-gd ${php85_with_openssl} \
    --with-mhash --enable-pcntl --enable-sockets --enable-ftp --enable-intl --with-xsl \
    --with-gettext --with-zip=/usr/local --enable-soap --disable-debug ${php_modules_options}
  fi
  [ -f Makefile ] && sed -i 's@-Wl,-z,max-page-size=[0-9]\+@@g; s@-z,max-page-size=[0-9]\+@@g' Makefile
  make EXTRA_CFLAGS="${compat_cflags} -fPIE" EXTRA_LDFLAGS_PROGRAM="-pie" ZEND_EXTRA_LIBS='-liconv' -j ${THREAD}
  make install

  if [ -e "${php_install_dir}/bin/phpize" ]; then
    [ ! -e "${php_install_dir}/etc/php.d" ] && mkdir -p ${php_install_dir}/etc/php.d
    echo "${CSUCCESS}PHP installed successfully! ${CEND}"
  else
    rm -rf ${php_install_dir}
    echo "${CFAILURE}PHP install failed, Please Contact the author! ${CEND}"
    kill -9 $$; exit 1;
  fi

  [ -z "`grep ^'export PATH=' /etc/profile`" ] && echo "export PATH=${php_install_dir}/bin:\$PATH" >> /etc/profile
  [ -n "`grep ^'export PATH=' /etc/profile`" -a -z "`grep ${php_install_dir} /etc/profile`" ] && sed -i "s@^export PATH=\(.*\)@export PATH=${php_install_dir}/bin:\1@" /etc/profile
  . /etc/profile

  /bin/cp php.ini-production ${php_install_dir}/etc/php.ini

  sed -i "s@^memory_limit.*@memory_limit = ${Memory_limit}M@" ${php_install_dir}/etc/php.ini
  sed -i 's@^output_buffering =@output_buffering = On\noutput_buffering =@' ${php_install_dir}/etc/php.ini
  #sed -i 's@^;cgi.fix_pathinfo.*@cgi.fix_pathinfo=0@' ${php_install_dir}/etc/php.ini
  sed -i 's@^short_open_tag = Off@short_open_tag = On@' ${php_install_dir}/etc/php.ini
  sed -i 's@^expose_php = On@expose_php = Off@' ${php_install_dir}/etc/php.ini
  sed -i 's@^request_order.*@request_order = "CGP"@' ${php_install_dir}/etc/php.ini
  sed -i "s@^;date.timezone.*@date.timezone = ${timezone}@" ${php_install_dir}/etc/php.ini
  sed -i 's@^post_max_size.*@post_max_size = 100M@' ${php_install_dir}/etc/php.ini
  sed -i 's@^upload_max_filesize.*@upload_max_filesize = 50M@' ${php_install_dir}/etc/php.ini
  sed -i 's@^max_execution_time.*@max_execution_time = 600@' ${php_install_dir}/etc/php.ini
  sed -i 's@^;realpath_cache_size.*@realpath_cache_size = 2M@' ${php_install_dir}/etc/php.ini
  sed -i 's@^disable_functions.*@disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,ini_alter,ini_restore,dl,readlink,symlink,popepassthru,stream_socket_server,fsocket,popen@' ${php_install_dir}/etc/php.ini
  [ -e /usr/sbin/sendmail ] && sed -i 's@^;sendmail_path.*@sendmail_path = /usr/sbin/sendmail -t -i@' ${php_install_dir}/etc/php.ini
  if [ "${with_old_openssl_flag}" = 'y' ]; then
    sed -i "s@^;curl.cainfo.*@curl.cainfo = \"${openssl_install_dir}/cert.pem\"@" ${php_install_dir}/etc/php.ini
    sed -i "s@^;openssl.cafile.*@openssl.cafile = \"${openssl_install_dir}/cert.pem\"@" ${php_install_dir}/etc/php.ini
    sed -i "s@^;openssl.capath.*@openssl.capath = \"${openssl_install_dir}/cert.pem\"@" ${php_install_dir}/etc/php.ini
  fi

  [ "${phpcache_option}" == '1' ] && cat > ${php_install_dir}/etc/php.d/02-opcache.ini << EOF
[opcache]
opcache.enable=1
opcache.enable_cli=1
opcache.memory_consumption=${Memory_limit}
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=100000
opcache.max_wasted_percentage=5
opcache.use_cwd=1
opcache.validate_timestamps=1
opcache.revalidate_freq=60
;opcache.save_comments=0
opcache.consistency_checks=0
;opcache.optimization_level=0
EOF

  if [ "${apache_mode_option}" != '2' ]; then
    # php-fpm Init Script
    /bin/cp ${oneinstack_dir}/init.d/php-fpm.service /lib/systemd/system/
    sed -i "s@/usr/local/php@${php_install_dir}@g" /lib/systemd/system/php-fpm.service
    systemctl enable php-fpm

    cat > ${php_install_dir}/etc/php-fpm.conf <<EOF
;;;;;;;;;;;;;;;;;;;;;
; FPM Configuration ;
;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;
; Global Options ;
;;;;;;;;;;;;;;;;;;

[global]
pid = run/php-fpm.pid
error_log = log/php-fpm.log
log_level = warning

emergency_restart_threshold = 30
emergency_restart_interval = 60s
process_control_timeout = 5s
daemonize = yes

;;;;;;;;;;;;;;;;;;;;
; Pool Definitions ;
;;;;;;;;;;;;;;;;;;;;

[${run_user}]
listen = /dev/shm/php-cgi.sock
listen.backlog = -1
listen.allowed_clients = 127.0.0.1
listen.owner = ${run_user}
listen.group = ${run_group}
listen.mode = 0666
user = ${run_user}
group = ${run_group}

pm = dynamic
pm.max_children = 12
pm.start_servers = 8
pm.min_spare_servers = 6
pm.max_spare_servers = 12
pm.max_requests = 2048
pm.process_idle_timeout = 10s
request_terminate_timeout = 120
request_slowlog_timeout = 0

pm.status_path = /php-fpm_status
slowlog = var/log/slow.log
rlimit_files = 51200
rlimit_core = 0

catch_workers_output = yes
;env[HOSTNAME] = $HOSTNAME
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] = /tmp
EOF

    if [ $Mem -le 3000 ]; then
      sed -i "s@^pm.max_children.*@pm.max_children = $(($Mem/3/20))@" ${php_install_dir}/etc/php-fpm.conf
      sed -i "s@^pm.start_servers.*@pm.start_servers = $(($Mem/3/30))@" ${php_install_dir}/etc/php-fpm.conf
      sed -i "s@^pm.min_spare_servers.*@pm.min_spare_servers = $(($Mem/3/40))@" ${php_install_dir}/etc/php-fpm.conf
      sed -i "s@^pm.max_spare_servers.*@pm.max_spare_servers = $(($Mem/3/20))@" ${php_install_dir}/etc/php-fpm.conf
    elif [ $Mem -gt 3000 -a $Mem -le 4500 ]; then
      sed -i "s@^pm.max_children.*@pm.max_children = 50@" ${php_install_dir}/etc/php-fpm.conf
      sed -i "s@^pm.start_servers.*@pm.start_servers = 30@" ${php_install_dir}/etc/php-fpm.conf
      sed -i "s@^pm.min_spare_servers.*@pm.min_spare_servers = 20@" ${php_install_dir}/etc/php-fpm.conf
      sed -i "s@^pm.max_spare_servers.*@pm.max_spare_servers = 50@" ${php_install_dir}/etc/php-fpm.conf
    elif [ $Mem -gt 4500 -a $Mem -le 6500 ]; then
      sed -i "s@^pm.max_children.*@pm.max_children = 60@" ${php_install_dir}/etc/php-fpm.conf
      sed -i "s@^pm.start_servers.*@pm.start_servers = 40@" ${php_install_dir}/etc/php-fpm.conf
      sed -i "s@^pm.min_spare_servers.*@pm.min_spare_servers = 30@" ${php_install_dir}/etc/php-fpm.conf
      sed -i "s@^pm.max_spare_servers.*@pm.max_spare_servers = 60@" ${php_install_dir}/etc/php-fpm.conf
    elif [ $Mem -gt 6500 -a $Mem -le 8500 ]; then
      sed -i "s@^pm.max_children.*@pm.max_children = 70@" ${php_install_dir}/etc/php-fpm.conf
      sed -i "s@^pm.start_servers.*@pm.start_servers = 50@" ${php_install_dir}/etc/php-fpm.conf
      sed -i "s@^pm.min_spare_servers.*@pm.min_spare_servers = 40@" ${php_install_dir}/etc/php-fpm.conf
      sed -i "s@^pm.max_spare_servers.*@pm.max_spare_servers = 70@" ${php_install_dir}/etc/php-fpm.conf
    elif [ $Mem -gt 8500 ]; then
      sed -i "s@^pm.max_children.*@pm.max_children = 80@" ${php_install_dir}/etc/php-fpm.conf
      sed -i "s@^pm.start_servers.*@pm.start_servers = 60@" ${php_install_dir}/etc/php-fpm.conf
      sed -i "s@^pm.min_spare_servers.*@pm.min_spare_servers = 50@" ${php_install_dir}/etc/php-fpm.conf
      sed -i "s@^pm.max_spare_servers.*@pm.max_spare_servers = 80@" ${php_install_dir}/etc/php-fpm.conf
    fi

    systemctl start php-fpm 2>/dev/null || ${php_install_dir}/sbin/php-fpm

  elif [ "${apache_mode_option}" == '2' ]; then
    systemctl restart httpd 2>/dev/null || ${apache_install_dir}/bin/apachectl -k restart
  fi
  popd > /dev/null
  [ -e "${php_install_dir}/bin/phpize" ] && rm -rf php-${php85_ver}
  popd > /dev/null
}
