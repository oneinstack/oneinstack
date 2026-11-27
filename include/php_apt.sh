#!/bin/bash
# Author:  OneinStack
# Notes: OneinStack APT (Sury/Ondrej) PHP package installer with automatic source fallback
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

# Convert two-digit PHP version code (e.g. 86) to dotted version (e.g. 8.6)
PHP_Code_To_Dot() {
  local ver_code="$1"
  if [[ "${ver_code}" =~ ^[0-9]{2}$ ]]; then
    echo "${ver_code:0:1}.${ver_code:1:1}"
  else
    echo ""
  fi
}

# Return 0 only when the given Debian/Ubuntu package is actively installed (ignores 'rc' config-only state)
PHP_APT_Pkg_Installed() {
  local pkg="$1"
  command -v dpkg-query >/dev/null 2>&1 || return 1
  local status
  status=$(dpkg-query -W -f='${Status}\n' "${pkg}" 2>/dev/null)
  [ "${status}" == "install ok installed" ]
}

# Return 0 if target APT PHP packages are already installed on the system (isolation-first guard)
PHP_APT_Preexisting_Detected() {
  local ver_code="$1"
  local apt_ver
  apt_ver=$(PHP_Code_To_Dot "${ver_code}")
  [ -z "${apt_ver}" ] && return 1
  local apt_pkg="php${apt_ver}"
  local pkg
  for pkg in "${apt_pkg}-fpm" "${apt_pkg}-cli" "${apt_pkg}-common"; do
    PHP_APT_Pkg_Installed "${pkg}" && return 0
  done
  return 1
}

# Return 0 if this host + options are eligible for APT PHP installation
PHP_APT_Eligible() {
  local ver_code="$1"
  local method="${php_install_method:-auto}"
  [ "${method}" == "source" ] && return 1
  [ "${method}" == "dnf" ] && return 1
  command -v apt-get >/dev/null 2>&1 || return 1
  [[ "${Family}" =~ ^(debian|ubuntu)$ ]] || return 1
  [ "${apache_mode_option}" == "2" ] && return 1
  [ -n "${php_modules_options}" ] && return 1
  [[ "${ver_code}" =~ ^(56|7[0-4]|8[0-6])$ ]] || return 1
  PHP_APT_Preexisting_Detected "${ver_code}" && return 1
  return 0
}

# Return 0 if another OneinStack PHP directory already owns the given apt_pkg (e.g. php8.6)
PHP_APT_Pkg_Claimed() {
  local target_pkg="$1"
  local exclude_dir="$2"
  local base_dir="${orig_php_install_dir:-${php_install_dir}}"
  base_dir=$(echo "${base_dir}" | sed -E 's/[0-9]{2}$//')
  local d method_val pkg_val
  for d in "${base_dir}" "${base_dir}"53 "${base_dir}"54 "${base_dir}"55 "${base_dir}"56 \
           "${base_dir}"70 "${base_dir}"71 "${base_dir}"72 "${base_dir}"73 "${base_dir}"74 \
           "${base_dir}"80 "${base_dir}"81 "${base_dir}"82 "${base_dir}"83 "${base_dir}"84 \
           "${base_dir}"85 "${base_dir}"86; do
    [ "${d}" == "${exclude_dir}" ] && continue
    [ ! -f "${d}/.install_method" ] && continue
    method_val=$(awk -F= '/^method=/{print $2}' "${d}/.install_method" 2>/dev/null)
    pkg_val=$(awk -F= '/^apt_pkg=/{print $2}' "${d}/.install_method" 2>/dev/null)
    if [ "${method_val}" == "apt" ] && [ "${pkg_val}" == "${target_pkg}" ]; then
      return 0
    fi
  done
  return 1
}

# Detect Debian/Ubuntu upstream codename for Sury / Ondrej repositories
PHP_APT_Get_Codename() {
  local codename=""
  if [ -r /etc/os-release ]; then
    if [ "${Family}" == "ubuntu" ]; then
      codename=$(. /etc/os-release 2>/dev/null && echo "${UBUNTU_CODENAME:-${VERSION_CODENAME}}")
    else
      codename=$(. /etc/os-release 2>/dev/null && echo "${VERSION_CODENAME}")
    fi
  fi
  if [ -z "${codename}" ] && command -v lsb_release >/dev/null 2>&1; then
    codename=$(lsb_release -sc 2>/dev/null)
  fi
  echo "${codename}"
}

# Ensure Sury/Ondrej APT repository is configured and phpX.Y-fpm is available
Ensure_PHP_APT_Repo() {
  local ver_code="$1"
  local apt_ver
  apt_ver=$(PHP_Code_To_Dot "${ver_code}")
  local apt_pkg="php${apt_ver}"

  if PHP_APT_Pkg_Installed "${apt_pkg}-fpm" || apt-cache show "${apt_pkg}-fpm" >/dev/null 2>&1; then
    return 0
  fi

  local codename deb_arch
  codename=$(PHP_APT_Get_Codename)
  deb_arch=$(dpkg --print-architecture 2>/dev/null || echo "amd64")
  if [ -z "${codename}" ]; then
    echo "${CWARNING}Unable to determine OS codename for APT PHP repository.${CEND}"
    return 1
  fi

  echo "${CMSG}Configuring APT PHP repository for ${apt_pkg} (${codename}/${deb_arch})...${CEND}"
  DEBIAN_FRONTEND=noninteractive apt-get -y update >/dev/null 2>&1 || true
  DEBIAN_FRONTEND=noninteractive apt-get --no-install-recommends -y install ca-certificates curl gnupg lsb-release apt-transport-https >/dev/null 2>&1 || true

  local had_list=0
  [ -f /etc/apt/sources.list.d/oneinstack-php.list ] && had_list=1

  # 1. Try unified Sury PHP repository (Debian & modern Ubuntu) with China mirror probe
  local sury_candidates
  if [ "${OUTIP_STATE}"x == "China"x ]; then
    sury_candidates="https://mirror.nju.edu.cn/sury/php https://packages.sury.org/php"
  else
    sury_candidates="https://packages.sury.org/php https://mirror.nju.edu.cn/sury/php"
  fi

  local base_url key_ok
  for base_url in ${sury_candidates}; do
    if curl --connect-timeout 4 -m 8 -fsI "${base_url}/dists/${codename}/Release" >/dev/null 2>&1; then
      mkdir -p /usr/share/keyrings
      key_ok=0
      if curl --connect-timeout 5 -m 15 -fsSL "${base_url}/apt.gpg" -o /usr/share/keyrings/deb.sury.org-php.gpg 2>/dev/null && [ -s /usr/share/keyrings/deb.sury.org-php.gpg ]; then
        key_ok=1
      elif curl --connect-timeout 5 -m 15 -fsSL "https://packages.sury.org/php/apt.gpg" -o /usr/share/keyrings/deb.sury.org-php.gpg 2>/dev/null && [ -s /usr/share/keyrings/deb.sury.org-php.gpg ]; then
        key_ok=1
      fi
      if [ "${key_ok}" -eq 1 ]; then
        chmod 644 /usr/share/keyrings/deb.sury.org-php.gpg
        echo "deb [arch=${deb_arch} signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] ${base_url}/ ${codename} main" > /etc/apt/sources.list.d/oneinstack-php.list
        if DEBIAN_FRONTEND=noninteractive apt-get -y update; then
          if apt-cache show "${apt_pkg}-fpm" >/dev/null 2>&1; then
            return 0
          fi
        fi
      fi
    fi
  done

  # 2. Ubuntu fallback: ppa:ondrej/php (or USTC Launchpad proxy in China)
  if [ "${Family}" == "ubuntu" ]; then
    local ppa_added=0
    if [ "${OUTIP_STATE}"x == "China"x ] && curl --connect-timeout 4 -m 8 -fsI "https://launchpad.proxy.ustclug.org/ondrej/php/ubuntu/dists/${codename}/Release" >/dev/null 2>&1; then
      mkdir -p /usr/share/keyrings
      if curl --connect-timeout 5 -m 15 -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x14aa40ec0831756756d7f66c4f4ea0aae5267a6c" 2>/dev/null | gpg --dearmor --yes -o /usr/share/keyrings/ondrej-php.gpg 2>/dev/null && [ -s /usr/share/keyrings/ondrej-php.gpg ]; then
        chmod 644 /usr/share/keyrings/ondrej-php.gpg
        echo "deb [arch=${deb_arch} signed-by=/usr/share/keyrings/ondrej-php.gpg] https://launchpad.proxy.ustclug.org/ondrej/php/ubuntu ${codename} main" > /etc/apt/sources.list.d/oneinstack-php.list
        DEBIAN_FRONTEND=noninteractive apt-get -y update && ppa_added=1
      fi
    fi
    if [ "${ppa_added}" -eq 0 ] && command -v add-apt-repository >/dev/null 2>&1; then
      if LC_ALL=C.UTF-8 DEBIAN_FRONTEND=noninteractive add-apt-repository -y ppa:ondrej/php; then
        DEBIAN_FRONTEND=noninteractive apt-get -y update || true
      fi
    fi
    if apt-cache show "${apt_pkg}-fpm" >/dev/null 2>&1; then
      return 0
    fi
  fi

  [ "${had_list}" -eq 0 ] && rm -f /etc/apt/sources.list.d/oneinstack-php.list
  echo "${CWARNING}Package ${apt_pkg}-fpm is not available in APT repositories.${CEND}"
  return 1
}

# Roll back partial APT PHP installation before falling back to source compilation
PHP_APT_Rollback() {
  local apt_pkg="$1"
  local target_dir="$2"
  local had_apt_pkg="$3"

  if [ ! -e "/lib/systemd/system/php-fpm.service_bk" ]; then
    systemctl stop php-fpm >/dev/null 2>&1 || true
    systemctl disable php-fpm >/dev/null 2>&1 || true
    rm -f /lib/systemd/system/php-fpm.service
    if [ -e "/lib/systemd/system/php-fpm.service.sys.orig" ]; then
      /bin/mv /lib/systemd/system/php-fpm.service.sys.orig /lib/systemd/system/php-fpm.service
    fi
    systemctl daemon-reload >/dev/null 2>&1 || true
  else
    rm -f /lib/systemd/system/php-fpm.service
  fi
  [ -n "${target_dir}" ] && rm -rf "${target_dir}"
  if [ "${had_apt_pkg}" != "1" ]; then
    local installed_pkgs
    installed_pkgs=$(dpkg-query -W -f='${Package}\n' "${apt_pkg}" "${apt_pkg}-*" 2>/dev/null | tr '\n' ' ')
    if [ -n "${installed_pkgs}" ]; then
      DEBIAN_FRONTEND=noninteractive apt-get -y purge ${installed_pkgs} >/dev/null 2>&1 || true
      DEBIAN_FRONTEND=noninteractive apt-get -y autoremove >/dev/null 2>&1 || true
    fi
  fi
}

# Install PHP via APT (Sury/Ondrej) and bridge into ${php_install_dir} for full OneinStack compatibility
Install_PHP_APT() {
  local ver_code="$1"
  local apt_ver
  apt_ver=$(PHP_Code_To_Dot "${ver_code}")
  local apt_pkg="php${apt_ver}"

  if PHP_APT_Preexisting_Detected "${ver_code}"; then
    echo "${CWARNING}Pre-existing APT package (${apt_pkg}) detected; using isolated source build for ${php_install_dir} to keep existing PHP untouched.${CEND}"
    return 1
  fi
  PHP_APT_Eligible "${ver_code}" || return 1

  if PHP_APT_Pkg_Claimed "${apt_pkg}" "${php_install_dir}"; then
    echo "${CWARNING}${apt_pkg} is already managed via APT by another OneinStack PHP installation; using source build for ${php_install_dir}.${CEND}"
    return 1
  fi

  local had_apt_pkg=0

  # Ensure run_user / run_group exist
  id -g ${run_group} >/dev/null 2>&1
  [ $? -ne 0 ] && groupadd ${run_group}
  id -u ${run_user} >/dev/null 2>&1
  [ $? -ne 0 ] && useradd -g ${run_group} -M -s /sbin/nologin ${run_user}

  if ! Ensure_PHP_APT_Repo "${ver_code}"; then
    return 1
  fi

  local core_pkgs="${apt_pkg}-fpm ${apt_pkg}-cli ${apt_pkg}-common ${apt_pkg}-dev ${apt_pkg}-mysql ${apt_pkg}-mbstring ${apt_pkg}-xml ${apt_pkg}-gd ${apt_pkg}-curl"
  local opt_candidates="${apt_pkg}-bcmath ${apt_pkg}-intl ${apt_pkg}-soap ${apt_pkg}-zip ${apt_pkg}-bz2 ${apt_pkg}-opcache ${apt_pkg}-readline ${apt_pkg}-gmp ${apt_pkg}-xsl ${apt_pkg}-json"

  echo "${CMSG}Installing PHP (${apt_pkg}) via APT package manager...${CEND}"
  if ! DEBIAN_FRONTEND=noninteractive apt-get --no-install-recommends -y install ${core_pkgs}; then
    echo "${CWARNING}Failed to install core APT packages for ${apt_pkg}.${CEND}"
    PHP_APT_Rollback "${apt_pkg}" "${php_install_dir}" "${had_apt_pkg}"
    return 1
  fi

  # Best-effort install optional parity extensions that exist for this PHP version
  local opt_avail="" opt_pkg
  for opt_pkg in ${opt_candidates}; do
    apt-cache show "${opt_pkg}" >/dev/null 2>&1 && opt_avail="${opt_avail} ${opt_pkg}"
  done
  if [ -n "${opt_avail}" ]; then
    DEBIAN_FRONTEND=noninteractive apt-get --no-install-recommends -y install ${opt_avail} || true
  fi

  local apt_fpm_etc="/etc/php/${apt_ver}/fpm"
  local apt_cli_etc="/etc/php/${apt_ver}/cli"

  if [ ! -x "/usr/bin/php${apt_ver}" ] || [ ! -x "/usr/bin/phpize${apt_ver}" ] || \
     [ ! -x "/usr/bin/php-config${apt_ver}" ] || [ ! -x "/usr/sbin/php-fpm${apt_ver}" ] || \
     [ ! -f "${apt_fpm_etc}/php.ini" ] || [ ! -d "${apt_fpm_etc}/conf.d" ] || [ ! -d "${apt_cli_etc}/conf.d" ]; then
    echo "${CWARNING}APT PHP layout verification failed for ${apt_pkg}.${CEND}"
    PHP_APT_Rollback "${apt_pkg}" "${php_install_dir}" "${had_apt_pkg}"
    return 1
  fi

  # Disable Debian/Ubuntu stock phpX.Y-fpm service to avoid conflict with OneinStack's php-fpm service
  systemctl stop "${apt_pkg}-fpm" >/dev/null 2>&1 || true
  systemctl disable "${apt_pkg}-fpm" >/dev/null 2>&1 || true
  if [ -x "/etc/init.d/${apt_pkg}-fpm" ]; then
    service "${apt_pkg}-fpm" stop >/dev/null 2>&1 || true
    update-rc.d "${apt_pkg}-fpm" disable >/dev/null 2>&1 || true
  fi

  # Build OneinStack compatibility bridge under ${php_install_dir}
  # Note: Debian splits cli/conf.d and fpm/conf.d; using PHP_INI_SCAN_DIR wrappers lets both
  # CLI and FPM scan their native conf.d plus OneinStack's ${php_install_dir}/etc/php.d seamlessly.
  mkdir -p "${php_install_dir}/bin" "${php_install_dir}/sbin" "${php_install_dir}/etc/php.d" \
           "${php_install_dir}/var/run" "${php_install_dir}/var/log"

  ln -sfn "/usr/bin/phpize${apt_ver}" "${php_install_dir}/bin/phpize"
  ln -sfn "/usr/bin/php-config${apt_ver}" "${php_install_dir}/bin/php-config"
  [ -x "/usr/bin/php-cgi${apt_ver}" ] && ln -sfn "/usr/bin/php-cgi${apt_ver}" "${php_install_dir}/bin/php-cgi"
  [ -x "/usr/bin/phar${apt_ver}" ] && ln -sfn "/usr/bin/phar${apt_ver}" "${php_install_dir}/bin/phar"
  [ -x "/usr/bin/phar.phar${apt_ver}" ] && ln -sfn "/usr/bin/phar.phar${apt_ver}" "${php_install_dir}/bin/phar.phar"
  [ -x "/usr/bin/phpdbg${apt_ver}" ] && ln -sfn "/usr/bin/phpdbg${apt_ver}" "${php_install_dir}/bin/phpdbg"

  cat > "${php_install_dir}/bin/php" << EOF
#!/bin/bash
export PHP_INI_SCAN_DIR="\${PHP_INI_SCAN_DIR:-${apt_cli_etc}/conf.d:${php_install_dir}/etc/php.d}"
exec /usr/bin/php${apt_ver} "\$@"
EOF
  chmod 755 "${php_install_dir}/bin/php"

  cat > "${php_install_dir}/sbin/php-fpm" << EOF
#!/bin/bash
export PHP_INI_SCAN_DIR="\${PHP_INI_SCAN_DIR:-${apt_fpm_etc}/conf.d:${php_install_dir}/etc/php.d}"
exec /usr/sbin/php-fpm${apt_ver} "\$@"
EOF
  chmod 755 "${php_install_dir}/sbin/php-fpm"

  ln -sfn "${apt_fpm_etc}/php.ini" "${php_install_dir}/etc/php.ini"

  # Tune ${apt_fpm_etc}/php.ini directly (never sed -i the symlink) to match OneinStack defaults
  [ ! -f "${apt_fpm_etc}/php.ini.apt.orig" ] && /bin/cp "${apt_fpm_etc}/php.ini" "${apt_fpm_etc}/php.ini.apt.orig"
  sed -i "s@^memory_limit.*@memory_limit = ${Memory_limit:-128}M@" "${apt_fpm_etc}/php.ini"
  sed -i 's@^output_buffering =.*@output_buffering = On@' "${apt_fpm_etc}/php.ini"
  sed -i 's@^short_open_tag = Off@short_open_tag = On@' "${apt_fpm_etc}/php.ini"
  sed -i 's@^expose_php = On@expose_php = Off@' "${apt_fpm_etc}/php.ini"
  sed -i 's@^request_order.*@request_order = "CGP"@' "${apt_fpm_etc}/php.ini"
  sed -i "s@^;\\?date\\.timezone.*@date.timezone = ${timezone:-Asia/Shanghai}@" "${apt_fpm_etc}/php.ini"
  sed -i 's@^post_max_size.*@post_max_size = 100M@' "${apt_fpm_etc}/php.ini"
  sed -i 's@^upload_max_filesize.*@upload_max_filesize = 50M@' "${apt_fpm_etc}/php.ini"
  sed -i 's@^max_execution_time.*@max_execution_time = 600@' "${apt_fpm_etc}/php.ini"
  sed -i 's@^;\\?realpath_cache_size.*@realpath_cache_size = 2M@' "${apt_fpm_etc}/php.ini"
  sed -i 's@^disable_functions.*@disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,ini_alter,ini_restore,dl,readlink,symlink,popepassthru,stream_socket_server,fsocket,popen@' "${apt_fpm_etc}/php.ini"
  [ -e /usr/sbin/sendmail ] && sed -i 's@^;\\?sendmail_path.*@sendmail_path = /usr/sbin/sendmail -t -i@' "${apt_fpm_etc}/php.ini"

  # Sync timezone & basic runtime flags to CLI php.ini (keeping CLI memory_limit/disable_functions friendly for Composer)
  if [ -f "${apt_cli_etc}/php.ini" ]; then
    [ ! -f "${apt_cli_etc}/php.ini.apt.orig" ] && /bin/cp "${apt_cli_etc}/php.ini" "${apt_cli_etc}/php.ini.apt.orig"
    sed -i 's@^short_open_tag = Off@short_open_tag = On@' "${apt_cli_etc}/php.ini"
    sed -i 's@^expose_php = On@expose_php = Off@' "${apt_cli_etc}/php.ini"
    sed -i "s@^;\\?date\\.timezone.*@date.timezone = ${timezone:-Asia/Shanghai}@" "${apt_cli_etc}/php.ini"
    sed -i 's@^;\\?realpath_cache_size.*@realpath_cache_size = 2M@' "${apt_cli_etc}/php.ini"
    [ -e /usr/sbin/sendmail ] && sed -i 's@^;\\?sendmail_path.*@sendmail_path = /usr/sbin/sendmail -t -i@' "${apt_cli_etc}/php.ini"
  fi

  # Prevent Debian's default 10-opcache.ini from colliding with OneinStack's 02-opcache.ini
  command -v phpdismod >/dev/null 2>&1 && phpdismod -v "${apt_ver}" opcache >/dev/null 2>&1 || true
  rm -f "${apt_fpm_etc}/conf.d/"*opcache.ini "${apt_cli_etc}/conf.d/"*opcache.ini 2>/dev/null || true

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

  # Generate OneinStack php-fpm.conf using ABSOLUTE paths
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
    echo "${CWARNING}APT PHP-FPM configuration test failed for ${apt_pkg}.${CEND}"
    PHP_APT_Rollback "${apt_pkg}" "${php_install_dir}" "${had_apt_pkg}"
    return 1
  fi

  # Preserve any pre-existing non-OneinStack system php-fpm.service
  if [ ! -e "/lib/systemd/system/php-fpm.service_bk" ] && [ -f "/lib/systemd/system/php-fpm.service" ]; then
    if ! grep -q "${php_install_dir}/sbin/php-fpm" /lib/systemd/system/php-fpm.service 2>/dev/null; then
      echo "${CWARNING}Detected existing system php-fpm.service; backing up to /lib/systemd/system/php-fpm.service.sys.orig.${CEND}"
      systemctl stop php-fpm >/dev/null 2>&1 || true
      [ ! -e "/lib/systemd/system/php-fpm.service.sys.orig" ] && /bin/cp /lib/systemd/system/php-fpm.service /lib/systemd/system/php-fpm.service.sys.orig
    fi
  fi

  # Install OneinStack systemd unit
  /bin/cp "${oneinstack_dir}/init.d/php-fpm.service" /lib/systemd/system/php-fpm.service
  sed -i "s@/usr/local/php@${php_install_dir}@g" /lib/systemd/system/php-fpm.service

  # Start/restart service immediately only for primary PHP (for mphp, include/mphp.sh rewrites socket & service name first)
  if [ ! -e "/lib/systemd/system/php-fpm.service_bk" ]; then
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable php-fpm >/dev/null 2>&1 || true
    systemctl restart php-fpm 2>/dev/null || "${php_install_dir}/sbin/php-fpm" --fpm-config "${php_install_dir}/etc/php-fpm.conf"
    if ! systemctl is-active --quiet php-fpm 2>/dev/null && [ ! -s "${php_install_dir}/var/run/php-fpm.pid" ]; then
      echo "${CWARNING}Failed to start APT PHP-FPM service for ${apt_pkg}.${CEND}"
      PHP_APT_Rollback "${apt_pkg}" "${php_install_dir}" "${had_apt_pkg}"
      return 1
    fi
  fi

  # Update /etc/profile PATH (consistent with source & DNF PHP installers)
  [ -z "`grep ^'export PATH=' /etc/profile`" ] && echo "export PATH=${php_install_dir}/bin:\$PATH" >> /etc/profile
  [ -n "`grep ^'export PATH=' /etc/profile`" -a -z "`grep ${php_install_dir} /etc/profile`" ] && sed -i "s@^export PATH=\(.*\)@export PATH=${php_install_dir}/bin:\1@" /etc/profile
  . /etc/profile

  # Record installation metadata for upgrade_php.sh, pecl_*.sh, and uninstall.sh
  cat > "${php_install_dir}/.install_method" << EOF
method=apt
apt_pkg=${apt_pkg}
apt_ver=${apt_ver}
EOF

  echo "${CSUCCESS}PHP (${apt_pkg}) installed successfully via APT! ${CEND}"
  return 0
}
