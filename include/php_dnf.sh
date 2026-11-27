#!/bin/bash
# Author:  OneinStack
# Notes: OneinStack DNF/Remi PHP package installer with automatic source fallback
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

# Map install.sh php_option (1..16) to two-digit version code (53..86)
PHP_Option_To_Code() {
  case "$1" in
    1)  echo "53" ;;
    2)  echo "54" ;;
    3)  echo "55" ;;
    4)  echo "56" ;;
    5)  echo "70" ;;
    6)  echo "71" ;;
    7)  echo "72" ;;
    8)  echo "73" ;;
    9)  echo "74" ;;
    10) echo "80" ;;
    11) echo "81" ;;
    12) echo "82" ;;
    13) echo "83" ;;
    14) echo "84" ;;
    15) echo "85" ;;
    16) echo "86" ;;
    *)  echo "" ;;
  esac
}

# Return 0 if this host + options are eligible for DNF (Remi SCL) PHP installation
PHP_DNF_Eligible() {
  local ver_code="$1"
  [ "${php_install_method:-dnf}" == "source" ] && return 1
  command -v dnf >/dev/null 2>&1 || return 1
  [ "${Family}" == "rhel" ] || return 1
  [ "${RHEL_ver:-0}" -ge 8 ] 2>/dev/null || return 1
  [ "${apache_mode_option}" == "2" ] && return 1
  [ -n "${php_modules_options}" ] && return 1
  [[ "${ver_code}" =~ ^(56|7[0-4]|8[0-6])$ ]] || return 1
  return 0
}

# Return 0 if another OneinStack PHP directory already owns the given remi_pkg
PHP_DNF_Remi_Claimed() {
  local target_pkg="$1"
  local exclude_dir="$2"
  local base_dir="${orig_php_install_dir:-${php_install_dir}}"
  # Strip trailing two-digit mphp suffix if base_dir itself is e.g. /usr/local/php86
  base_dir=$(echo "${base_dir}" | sed -E 's/[0-9]{2}$//')
  local d method_val pkg_val
  for d in "${base_dir}" "${base_dir}"53 "${base_dir}"54 "${base_dir}"55 "${base_dir}"56 \
           "${base_dir}"70 "${base_dir}"71 "${base_dir}"72 "${base_dir}"73 "${base_dir}"74 \
           "${base_dir}"80 "${base_dir}"81 "${base_dir}"82 "${base_dir}"83 "${base_dir}"84 \
           "${base_dir}"85 "${base_dir}"86; do
    [ "${d}" == "${exclude_dir}" ] && continue
    [ ! -f "${d}/.install_method" ] && continue
    method_val=$(awk -F= '/^method=/{print $2}' "${d}/.install_method" 2>/dev/null)
    pkg_val=$(awk -F= '/^remi_pkg=/{print $2}' "${d}/.install_method" 2>/dev/null)
    if [ "${method_val}" == "dnf" ] && [ "${pkg_val}" == "${target_pkg}" ]; then
      return 0
    fi
  done
  return 1
}

# Rewrite Remi repo files to a fast reachable China mirror when in China or when official CDN is unreachable
PHP_DNF_Configure_Remi_Mirror() {
  ls /etc/yum.repos.d/remi*.repo >/dev/null 2>&1 || return 0
  local need_mirror=0
  if [ "${OUTIP_STATE}"x == "China"x ]; then
    need_mirror=1
  elif ! curl --connect-timeout 3 -m 5 -sI https://rpms.remirepo.net/ >/dev/null 2>&1; then
    need_mirror=1
  fi
  [ "${need_mirror}" -ne 1 ] && return 0

  local mirror_base=""
  local candidate
  for candidate in "https://mirrors.tuna.tsinghua.edu.cn/remi" "https://mirrors.aliyun.com/remi"; do
    if curl --connect-timeout 3 -m 5 -sI "${candidate}/" 2>/dev/null | head -n1 | grep -qE '200|301|302'; then
      mirror_base="${candidate}"
      break
    fi
  done
  [ -z "${mirror_base}" ] && return 0

  sed -i -e 's@^mirrorlist=@#mirrorlist=@g' \
         -e "s@^#\\?baseurl=https\\?://rpms\\.remirepo\\.net@baseurl=${mirror_base}@g" \
         /etc/yum.repos.d/remi*.repo 2>/dev/null
}

# Build extra --enablerepo flags for DNF (remi-safe + crb/powertools if available)
PHP_DNF_Build_Repo_Args() {
  PHP_DNF_REPO_ARGS=""
  local all_repos
  all_repos=$(dnf repolist --all 2>/dev/null | awk '{print $1}')
  if echo "${all_repos}" | grep -qx "remi-safe"; then
    PHP_DNF_REPO_ARGS="${PHP_DNF_REPO_ARGS} --enablerepo=remi-safe"
  fi
  if echo "${all_repos}" | grep -qx "crb"; then
    PHP_DNF_REPO_ARGS="${PHP_DNF_REPO_ARGS} --enablerepo=crb"
  elif echo "${all_repos}" | grep -qx "powertools"; then
    PHP_DNF_REPO_ARGS="${PHP_DNF_REPO_ARGS} --enablerepo=powertools"
  elif echo "${all_repos}" | grep -qx "PowerTools"; then
    PHP_DNF_REPO_ARGS="${PHP_DNF_REPO_ARGS} --enablerepo=PowerTools"
  fi
}

# Ensure Remi repository is installed and the requested phpXX-php-fpm package is available
Ensure_Remi_Repo() {
  local ver_code="$1"
  local remi_pkg="php${ver_code}"

  PHP_DNF_Build_Repo_Args
  if rpm -q "${remi_pkg}-php-fpm" >/dev/null 2>&1 || dnf -q ${PHP_DNF_REPO_ARGS} list available "${remi_pkg}-php-fpm" >/dev/null 2>&1; then
    return 0
  fi

  echo "${CMSG}Configuring Remi repository for DNF PHP (${remi_pkg})...${CEND}"
  if [ -n "${Fedora_ver}" ]; then
    local rpm_urls
    if [ "${OUTIP_STATE}"x == "China"x ]; then
      rpm_urls="https://mirrors.tuna.tsinghua.edu.cn/remi/fedora/remi-release-${Fedora_ver}.rpm https://rpms.remirepo.net/fedora/remi-release-${Fedora_ver}.rpm"
    else
      rpm_urls="https://rpms.remirepo.net/fedora/remi-release-${Fedora_ver}.rpm https://mirrors.tuna.tsinghua.edu.cn/remi/fedora/remi-release-${Fedora_ver}.rpm"
    fi
    local url
    for url in ${rpm_urls}; do
      if dnf -y install "${url}"; then
        break
      fi
    done
  else
    rpm -q epel-release >/dev/null 2>&1 || dnf -y install epel-release || true
    local rpm_urls
    if [ "${OUTIP_STATE}"x == "China"x ]; then
      rpm_urls="https://mirrors.tuna.tsinghua.edu.cn/remi/enterprise/remi-release-${RHEL_ver}.rpm https://mirrors.aliyun.com/remi/enterprise/remi-release-${RHEL_ver}.rpm https://rpms.remirepo.net/enterprise/remi-release-${RHEL_ver}.rpm"
    else
      rpm_urls="https://rpms.remirepo.net/enterprise/remi-release-${RHEL_ver}.rpm https://mirrors.tuna.tsinghua.edu.cn/remi/enterprise/remi-release-${RHEL_ver}.rpm https://mirrors.aliyun.com/remi/enterprise/remi-release-${RHEL_ver}.rpm"
    fi
    local url
    for url in ${rpm_urls}; do
      if dnf -y install "${url}"; then
        break
      fi
    done
  fi

  PHP_DNF_Configure_Remi_Mirror
  PHP_DNF_Build_Repo_Args

  if rpm -q "${remi_pkg}-php-fpm" >/dev/null 2>&1 || dnf -q ${PHP_DNF_REPO_ARGS} list available "${remi_pkg}-php-fpm" >/dev/null 2>&1; then
    return 0
  fi
  echo "${CWARNING}Package ${remi_pkg}-php-fpm is not available in DNF repositories.${CEND}"
  return 1
}

# Roll back partial DNF PHP installation before falling back to source compilation
PHP_DNF_Rollback() {
  local remi_pkg="$1"
  local target_dir="$2"
  local had_remi_pkg="$3"

  if [ ! -e "/lib/systemd/system/php-fpm.service_bk" ]; then
    systemctl stop php-fpm >/dev/null 2>&1 || true
    systemctl disable php-fpm >/dev/null 2>&1 || true
    rm -f /lib/systemd/system/php-fpm.service
    systemctl daemon-reload >/dev/null 2>&1 || true
  else
    rm -f /lib/systemd/system/php-fpm.service
  fi
  [ -n "${target_dir}" ] && rm -rf "${target_dir}"
  if [ "${had_remi_pkg}" != "1" ]; then
    dnf -y remove "${remi_pkg}-php-*" "${remi_pkg}-runtime" >/dev/null 2>&1 || true
  fi
}

# Download PHP source tarball + common C library dependencies for a given version code (53..86)
Download_PHP_Common_Src() {
  echo "PHP common..."
  src_url=${mirror_link}/oneinstack/src/libiconv-${libiconv_ver}.tar.gz && Download_src
  src_url=${mirror_link}/oneinstack/src/curl-${curl_ver}.tar.gz && Download_src
  src_url=${mirror_link}/oneinstack/src/mhash-${mhash_ver}.tar.gz && Download_src
  src_url=${mirror_link}/oneinstack/src/libmcrypt-${libmcrypt_ver}.tar.gz && Download_src
  src_url=${mirror_link}/oneinstack/src/mcrypt-${mcrypt_ver}.tar.gz && Download_src
  src_url=${mirror_link}/oneinstack/src/freetype-${freetype_ver}.tar.gz && Download_src
}

Download_PHP_Version_Src() {
  local ver_code="$1"
  case "${ver_code}" in
    53)
      src_url=${mirror_link}/oneinstack/src/debian_patches_disable_SSLv2_for_openssl_1_0_0.patch && Download_src
      src_url=${mirror_link}/oneinstack/src/php5.3patch && Download_src
      src_url=https://www.php.net/distributions/php-${php53_ver}.tar.gz && Download_src
      src_url=${mirror_link}/oneinstack/src/fpm-race-condition.patch && Download_src
      ;;
    54)
      src_url=https://www.php.net/distributions/php-${php54_ver}.tar.gz && Download_src
      src_url=${mirror_link}/oneinstack/src/fpm-race-condition.patch && Download_src
      ;;
    55)
      src_url=https://www.php.net/distributions/php-${php55_ver}.tar.gz && Download_src
      src_url=${mirror_link}/oneinstack/src/fpm-race-condition.patch && Download_src
      ;;
    56)
      src_url=https://www.php.net/distributions/php-${php56_ver}.tar.gz && Download_src
      ;;
    70)
      src_url=https://www.php.net/distributions/php-${php70_ver}.tar.gz && Download_src
      ;;
    71)
      src_url=https://www.php.net/distributions/php-${php71_ver}.tar.gz && Download_src
      ;;
    72)
      src_url=${mirror_link}/oneinstack/src/php-${php72_ver}.tar.gz && Download_src
      src_url=${mirror_link}/oneinstack/src/argon2-${argon2_ver}.tar.gz && Download_src
      src_url=${mirror_link}/oneinstack/src/libsodium-${libsodium_ver}.tar.gz && Download_src
      ;;
    73)
      src_url=${mirror_link}/oneinstack/src/php-${php73_ver}.tar.gz && Download_src
      src_url=${mirror_link}/oneinstack/src/php-7.3-CVE-2026-1119.patch && Download_src
      src_url=${mirror_link}/oneinstack/src/argon2-${argon2_ver}.tar.gz && Download_src
      src_url=${mirror_link}/oneinstack/src/libsodium-${libsodium_ver}.tar.gz && Download_src
      ;;
    74)
      src_url=${mirror_link}/oneinstack/src/php-${php74_ver}.tar.gz && Download_src
      src_url=${mirror_link}/oneinstack/src/php-7.4-CVE-2026-109618-109619.patch && Download_src
      src_url=${mirror_link}/oneinstack/src/php-7.4-CVE-2026-1119.patch && Download_src
      src_url=${mirror_link}/oneinstack/src/argon2-${argon2_ver}.tar.gz && Download_src
      src_url=${mirror_link}/oneinstack/src/libsodium-${libsodium_ver}.tar.gz && Download_src
      src_url=${mirror_link}/oneinstack/src/libzip-${libzip_ver}.tar.gz && Download_src
      ;;
    80)
      src_url=${mirror_link}/oneinstack/src/php-${php80_ver}.tar.gz && Download_src
      src_url=${mirror_link}/oneinstack/src/argon2-${argon2_ver}.tar.gz && Download_src
      src_url=${mirror_link}/oneinstack/src/libsodium-${libsodium_ver}.tar.gz && Download_src
      src_url=${mirror_link}/oneinstack/src/libzip-${libzip_ver}.tar.gz && Download_src
      ;;
    81)
      src_url=${mirror_link}/oneinstack/src/php-${php81_ver}.tar.gz && Download_src
      src_url=${mirror_link}/oneinstack/src/php-8.1-CVE-2026-109618-109619.patch && Download_src
      src_url=${mirror_link}/oneinstack/src/argon2-${argon2_ver}.tar.gz && Download_src
      src_url=${mirror_link}/oneinstack/src/libsodium-${libsodium_ver}.tar.gz && Download_src
      src_url=${mirror_link}/oneinstack/src/libzip-${libzip_ver}.tar.gz && Download_src
      ;;
    82)
      src_url=${mirror_link}/oneinstack/src/php-${php82_ver}.tar.gz && Download_src
      src_url=${mirror_link}/oneinstack/src/argon2-${argon2_ver}.tar.gz && Download_src
      src_url=${mirror_link}/oneinstack/src/libsodium-${libsodium_up_ver}.tar.gz && Download_src
      src_url=${mirror_link}/oneinstack/src/libzip-${libzip_ver}.tar.gz && Download_src
      ;;
    83)
      src_url=${mirror_link}/oneinstack/src/php-${php83_ver}.tar.gz && Download_src
      src_url=${mirror_link}/oneinstack/src/argon2-${argon2_ver}.tar.gz && Download_src
      src_url=${mirror_link}/oneinstack/src/libsodium-${libsodium_up_ver}.tar.gz && Download_src
      src_url=${mirror_link}/oneinstack/src/libzip-${libzip_ver}.tar.gz && Download_src
      ;;
    84)
      src_url=${mirror_link}/oneinstack/src/php-${php84_ver}.tar.gz && Download_src
      src_url=${mirror_link}/oneinstack/src/argon2-${argon2_ver}.tar.gz && Download_src
      src_url=${mirror_link}/oneinstack/src/libsodium-${libsodium_up_ver}.tar.gz && Download_src
      src_url=${mirror_link}/oneinstack/src/libzip-${libzip_ver}.tar.gz && Download_src
      ;;
    85)
      src_url=${mirror_link}/oneinstack/src/php-${php85_ver}.tar.gz && Download_src
      src_url=${mirror_link}/oneinstack/src/argon2-${argon2_ver}.tar.gz && Download_src
      src_url=${mirror_link}/oneinstack/src/libsodium-${libsodium_up_ver}.tar.gz && Download_src
      src_url=${mirror_link}/oneinstack/src/libzip-${libzip_ver}.tar.gz && Download_src
      ;;
    86)
      src_url=${mirror_link}/oneinstack/src/php-${php86_ver}.tar.gz && Download_src
      src_url=${mirror_link}/oneinstack/src/argon2-${argon2_ver}.tar.gz && Download_src
      src_url=${mirror_link}/oneinstack/src/libsodium-${libsodium_up_ver}.tar.gz && Download_src
      src_url=${mirror_link}/oneinstack/src/libzip-${libzip_ver}.tar.gz && Download_src
      ;;
  esac
}

Download_PHP_Source_Deps() {
  local ver_code="$1"
  [ ! -d "${oneinstack_dir}/src" ] && mkdir -p "${oneinstack_dir}/src"
  pushd "${oneinstack_dir}/src" > /dev/null
  Download_PHP_Common_Src
  Download_PHP_Version_Src "${ver_code}"
  popd > /dev/null
}

# Install PHP via DNF (Remi SCL) and bridge into ${php_install_dir} for full OneinStack compatibility
Install_PHP_DNF() {
  local ver_code="$1"
  PHP_DNF_Eligible "${ver_code}" || return 1

  local remi_pkg="php${ver_code}"
  if PHP_DNF_Remi_Claimed "${remi_pkg}" "${php_install_dir}"; then
    echo "${CWARNING}${remi_pkg} is already managed via DNF by another OneinStack PHP installation; using source build for ${php_install_dir}.${CEND}"
    return 1
  fi

  local had_remi_pkg=0
  rpm -q "${remi_pkg}-php-fpm" >/dev/null 2>&1 && had_remi_pkg=1

  # Ensure run_user / run_group exist
  id -g ${run_group} >/dev/null 2>&1
  [ $? -ne 0 ] && groupadd ${run_group}
  id -u ${run_user} >/dev/null 2>&1
  [ $? -ne 0 ] && useradd -g ${run_group} -M -s /sbin/nologin ${run_user}

  if ! Ensure_Remi_Repo "${ver_code}"; then
    return 1
  fi

  local core_pkgs="${remi_pkg}-php-fpm ${remi_pkg}-php-common ${remi_pkg}-php-cli ${remi_pkg}-php-devel ${remi_pkg}-php-mysqlnd ${remi_pkg}-php-pdo ${remi_pkg}-php-mbstring ${remi_pkg}-php-xml ${remi_pkg}-php-gd"
  local opt_pkgs="${remi_pkg}-php-bcmath ${remi_pkg}-php-intl ${remi_pkg}-php-soap ${remi_pkg}-php-process ${remi_pkg}-php-sodium ${remi_pkg}-php-pecl-zip ${remi_pkg}-php-opcache ${remi_pkg}-php-json ${remi_pkg}-php-xsl ${remi_pkg}-php-gmp"

  echo "${CMSG}Installing PHP (${remi_pkg}) via DNF package manager...${CEND}"
  if ! dnf -y ${PHP_DNF_REPO_ARGS} install ${core_pkgs}; then
    echo "${CWARNING}Failed to install core DNF packages for ${remi_pkg}.${CEND}"
    PHP_DNF_Rollback "${remi_pkg}" "${php_install_dir}" "${had_remi_pkg}"
    return 1
  fi

  # Best-effort install optional parity extensions (e.g., json is built-in on 8.0+, opcache on 8.5+)
  dnf -y ${PHP_DNF_REPO_ARGS} --setopt=strict=0 --skip-broken install ${opt_pkgs} || true

  local remi_root="/opt/remi/${remi_pkg}/root"
  local remi_etc="/etc/opt/remi/${remi_pkg}"

  if [ ! -x "${remi_root}/usr/bin/php" ] || [ ! -x "${remi_root}/usr/bin/phpize" ] || \
     [ ! -x "${remi_root}/usr/bin/php-config" ] || [ ! -x "${remi_root}/usr/sbin/php-fpm" ] || \
     [ ! -f "${remi_etc}/php.ini" ] || [ ! -d "${remi_etc}/php.d" ]; then
    echo "${CWARNING}Remi DNF layout verification failed for ${remi_pkg}.${CEND}"
    PHP_DNF_Rollback "${remi_pkg}" "${php_install_dir}" "${had_remi_pkg}"
    return 1
  fi

  # Disable Remi's default phpXX-php-fpm service to avoid port/socket conflict with OneinStack's php-fpm service
  systemctl stop "${remi_pkg}-php-fpm" >/dev/null 2>&1 || true
  systemctl disable "${remi_pkg}-php-fpm" >/dev/null 2>&1 || true

  # Build OneinStack compatibility bridge under ${php_install_dir}
  mkdir -p "${php_install_dir}/bin" "${php_install_dir}/sbin" "${php_install_dir}/etc" \
           "${php_install_dir}/var/run" "${php_install_dir}/var/log"

  local bin_item
  for bin_item in "${remi_root}/usr/bin/"*; do
    [ -e "${bin_item}" ] && ln -sfn "${bin_item}" "${php_install_dir}/bin/$(basename "${bin_item}")"
  done
  ln -sfn "${remi_root}/usr/sbin/php-fpm" "${php_install_dir}/sbin/php-fpm"
  ln -sfn "${remi_etc}/php.ini" "${php_install_dir}/etc/php.ini"
  rm -rf "${php_install_dir}/etc/php.d"
  ln -sfn "${remi_etc}/php.d" "${php_install_dir}/etc/php.d"

  # Tune ${remi_etc}/php.ini directly (never sed -i the symlink) to match OneinStack defaults
  [ ! -f "${remi_etc}/php.ini.remi.orig" ] && /bin/cp "${remi_etc}/php.ini" "${remi_etc}/php.ini.remi.orig"
  sed -i "s@^memory_limit.*@memory_limit = ${Memory_limit:-128}M@" "${remi_etc}/php.ini"
  sed -i 's@^output_buffering =.*@output_buffering = On@' "${remi_etc}/php.ini"
  sed -i 's@^short_open_tag = Off@short_open_tag = On@' "${remi_etc}/php.ini"
  sed -i 's@^expose_php = On@expose_php = Off@' "${remi_etc}/php.ini"
  sed -i 's@^request_order.*@request_order = "CGP"@' "${remi_etc}/php.ini"
  sed -i "s@^;\\?date\\.timezone.*@date.timezone = ${timezone:-Asia/Shanghai}@" "${remi_etc}/php.ini"
  sed -i 's@^post_max_size.*@post_max_size = 100M@' "${remi_etc}/php.ini"
  sed -i 's@^upload_max_filesize.*@upload_max_filesize = 50M@' "${remi_etc}/php.ini"
  sed -i 's@^max_execution_time.*@max_execution_time = 600@' "${remi_etc}/php.ini"
  sed -i 's@^;\\?realpath_cache_size.*@realpath_cache_size = 2M@' "${remi_etc}/php.ini"
  sed -i 's@^disable_functions.*@disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,ini_alter,ini_restore,dl,readlink,symlink,popepassthru,stream_socket_server,fsocket,popen@' "${remi_etc}/php.ini"
  [ -e /usr/sbin/sendmail ] && sed -i 's@^;\\?sendmail_path.*@sendmail_path = /usr/sbin/sendmail -t -i@' "${remi_etc}/php.ini"

  # Prevent Remi's default 10-opcache.ini from colliding with OneinStack's 02-opcache.ini
  if [ -f "${remi_etc}/php.d/10-opcache.ini" ]; then
    /bin/mv "${remi_etc}/php.d/10-opcache.ini" "${remi_etc}/php.d/10-opcache.ini.remi.bak"
  fi
  if [ "${phpcache_option}" == '1' ]; then
    local php_ext_dir php_detail_ver php_main_ver
    php_ext_dir=$("${php_install_dir}/bin/php-config" --extension-dir 2>/dev/null)
    php_detail_ver=$("${php_install_dir}/bin/php-config" --version 2>/dev/null)
    php_main_ver="${php_detail_ver%.*}"
    if [[ "${php_main_ver}" =~ ^8\.[5-9]$ ]]; then
      cat > "${php_install_dir}/etc/php.d/02-opcache.ini" << EOF
[opcache]
opcache.enable=1
opcache.enable_cli=1
opcache.memory_consumption=${Memory_limit:-128}
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
    elif [ -f "${php_ext_dir}/opcache.so" ]; then
      cat > "${php_install_dir}/etc/php.d/02-opcache.ini" << EOF
[opcache]
zend_extension=opcache.so
opcache.enable=1
opcache.enable_cli=1
opcache.memory_consumption=${Memory_limit:-128}
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=100000
opcache.max_wasted_percentage=5
opcache.use_cwd=1
opcache.validate_timestamps=1
opcache.revalidate_freq=60
;opcache.save_comments=0
opcache.fast_shutdown=1
opcache.consistency_checks=0
;opcache.optimization_level=0
EOF
    fi
  fi

  # Generate OneinStack php-fpm.conf using ABSOLUTE paths (Remi php-fpm defaults relative paths to /var/opt/remi/phpXX)
  cat > "${php_install_dir}/etc/php-fpm.conf" << EOF
;;;;;;;;;;;;;;;;;;;;;
; FPM Configuration ;
;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;
; Global Options ;
;;;;;;;;;;;;;;;;;;

[global]
pid = ${php_install_dir}/var/run/php-fpm.pid
error_log = ${php_install_dir}/var/log/php-fpm.log
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
slowlog = ${php_install_dir}/var/log/slow.log
rlimit_files = 51200
rlimit_core = 0

catch_workers_output = yes
;env[HOSTNAME] = \$HOSTNAME
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] = /tmp
EOF

  local mem_mb=${Mem:-1024}
  if [ ${mem_mb} -le 3000 ]; then
    local pm_max=$((mem_mb/3/20)); [ ${pm_max} -lt 2 ] && pm_max=2
    local pm_start=$((mem_mb/3/30)); [ ${pm_start} -lt 1 ] && pm_start=1
    local pm_min=$((mem_mb/3/40)); [ ${pm_min} -lt 1 ] && pm_min=1
    [ ${pm_start} -lt ${pm_min} ] && pm_start=${pm_min}
    [ ${pm_start} -gt ${pm_max} ] && pm_start=${pm_max}
    sed -i "s@^pm.max_children.*@pm.max_children = ${pm_max}@" "${php_install_dir}/etc/php-fpm.conf"
    sed -i "s@^pm.start_servers.*@pm.start_servers = ${pm_start}@" "${php_install_dir}/etc/php-fpm.conf"
    sed -i "s@^pm.min_spare_servers.*@pm.min_spare_servers = ${pm_min}@" "${php_install_dir}/etc/php-fpm.conf"
    sed -i "s@^pm.max_spare_servers.*@pm.max_spare_servers = ${pm_max}@" "${php_install_dir}/etc/php-fpm.conf"
  elif [ ${mem_mb} -gt 3000 -a ${mem_mb} -le 4500 ]; then
    sed -i "s@^pm.max_children.*@pm.max_children = 50@" "${php_install_dir}/etc/php-fpm.conf"
    sed -i "s@^pm.start_servers.*@pm.start_servers = 30@" "${php_install_dir}/etc/php-fpm.conf"
    sed -i "s@^pm.min_spare_servers.*@pm.min_spare_servers = 20@" "${php_install_dir}/etc/php-fpm.conf"
    sed -i "s@^pm.max_spare_servers.*@pm.max_spare_servers = 50@" "${php_install_dir}/etc/php-fpm.conf"
  elif [ ${mem_mb} -gt 4500 -a ${mem_mb} -le 6500 ]; then
    sed -i "s@^pm.max_children.*@pm.max_children = 60@" "${php_install_dir}/etc/php-fpm.conf"
    sed -i "s@^pm.start_servers.*@pm.start_servers = 40@" "${php_install_dir}/etc/php-fpm.conf"
    sed -i "s@^pm.min_spare_servers.*@pm.min_spare_servers = 30@" "${php_install_dir}/etc/php-fpm.conf"
    sed -i "s@^pm.max_spare_servers.*@pm.max_spare_servers = 60@" "${php_install_dir}/etc/php-fpm.conf"
  elif [ ${mem_mb} -gt 6500 -a ${mem_mb} -le 8500 ]; then
    sed -i "s@^pm.max_children.*@pm.max_children = 70@" "${php_install_dir}/etc/php-fpm.conf"
    sed -i "s@^pm.start_servers.*@pm.start_servers = 50@" "${php_install_dir}/etc/php-fpm.conf"
    sed -i "s@^pm.min_spare_servers.*@pm.min_spare_servers = 40@" "${php_install_dir}/etc/php-fpm.conf"
    sed -i "s@^pm.max_spare_servers.*@pm.max_spare_servers = 70@" "${php_install_dir}/etc/php-fpm.conf"
  elif [ ${mem_mb} -gt 8500 ]; then
    sed -i "s@^pm.max_children.*@pm.max_children = 80@" "${php_install_dir}/etc/php-fpm.conf"
    sed -i "s@^pm.start_servers.*@pm.start_servers = 60@" "${php_install_dir}/etc/php-fpm.conf"
    sed -i "s@^pm.min_spare_servers.*@pm.min_spare_servers = 50@" "${php_install_dir}/etc/php-fpm.conf"
    sed -i "s@^pm.max_spare_servers.*@pm.max_spare_servers = 80@" "${php_install_dir}/etc/php-fpm.conf"
  fi

  # Validate FPM config syntax before registering service
  if ! "${php_install_dir}/sbin/php-fpm" -t --fpm-config "${php_install_dir}/etc/php-fpm.conf" >/dev/null 2>&1; then
    echo "${CWARNING}DNF PHP-FPM configuration test failed for ${remi_pkg}.${CEND}"
    PHP_DNF_Rollback "${remi_pkg}" "${php_install_dir}" "${had_remi_pkg}"
    return 1
  fi

  # Install OneinStack systemd unit
  /bin/cp "${oneinstack_dir}/init.d/php-fpm.service" /lib/systemd/system/php-fpm.service
  sed -i "s@/usr/local/php@${php_install_dir}@g" /lib/systemd/system/php-fpm.service

  # Start service immediately only for primary PHP (for mphp, include/mphp.sh rewrites socket & service name first)
  if [ ! -e "/lib/systemd/system/php-fpm.service_bk" ]; then
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable php-fpm >/dev/null 2>&1 || true
    systemctl start php-fpm 2>/dev/null || "${php_install_dir}/sbin/php-fpm" --fpm-config "${php_install_dir}/etc/php-fpm.conf"
    if ! systemctl is-active --quiet php-fpm 2>/dev/null && [ ! -s "${php_install_dir}/var/run/php-fpm.pid" ]; then
      echo "${CWARNING}Failed to start DNF PHP-FPM service for ${remi_pkg}.${CEND}"
      PHP_DNF_Rollback "${remi_pkg}" "${php_install_dir}" "${had_remi_pkg}"
      return 1
    fi
  fi

  # Update /etc/profile PATH (consistent with source PHP installers)
  [ -z "`grep ^'export PATH=' /etc/profile`" ] && echo "export PATH=${php_install_dir}/bin:\$PATH" >> /etc/profile
  [ -n "`grep ^'export PATH=' /etc/profile`" -a -z "`grep ${php_install_dir} /etc/profile`" ] && sed -i "s@^export PATH=\(.*\)@export PATH=${php_install_dir}/bin:\1@" /etc/profile
  . /etc/profile

  # Record installation metadata for upgrade_php.sh, pecl_*.sh, and uninstall.sh
  cat > "${php_install_dir}/.install_method" << EOF
method=dnf
remi_pkg=${remi_pkg}
EOF

  echo "${CSUCCESS}PHP (${remi_pkg}) installed successfully via DNF! ${CEND}"
  return 0
}

# Try DNF PHP installation first when eligible; on any failure, download source deps and compile from source
Install_PHP_With_Fallback() {
  local ver_code="$1"
  local source_script="$2"
  local source_func="$3"

  if PHP_DNF_Eligible "${ver_code}"; then
    if Install_PHP_DNF "${ver_code}"; then
      return 0
    fi
    echo "${CWARNING}DNF installation for PHP ${ver_code} failed, falling back to source compilation...${CEND}"
    Download_PHP_Source_Deps "${ver_code}"
  fi

  . "${source_script}"
  "${source_func}"
}
