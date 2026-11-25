#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

export PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
oneinstack_dir=$(dirname "$(readlink -f "$0")")
clear 2>/dev/null || true
if [ "$(id -u)" != "0" ]; then
  echo "Error: You must be root to run this script" >&2
  exit 1
fi
umask 077
upgrade_log="${oneinstack_dir}/upgrade.log"
touch "${upgrade_log}" || { echo "Unable to create upgrade log: ${upgrade_log}" >&2; exit 1; }
chmod 600 "${upgrade_log}" || { echo "Unable to secure upgrade log: ${upgrade_log}" >&2; exit 1; }
exec > >(tee -a "${upgrade_log}") 2>&1
printf "\n===== upgrade.sh started at %s =====\n" "$(date '+%F %T %z')"
printf "Upgrade output is being logged to %s\n" "${upgrade_log}"
upgrade_log_finish() {
  local status=$?
  trap - EXIT
  printf "===== upgrade.sh finished at %s (exit status: %s) =====\n" "$(date '+%F %T %z')" "${status}"
  exit "${status}"
}
trap upgrade_log_finish EXIT

printf "
#######################################################################
#       OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+      #
#              Upgrade Software versions for OneinStack               #
#       For more information please visit https://oneinstack.com      #
#######################################################################
"
pushd ${oneinstack_dir} > /dev/null
. ./versions.txt
. ./options.conf
. ./include/color.sh
. ./include/check_os.sh
. ./include/check_dir.sh
. ./include/download.sh
. ./include/get_char.sh
. ./include/upgrade_web.sh
. ./include/upgrade_db.sh
. ./include/upgrade_postgresql.sh
. ./include/upgrade_postgresql_major.sh
. ./include/upgrade_php.sh
. ./include/upgrade_redis.sh
. ./include/upgrade_valkey.sh
. ./include/upgrade_memcached.sh
. ./include/upgrade_phpmyadmin.sh
. ./include/upgrade_nodejs.sh
. ./include/upgrade_oneinstack.sh

# get the out ip country
OUTIP_STATE=$(./include/ois.${ARCH} ip_state)

Show_Help() {
  echo
  echo "Usage: $0  command ...[version]....
  --help, -h                  Show this help message
  --nginx        [version]    Upgrade Nginx
  --tengine      [version]    Upgrade Tengine
  --openresty    [version]    Upgrade OpenResty
  --apache       [version]    Upgrade Apache
  --tomcat       [version]    Upgrade Tomcat
  --db           [version]    Upgrade MySQL/MariaDB/Percona
  --postgresql   [version]    Upgrade PostgreSQL (minor or major version)
  --php          [version]    Upgrade PHP
  --redis        [version]    Upgrade Redis
  --valkey       [version]    Upgrade Valkey
  --memcached    [version]    Upgrade Memcached
  --phpmyadmin   [version]    Upgrade phpMyAdmin
  --nodejs       [version]    Upgrade Nodejs
  --oneinstack                Upgrade OneinStack latest
  --acme.sh                   Upgrade acme.sh latest
  "
}

ARG_NUM=$#
TEMP=`getopt -o h --long help,nginx:,tengine:,openresty:,apache:,tomcat:,db:,postgresql:,php:,redis:,valkey:,memcached:,phpmyadmin:,nodejs:,node:,oneinstack,acme.sh -- "$@" 2>/dev/null`

[ $? != 0 ] && echo "${CWARNING}ERROR: unknown argument! ${CEND}" && Show_Help && exit 1
eval set -- "${TEMP}"
while :; do
  [ -z "$1" ] && break;
  case "$1" in
    -h|--help)
      Show_Help; exit 0
      ;;
    --nginx)
      nginx_flag=y; NEW_nginx_ver=$2; shift 2
      ;;
    --tengine)
      tengine_flag=y; NEW_tengine_ver=$2; shift 2
      ;;
    --openresty)
      openresty_flag=y; NEW_openresty_ver=$2; shift 2
      ;;
    --apache)
      apache_flag=y; NEW_apache_ver=$2; shift 2
      ;;
    --tomcat)
      tomcat_flag=y; NEW_tomcat_ver=$2; shift 2
      ;;
    --db)
      db_flag=y; NEW_db_ver=$2; shift 2
      ;;
    --postgresql)
      postgresql_flag=y; NEW_pgsql_ver=$2; shift 2
      ;;
    --php)
      php_flag=y; NEW_php_ver=$2; shift 2
      ;;
    --redis)
      redis_flag=y; NEW_redis_ver=$2; shift 2
      ;;
    --valkey)
      valkey_flag=y; NEW_valkey_ver=$2; shift 2
      ;;
    --memcached)
      memcached_flag=y; NEW_memcached_ver=$2; shift 2
      ;;
    --phpmyadmin)
      phpmyadmin_flag=y; NEW_phpmyadmin_ver=$2; shift 2
      ;;
    --nodejs|--node)
      nodejs_flag=y; NEW_nodejs_ver=$2; shift 2
      ;;
    --oneinstack)
      NEW_oneinstack_ver=latest; shift 1
      ;;
    --acme.sh)
      NEW_acme_ver=latest; shift 1
      ;;
    --)
      shift
      ;;
    *)
      echo "${CWARNING}ERROR: unknown argument! ${CEND}" && Show_Help && exit 1
      ;;
  esac
done

Menu() {
  menu_status=0
  while :; do
    printf "
What Are You Doing?
\t${CMSG} 1${CEND}. Upgrade Nginx/Tengine/OpenResty
\t${CMSG} 2${CEND}. Upgrade Apache
\t${CMSG} 3${CEND}. Upgrade Tomcat
\t${CMSG} 4${CEND}. Upgrade MySQL/MariaDB/Percona
\t${CMSG} 5${CEND}. Upgrade PHP
\t${CMSG} 6${CEND}. Upgrade Redis
\t${CMSG} 7${CEND}. Upgrade Valkey
\t${CMSG} 8${CEND}. Upgrade Memcached
\t${CMSG} 9${CEND}. Upgrade phpMyAdmin
\t${CMSG}10${CEND}. Upgrade Nodejs
\t${CMSG}11${CEND}. Upgrade OneinStack latest
\t${CMSG}12${CEND}. Upgrade acme.sh latest
\t${CMSG}13${CEND}. Upgrade PostgreSQL (minor or major version)
\t${CMSG} q${CEND}. Exit
"
    echo
    read -e -p "Please input the correct option: " Upgrade_flag
    printf 'Selected menu option: %s\n' "${Upgrade_flag}"
    if [[ ! "${Upgrade_flag}" =~ ^[1-9,q]$|^1[0-3]$ ]]; then
      echo "${CWARNING}input error! Please only input 1~13 and q${CEND}"
    else
      case "${Upgrade_flag}" in
        1)
          [ -e "${nginx_install_dir}/sbin/nginx" ] && Upgrade_Nginx
          [ -e "${tengine_install_dir}/sbin/nginx" ] && Upgrade_Tengine
          [ -e "${openresty_install_dir}/nginx/sbin/nginx" ] && Upgrade_OpenResty
          ;;
        2)
          Upgrade_Apache
          ;;
        3)
          Upgrade_Tomcat
          ;;
        4)
          if [ ! -e "$db_install_dir/bin/mysql" ]; then
            echo "${CWARNING}MySQL/MariaDB/Percona is not installed. Choose 13 to upgrade PostgreSQL.${CEND}"
          else
            Upgrade_DB
          fi
          ;;
        5)
          Upgrade_PHP
          ;;
        6)
          Upgrade_Redis
          ;;
        7)
          Upgrade_Valkey
          ;;
        8)
          Upgrade_Memcached
          ;;
        9)
          Upgrade_phpMyAdmin
          ;;
        10)
          Upgrade_Nodejs
          ;;
        11)
          if Upgrade_OneinStack; then menu_status=0; else menu_status=$?; fi
          ;;
        12)
          if [ -e ~/.acme.sh/acme.sh ]; then
            ~/.acme.sh/acme.sh --force --upgrade; ~/.acme.sh/acme.sh --version;
          elif [ -e /usr/local/acme.sh/acme.sh ]; then
            /usr/local/acme.sh/acme.sh --force --upgrade; /usr/local/acme.sh/acme.sh --version;
          elif [ -e /opt/acme.sh/acme.sh ]; then
            /opt/acme.sh/acme.sh --force --upgrade; /opt/acme.sh/acme.sh --version;
          elif command -v acme.sh >/dev/null 2>&1; then
            acme.sh --force --upgrade; acme.sh --version;
          else
            echo "${CWARNING}acme.sh not found!${CEND}"
          fi
          ;;
        13)
          Upgrade_PostgreSQL
          ;;
        q)
          type check_os_eol >/dev/null 2>&1 && check_os_eol
          exit "${menu_status}"
          ;;
      esac
    fi
  done
}

if [ ${ARG_NUM} == 0 ]; then
  Menu
else
  upgrade_status=0
  [ "${nginx_flag}" == 'y' ] && Upgrade_Nginx
  [ "${tengine_flag}" == 'y' ] && Upgrade_Tengine
  [ "${openresty_flag}" == 'y' ] && Upgrade_OpenResty
  [ "${apache_flag}" == 'y' ] && Upgrade_Apache
  [ "${tomcat_flag}" == 'y' ] && Upgrade_Tomcat
  [ "${db_flag}" == 'y' ] && Upgrade_DB
  [ "${postgresql_flag}" == 'y' ] && Upgrade_PostgreSQL
  [ "${php_flag}" == 'y' ] && Upgrade_PHP
  [ "${redis_flag}" == 'y' ] && Upgrade_Redis
  [ "${valkey_flag}" == 'y' ] && Upgrade_Valkey
  [ "${memcached_flag}" == 'y' ] && Upgrade_Memcached
  [ "${phpmyadmin_flag}" == 'y' ] && Upgrade_phpMyAdmin
  [ "${nodejs_flag}" == 'y' ] && Upgrade_Nodejs
  if [ "${NEW_oneinstack_ver}" == 'latest' ]; then
    Upgrade_OneinStack || upgrade_status=$?
  fi
  if [ "${NEW_acme_ver}" == 'latest' ]; then
    if [ -e ~/.acme.sh/acme.sh ]; then
      ~/.acme.sh/acme.sh --force --upgrade; ~/.acme.sh/acme.sh --version;
    elif [ -e /usr/local/acme.sh/acme.sh ]; then
      /usr/local/acme.sh/acme.sh --force --upgrade; /usr/local/acme.sh/acme.sh --version;
    elif [ -e /opt/acme.sh/acme.sh ]; then
      /opt/acme.sh/acme.sh --force --upgrade; /opt/acme.sh/acme.sh --version;
    elif command -v acme.sh >/dev/null 2>&1; then
      acme.sh --force --upgrade; acme.sh --version;
    else
      echo "${CWARNING}acme.sh not found!${CEND}"
    fi
  fi
  type check_os_eol >/dev/null 2>&1 && check_os_eol
  exit "${upgrade_status}"
fi

