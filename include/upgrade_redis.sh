#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Valid_Redis_Version() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

Latest_Redis_Version() {
  local release_index latest_version

  release_index=$(curl --connect-timeout 5 --max-time 15 -fsSL https://download.redis.io/releases/) || return 1
  latest_version=$(printf '%s\n' "${release_index}" |
    grep -oE 'redis-[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz' |
    sed -E 's/^redis-//; s/\.tar\.gz$//' |
    sort -V |
    tail -1)
  Valid_Redis_Version "${latest_version}" || return 1
  printf '%s\n' "${latest_version}"
}

Upgrade_Redis() {
  pushd "${oneinstack_dir}/src" > /dev/null || return 1
  if [ ! -d "${redis_install_dir}" ]; then
    echo "${CWARNING}Redis is not installed on your system! ${CEND}"
    popd > /dev/null
    return 1
  fi

  OLD_redis_ver=$("${redis_install_dir}/bin/redis-cli" --version | awk '{print $2}')
  Latest_redis_ver=$(Latest_Redis_Version)
  Latest_redis_ver=${Latest_redis_ver:-${redis_ver}}
  echo "Current Redis Version: ${CMSG}${OLD_redis_ver}${CEND}"
  while :; do echo
    [ "${redis_flag}" != 'y' ] && read -e -p "Please input upgrade Redis Version(default: ${Latest_redis_ver}): " NEW_redis_ver
    NEW_redis_ver=${NEW_redis_ver:-${Latest_redis_ver}}

    if ! Valid_Redis_Version "${NEW_redis_ver}"; then
      echo "${CWARNING}Redis version must use the full x.y.z format, for example 8.8.0.${CEND}"
      [ "${redis_flag}" == 'y' ] && { popd > /dev/null; return 1; }
      continue
    fi
    if [ "${NEW_redis_ver}" == "${OLD_redis_ver}" ]; then
      echo "${CWARNING}input error! Upgrade Redis version is the same as the old version${CEND}"
      popd > /dev/null
      return 1
    fi

    # Always pass through Download_src so an existing archive is validated too.
    src_url=https://download.redis.io/releases/redis-${NEW_redis_ver}.tar.gz
    Download_src no_kill
    if [ -e "redis-${NEW_redis_ver}.tar.gz" ]; then
      echo "Download [${CMSG}redis-${NEW_redis_ver}.tar.gz${CEND}] successfully! "
      break
    else
      echo "${CWARNING}Redis ${NEW_redis_ver} source archive is unavailable or failed validation.${CEND}"
      [ "${redis_flag}" == 'y' ] && { popd > /dev/null; return 1; }
    fi
  done

  if [ -e "redis-${NEW_redis_ver}.tar.gz" ]; then
    echo "[${CMSG}redis-${NEW_redis_ver}.tar.gz${CEND}] found"
    if [ "${redis_flag}" != 'y' ]; then
      echo "Press Ctrl+c to cancel or Press any key to continue..."
      char=$(get_char)
    fi
    tar xzf "redis-${NEW_redis_ver}.tar.gz" || { popd > /dev/null; return 1; }
    pushd "redis-${NEW_redis_ver}" > /dev/null || { popd > /dev/null; return 1; }
    make clean
    make -j ${THREAD}

    if [ -f "src/redis-server" ]; then
      echo "Restarting Redis..."
      service redis-server stop
      /bin/cp src/{redis-benchmark,redis-check-aof,redis-check-rdb,redis-cli,redis-sentinel,redis-server} $redis_install_dir/bin/
      service redis-server start
      popd > /dev/null
      echo "You have ${CMSG}successfully${CEND} upgrade from ${CWARNING}${OLD_redis_ver}${CEND} to ${CWARNING}${NEW_redis_ver}${CEND}"
      rm -rf "redis-${NEW_redis_ver}"
    else
      echo "${CFAILURE}Upgrade Redis failed! ${CEND}"
      popd > /dev/null
      popd > /dev/null
      return 1
    fi
  fi
  popd > /dev/null
}
