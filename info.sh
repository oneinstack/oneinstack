#!/bin/bash

oneinstack_dir=$(cd "$(dirname "$0")" && pwd -P)
version_file="${oneinstack_dir}/include/oneinstack_version.sh"
options_file="${oneinstack_dir}/options.conf"

if [ -f "$version_file" ]; then
  # This file is maintained with the project and is also sourced by install.sh.
  . "$version_file"
else
  ONEINSTACK_VERSION=unknown
  ONEINSTACK_UPDATED_DATE=unknown
fi

config_value() {
  local wanted="$1" fallback="$2" line
  if [ -f "$options_file" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
        "${wanted}"=*) printf '%s' "${line#*=}"; return 0 ;;
      esac
    done < "$options_file"
  fi
  printf '%s' "$fallback"
}

usage() {
  cat <<EOF
Usage: $0 [OPTION]
  --version      Show OneinStack version
  --host         Show host system information
  --oneinstack   Show OneinStack and installed component information
  --all          Show host and OneinStack information
  --help         Show this help
EOF
}

show_version() {
  printf 'version: %s\nupdated date: %s\n' "$ONEINSTACK_VERSION" "$ONEINSTACK_UPDATED_DATE"
}

show_host() {
  local hostname os_name kernel arch cpu_model cpu_vendor cpu_count ips mem_total mem_available
  hostname=$(hostname 2>/dev/null || printf 'unknown')
  os_name=$(sed -n 's/^PRETTY_NAME="\(.*\)"$/\1/p' /etc/os-release 2>/dev/null | head -n1)
  [ -n "$os_name" ] || os_name=$(uname -s)
  kernel=$(uname -r 2>/dev/null || printf 'unknown')
  arch=$(uname -m 2>/dev/null || printf 'unknown')
  cpu_model=$(awk -F: '/^(model name|Hardware)[[:space:]]*:/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}' /proc/cpuinfo 2>/dev/null)
  if [ -z "$cpu_model" ] || [ "$cpu_model" = '-' ]; then
    cpu_vendor=$(lscpu 2>/dev/null | sed -n 's/^Vendor ID:[[:space:]]*//p' | head -n1)
    if [ -n "$cpu_vendor" ]; then
      cpu_model="${cpu_vendor} CPU (model unavailable)"
    else
      cpu_model=unknown
    fi
  fi
  cpu_count=$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf 'unknown')
  if command -v ip >/dev/null 2>&1; then
    ips=$(ip -o addr show scope global 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i == "inet" || $i == "inet6") {print $2 ": " $(i+1); break}}')
  else
    ips=$(hostname -I 2>/dev/null | tr ' ' '\n' | sed '/^$/d')
  fi
  mem_total=$(awk '/^MemTotal:/ {printf "%.1f GiB", $2 / 1048576}' /proc/meminfo 2>/dev/null)
  mem_available=$(awk '/^MemAvailable:/ {printf "%.1f GiB", $2 / 1048576}' /proc/meminfo 2>/dev/null)

  printf 'Host information\n'
  printf '  Hostname: %s\n' "$hostname"
  printf '  OS: %s\n' "$os_name"
  printf '  Kernel: %s\n' "$kernel"
  printf '  Architecture: %s\n' "$arch"
  printf '  CPU: %s (%s online cores)\n' "$cpu_model" "$cpu_count"
  printf '  Memory: %s total, %s available\n' "${mem_total:-unknown}" "${mem_available:-unknown}"
  printf '  Local interface IPs:\n'
  if [ -n "$ips" ]; then
    while IFS= read -r line; do printf '    %s\n' "$line"; done <<< "$ips"
  else
    printf '    none detected\n'
  fi
  printf '  Filesystems:\n'
  df -hP / "$oneinstack_dir" 2>/dev/null | awk 'NR == 1 {print "    " $0; next} {print "    " $0}'
}

print_binary_version() {
  local label="$1" binary="$2"
  shift 2
  [ -x "$binary" ] || return 0
  local result
  result=$("$binary" "$@" 2>&1 | head -n 1 | tr -d '\r')
  [ -n "$result" ] || result='version could not be read'
  printf '  %s: %s\n' "$label" "$result"
}

show_oneinstack() {
  local mirror md5 path found=0 candidate
  mirror=$(config_value mirror_link '')
  md5=$(config_value oneinstack_md5 '')
  # Never display URL user information or query parameters from custom mirrors.
  mirror=$(printf '%s' "$mirror" | sed -E 's#(https?://)[^/@]+@#\1#; s/[?].*$//')

  printf 'OneinStack information\n'
  printf '  Version: %s (updated %s)\n' "$ONEINSTACK_VERSION" "$ONEINSTACK_UPDATED_DATE"
  printf '  Installation directory: %s\n' "$oneinstack_dir"
  printf '  Configured mirror: %s\n' "${mirror:-not set}"
  printf '  Package MD5: %s\n' "${md5:-not recorded}"
  printf '  Detected components:\n'

  path=$(config_value nginx_install_dir /usr/local/nginx)
  print_binary_version 'Nginx/Tengine/OpenResty' "${path}/sbin/nginx" -v
  [ -x "${path}/sbin/nginx" ] && found=1

  path=$(config_value tengine_install_dir /usr/local/tengine)
  if [ -x "${path}/sbin/nginx" ]; then
    print_binary_version 'Tengine' "${path}/sbin/nginx" -v; found=1
  fi
  path=$(config_value openresty_install_dir /usr/local/openresty)
  if [ -x "${path}/nginx/sbin/nginx" ]; then
    print_binary_version 'OpenResty' "${path}/nginx/sbin/nginx" -v; found=1
  fi

  path=$(config_value apache_install_dir /usr/local/apache)
  if [ -x "${path}/bin/httpd" ]; then
    print_binary_version 'Apache' "${path}/bin/httpd" -v; found=1
  elif [ -x "${path}/bin/apachectl" ]; then
    print_binary_version 'Apache' "${path}/bin/apachectl" -v; found=1
  fi
  path=$(config_value tomcat_install_dir /usr/local/tomcat)
  if [ -x "${path}/bin/version.sh" ]; then
    print_binary_version 'Tomcat' "${path}/bin/version.sh"; found=1
  fi

  path=$(config_value caddy_install_dir /usr/local/caddy)
  if [ -x "${path}/bin/caddy" ]; then
    print_binary_version 'Caddy' "${path}/bin/caddy" version; found=1
  elif [ -x "${path}/caddy" ]; then
    print_binary_version 'Caddy' "${path}/caddy" version; found=1
  fi

  for path in \
    "$(config_value mysql_install_dir /usr/local/mysql)" \
    "$(config_value mariadb_install_dir /usr/local/mariadb)" \
    "$(config_value percona_install_dir /usr/local/percona)"; do
    if [ -x "${path}/bin/mysql" ]; then
      print_binary_version 'MySQL/MariaDB/Percona' "${path}/bin/mysql" --version; found=1; break
    fi
  done
  path=$(config_value pgsql_install_dir /usr/local/pgsql)
  if [ -x "${path}/bin/psql" ]; then
    print_binary_version 'PostgreSQL' "${path}/bin/psql" --version; found=1
  fi
  path=$(config_value mongo_install_dir /usr/local/mongodb)
  if [ -x "${path}/bin/mongod" ]; then
    print_binary_version 'MongoDB' "${path}/bin/mongod" --version; found=1
  elif [ -x "${path}/bin/mongosh" ]; then
    print_binary_version 'MongoDB Shell' "${path}/bin/mongosh" --version; found=1
  fi
  path=$(config_value clickhouse_install_dir /usr/local/clickhouse)
  if [ -x "${path}/bin/clickhouse" ]; then
    print_binary_version 'ClickHouse' "${path}/bin/clickhouse" --version; found=1
  elif [ -x "${path}/bin/clickhouse-client" ]; then
    print_binary_version 'ClickHouse' "${path}/bin/clickhouse-client" --version; found=1
  fi

  path=$(config_value php_install_dir /usr/local/php)
  for candidate in "$path" "$path"[0-9]*; do
    if [ -x "${candidate}/bin/php" ]; then
      print_binary_version "PHP (${candidate##*/})" "${candidate}/bin/php" -v; found=1
    fi
  done
  path=$(config_value nodejs_install_dir /usr/local/node)
  if [ -x "${path}/bin/node" ]; then
    print_binary_version 'Node.js' "${path}/bin/node" --version; found=1
  fi
  path=$(config_value redis_install_dir /usr/local/redis)
  if [ -x "${path}/bin/redis-server" ]; then
    print_binary_version 'Redis' "${path}/bin/redis-server" --version; found=1
  fi
  path=$(config_value valkey_install_dir /usr/local/valkey)
  if [ -x "${path}/bin/valkey-server" ]; then
    print_binary_version 'Valkey' "${path}/bin/valkey-server" --version; found=1
  fi
  path=$(config_value memcached_install_dir /usr/local/memcached)
  if [ -x "${path}/bin/memcached" ]; then
    print_binary_version 'Memcached' "${path}/bin/memcached" -h; found=1
  fi
  path=$(config_value pureftpd_install_dir /usr/local/pureftpd)
  if [ -x "${path}/sbin/pure-ftpd" ]; then
    print_binary_version 'Pure-FTPd' "${path}/sbin/pure-ftpd" -v; found=1
  elif [ -x "${path}/bin/pure-ftpd" ]; then
    print_binary_version 'Pure-FTPd' "${path}/bin/pure-ftpd" -v; found=1
  fi
  path=$(config_value openssl_install_dir /usr/local/openssl)
  if [ -x "${path}/bin/openssl" ]; then
    print_binary_version 'OpenSSL' "${path}/bin/openssl" version; found=1
  fi
  path=$(config_value curl_install_dir /usr/local/curl)
  if [ -x "${path}/bin/curl" ]; then
    print_binary_version 'curl' "${path}/bin/curl" --version; found=1
  fi
  path=$(config_value wwwroot_dir /data/wwwroot)
  for candidate in \
    "${path}/default/phpMyAdmin" "${path}/default/phpmyadmin" \
    "${path}/phpMyAdmin" "${path}/phpmyadmin"; do
    version_file="${candidate}/libraries/classes/Version.php"
    if [ -f "$version_file" ]; then
      local pma_version
      pma_version=$(sed -nE "s/.*VERSION[[:space:]]*=[[:space:]]*'([^']+)'.*/\\1/p" "$version_file" | head -n1)
      if [ -n "$pma_version" ]; then
        printf '  phpMyAdmin: %s\n' "$pma_version"
        found=1
        break
      fi
    fi
  done
  [ "$found" -eq 1 ] || printf '    no supported component binaries detected\n'
}

case "${1:---help}" in
  --version) show_version ;;
  --host) show_host ;;
  --oneinstack) show_oneinstack ;;
  --all) show_host; printf '\n'; show_oneinstack ;;
  --help|-h) usage ;;
  *) usage >&2; exit 2 ;;
esac
