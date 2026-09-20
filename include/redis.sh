#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

# Redis module versions (defaults if not set in versions.txt)
: ${redisbloom_ver:=2.8.2}
: ${redistimeseries_ver:=1.14.1}

Install_redis_server() {
  pushd ${oneinstack_dir}/src > /dev/null
  tar xzf redis-${redis_ver}.tar.gz
  pushd redis-${redis_ver} > /dev/null
  make -j ${THREAD}
  if [ -f "src/redis-server" ]; then
    mkdir -p ${redis_install_dir}/{bin,etc,var,modules}
    /bin/cp src/{redis-benchmark,redis-check-aof,redis-check-rdb,redis-cli,redis-sentinel,redis-server} ${redis_install_dir}/bin/
    /bin/cp redis.conf ${redis_install_dir}/etc/
    ln -s ${redis_install_dir}/bin/* /usr/local/bin/
    sed -i 's@pidfile.*@pidfile /var/run/redis/redis.pid@' ${redis_install_dir}/etc/redis.conf
    sed -i "s@logfile.*@logfile ${redis_install_dir}/var/redis.log@" ${redis_install_dir}/etc/redis.conf
    sed -i "s@^dir.*@dir ${redis_install_dir}/var@" ${redis_install_dir}/etc/redis.conf
    sed -i 's@daemonize no@daemonize yes@' ${redis_install_dir}/etc/redis.conf
    sed -i "s@^# bind 127.0.0.1@bind 127.0.0.1@" ${redis_install_dir}/etc/redis.conf
    redis_maxmemory=`expr $Mem / 8`000000
    [ -z "`grep ^maxmemory ${redis_install_dir}/etc/redis.conf`" ] && sed -i "s@maxmemory <bytes>@maxmemory <bytes>\nmaxmemory `expr $Mem / 8`000000@" ${redis_install_dir}/etc/redis.conf
    # Disable any unbuilt loadmodule to prevent startup crash (IB-003 fix)
    sed -i 's@^loadmodule @#loadmodule @g' ${redis_install_dir}/etc/redis.conf
    echo "${CSUCCESS}Redis-server installed successfully! ${CEND}"
    popd > /dev/null
    rm -rf redis-${redis_ver}
    id -u redis >/dev/null 2>&1
    [ $? -ne 0 ] && useradd -M -s /sbin/nologin redis
    chown -R redis:redis ${redis_install_dir}/{var,etc}

    /bin/cp ../init.d/redis-server.service /lib/systemd/system/
    sed -i "s@/usr/local/redis@${redis_install_dir}@g" /lib/systemd/system/redis-server.service
    systemctl daemon-reload
    systemctl enable redis-server
    #[ -z "`grep 'vm.overcommit_memory' /etc/sysctl.conf`" ] && echo 'vm.overcommit_memory = 1' >> /etc/sysctl.conf
    #sysctl -p
    systemctl restart redis-server || systemctl start redis-server
    local redis_started=0
    for ((i=1; i<=5; i++)); do
      if ${redis_install_dir}/bin/redis-cli ping 2>/dev/null | grep -q 'PONG'; then
        redis_started=1
        break
      fi
      sleep 1
    done
    if [ ${redis_started} -eq 0 ]; then
      echo "${CFAILURE}Redis-server start failed! redis-cli ping did not return PONG. ${CEND}"
      systemctl status redis-server --no-pager
      kill -9 $$; exit 1;
    fi
  else
    rm -rf ${redis_install_dir}
    echo "${CFAILURE}Redis-server install failed, Please contact the author! ${CEND}" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
    kill -9 $$; exit 1;
  fi
  popd > /dev/null
}

Install_redis_modules() {
  [ ! -e "${redis_install_dir}/bin/redis-server" ] && { echo "${CWARNING}Redis is not installed, skipping modules! ${CEND}"; return 1; }
  
  local modules_dir="${redis_install_dir}/modules"
  mkdir -p ${modules_dir}
  
  pushd ${oneinstack_dir}/src > /dev/null
  
  # Install RedisBloom (does not require Rust)
  if [ -n "${redisbloom_ver}" ]; then
    echo "Building RedisBloom ${redisbloom_ver}..."
    local bloom_tarball="RedisBloom-${redisbloom_ver}.tar.gz"
    if [ ! -f "${bloom_tarball}" ]; then
      wget --tries=3 -c "https://github.com/RedisBloom/RedisBloom/archive/refs/tags/v${redisbloom_ver}.tar.gz" -O "${bloom_tarball}" 2>/dev/null || \
      wget --tries=3 -c "${mirror_link}/oneinstack/src/${bloom_tarball}" -O "${bloom_tarball}" 2>/dev/null
    fi
    if [ -f "${bloom_tarball}" ]; then
      rm -rf RedisBloom-${redisbloom_ver}
      tar xzf "${bloom_tarball}"
      if [ -d "RedisBloom-${redisbloom_ver}" ]; then
        pushd RedisBloom-${redisbloom_ver} > /dev/null
        make -j ${THREAD} 2>&1 | tail -20
        if [ -f "redisbloom.so" ]; then
          /bin/cp redisbloom.so ${modules_dir}/
          chown redis:redis ${modules_dir}/redisbloom.so
          echo "loadmodule ${modules_dir}/redisbloom.so" >> ${redis_install_dir}/etc/redis.conf
          echo "${CSUCCESS}RedisBloom module installed successfully! ${CEND}"
        else
          echo "${CWARNING}RedisBloom build failed, module not installed. ${CEND}"
        fi
        popd > /dev/null
        rm -rf RedisBloom-${redisbloom_ver}
      fi
    else
      echo "${CWARNING}Failed to download RedisBloom, skipping. ${CEND}"
    fi
  fi
  
  # Install RedisTimeSeries (does not require Rust)
  if [ -n "${redistimeseries_ver}" ]; then
    echo "Building RedisTimeSeries ${redistimeseries_ver}..."
    local ts_tarball="RedisTimeSeries-${redistimeseries_ver}.tar.gz"
    if [ ! -f "${ts_tarball}" ]; then
      wget --tries=3 -c "https://github.com/RedisTimeSeries/RedisTimeSeries/archive/refs/tags/v${redistimeseries_ver}.tar.gz" -O "${ts_tarball}" 2>/dev/null || \
      wget --tries=3 -c "${mirror_link}/oneinstack/src/${ts_tarball}" -O "${ts_tarball}" 2>/dev/null
    fi
    if [ -f "${ts_tarball}" ]; then
      rm -rf RedisTimeSeries-${redistimeseries_ver}
      tar xzf "${ts_tarball}"
      if [ -d "RedisTimeSeries-${redistimeseries_ver}" ]; then
        pushd RedisTimeSeries-${redistimeseries_ver} > /dev/null
        make -j ${THREAD} 2>&1 | tail -20
        local ts_so=$(find . -name "redistimeseries.so" -type f 2>/dev/null | head -1)
        if [ -n "${ts_so}" ] && [ -f "${ts_so}" ]; then
          /bin/cp "${ts_so}" ${modules_dir}/
          chown redis:redis ${modules_dir}/redistimeseries.so
          echo "loadmodule ${modules_dir}/redistimeseries.so" >> ${redis_install_dir}/etc/redis.conf
          echo "${CSUCCESS}RedisTimeSeries module installed successfully! ${CEND}"
        else
          echo "${CWARNING}RedisTimeSeries build failed, module not installed. ${CEND}"
        fi
        popd > /dev/null
        rm -rf RedisTimeSeries-${redistimeseries_ver}
      fi
    else
      echo "${CWARNING}Failed to download RedisTimeSeries, skipping. ${CEND}"
    fi
  fi
  
  # RediSearch and RedisJSON require Rust toolchain
  # Skip with warning if cargo/rustc not available
  if ! command -v cargo >/dev/null 2>&1 || ! command -v rustc >/dev/null 2>&1; then
    echo "${CWARNING}RediSearch and RedisJSON require cargo/rustc which are not installed. ${CEND}"
    echo "${CWARNING}To install these modules, first install Rust: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh ${CEND}"
    echo "${CWARNING}Skipping RediSearch and RedisJSON modules. ${CEND}"
  else
    echo "${CWARNING}RediSearch and RedisJSON also require cmake>=3.25 and additional build dependencies. ${CEND}"
    echo "${CWARNING}These modules are complex to build; consider using Redis Stack instead. ${CEND}"
  fi
  
  # Ensure modules directory is owned by redis
  chown -R redis:redis ${modules_dir}
  
  # Reload Redis if modules were installed and it's running
  if [ -n "$(ls -A ${modules_dir} 2>/dev/null)" ]; then
    echo "Redis modules installed to ${modules_dir}"
    if systemctl is-active --quiet redis-server; then
      echo "Restarting Redis to load modules..."
      systemctl restart redis-server
      sleep 2
      if ${redis_install_dir}/bin/redis-cli ping 2>/dev/null | grep -q 'PONG'; then
        echo "${CSUCCESS}Redis restarted successfully with modules! ${CEND}"
      else
        echo "${CWARNING}Redis may have failed to start with modules. Check logs: ${redis_install_dir}/var/redis.log ${CEND}"
        # Disable modules and restart to recover
        sed -i 's@^loadmodule @#loadmodule @g' ${redis_install_dir}/etc/redis.conf
        systemctl restart redis-server
        echo "${CWARNING}Modules disabled to recover Redis. Check module compatibility. ${CEND}"
      fi
    fi
  else
    echo "${CWARNING}No Redis modules were successfully built. ${CEND}"
  fi
  
  popd > /dev/null
}

Install_pecl_redis() {
  if [ -e "${php_install_dir}/bin/phpize" ]; then
    pushd ${oneinstack_dir}/src > /dev/null
    phpExtensionDir=`${php_install_dir}/bin/php-config --extension-dir`
    if [ "$(${php_install_dir}/bin/php-config --version | awk -F. '{print $1}')" == '5' ]; then
      tar xzf redis-4.3.0.tgz
      pushd redis-4.3.0 > /dev/null
    elif [[ "$(${php_install_dir}/bin/php-config --version | awk -F. '{print $1$2}')" =~ ^7[0-1]$ ]]; then
      tar xzf redis-5.3.7.tgz
      pushd redis-5.3.7 > /dev/null
    else
      tar xzf redis-${pecl_redis_ver}.tgz
      pushd redis-${pecl_redis_ver} > /dev/null
    fi
    ${php_install_dir}/bin/phpize
    ./configure --with-php-config=${php_install_dir}/bin/php-config
    make -j ${THREAD} && make install
    popd > /dev/null
    if [ -f "${phpExtensionDir}/redis.so" ]; then
      echo 'extension=redis.so' > ${php_install_dir}/etc/php.d/05-redis.ini
      echo "${CSUCCESS}PHP Redis module installed successfully! ${CEND}"
      rm -rf redis-${pecl_redis_ver} redis-4.3.0 redis-5.3.7
    else
      echo "${CFAILURE}PHP Redis module install failed, Please contact the author! ${CEND}" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
    fi
    popd > /dev/null
  fi
}

Uninstall_pecl_redis() {
  if [ -e "${php_install_dir}/etc/php.d/05-redis.ini" ]; then
    rm -f ${php_install_dir}/etc/php.d/05-redis.ini
    echo; echo "${CMSG}PHP redis module uninstall completed${CEND}"
  else
    echo; echo "${CWARNING}PHP redis module does not exist! ${CEND}"
  fi
}
