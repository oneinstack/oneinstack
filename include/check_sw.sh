#!/bin/bash
# Author:  Alpha Eva <kaneawk AT gmail.com>
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

installDepsDebian() {
  echo "${CMSG}Removing the conflicting packages...${CEND}"
  if [ "${apache_flag}" == 'y' ]; then
    killall apache2
    pkgList="apache2 apache2-doc libsodium-dev apache2-utils apache2.2-common apache2.2-bin apache2-mpm-prefork apache2-doc apache2-mpm-worker php5 php5-common php5-cgi php5-cli php5-mysql php5-curl php5-gd"
    for Package in ${pkgList};do
      apt-get -y purge ${Package}
    done
    dpkg -l | grep ^rc | awk '{print $2}' | xargs dpkg -P
  fi

  if [[ "${db_option}" =~ ^[0-9]$|^1[0-2]$|^15$ ]]; then
    pkgList="mysql-client mysql-server mysql-common libsodium-dev mysql-server-core-5.5 mysql-client-5.5 mariadb-client mariadb-server mariadb-common"
    for Package in ${pkgList};do
      apt-get -y purge ${Package}
    done
    dpkg -l | grep ^rc | awk '{print $2}' | xargs dpkg -P
  fi

  echo "${CMSG}Installing dependencies packages...${CEND}"
  apt-get -y update
  apt-get -y autoremove
  apt-get -yf install
  export DEBIAN_FRONTEND=noninteractive

  # critical security updates
  grep security /etc/apt/sources.list > /tmp/security.sources.list
  apt-get -y upgrade -o Dir::Etc::SourceList=/tmp/security.sources.list

  # Install needed packages
  case "${Debian_ver}" in
    9|10|11|12)
      pkgCompatList="libncurses5 libncurses5-dev libaio1 libidn11 libidn11-dev"
      ;;
    13)
      # Debian 13 renamed libaio1 and removed the ncurses5/libidn11 packages.
      pkgCompatList="libncurses6 libtinfo6 libncurses-dev libaio1t64 libidn2-dev"
      ;;
    *)
      echo "${CFAILURE}Your system Debian ${Debian_ver} are not supported!${CEND}"
      kill -9 $$; exit 1;
      ;;
  esac
  pkgList="debian-keyring libsodium-dev debian-archive-keyring libxpm-dev build-essential gcc g++ make cmake autoconf libbz2-dev libjpeg62-turbo-dev libjpeg-dev libpng-dev libgd-dev libxml2 libxml2-dev zlib1g zlib1g-dev libc6 libc6-dev libc-client2007e-dev libglib2.0-0 libglib2.0-dev bzip2 libzip-dev libbz2-1.0 ${pkgCompatList} libaio-dev numactl libreadline-dev curl libcurl3-gnutls libcurl4-openssl-dev e2fsprogs libkrb5-3 libkrb5-dev libltdl-dev openssl net-tools libssl-dev libtool libevent-dev bison re2c libsasl2-dev libxslt1-dev libicu-dev locales patch vim zip unzip tmux htop bc dc expect libexpat1-dev libonig-dev libtirpc-dev rsync git lsof lrzsz rsyslog cron logrotate chrony libsqlite3-dev psmisc wget sysv-rc apt-transport-https ca-certificates software-properties-common gnupg ufw"
  for Package in ${pkgList}; do
    apt-get --no-install-recommends -y install ${Package}
  done
}

# Install renamed runtime packages for binary database installs on current apt
# distributions. On 64-bit ABIs, time_t was already 64-bit, so libaio's t64
# transition only changed its SONAME. Do not alias ncurses/tinfo across major
# SONAMEs; those ABIs are not interchangeable.
# 为新版 apt 系统补齐二进制数据库运行库；仅在 64 位系统兼容 libaio 的 t64
# 改名，绝不把 ncurses/tinfo 的新主版本伪装成旧 ABI。
ensureAptDatabaseCompat() {
  local Package Deb_Multiarch Deb_LibDir

  [[ "${db_option}" =~ ^[0-9]$|^1[0-2]$|^15$ ]] || return 0
  [ "${dbinstallmethod}" == '1' ] || return 0

  if { [ "${Family}" == 'debian' ] && [ "${Debian_ver:-0}" -ge 13 ]; } || \
    { [ "${Family}" == 'ubuntu' ] && [ "${Ubuntu_ver:-0}" -ge 24 ]; }; then
    export DEBIAN_FRONTEND=noninteractive
    for Package in libncurses6 libtinfo6 libaio1t64 libaio-dev; do
      dpkg -s "${Package}" > /dev/null 2>&1 || \
        apt-get --no-install-recommends -y install "${Package}" || {
          echo "${CFAILURE}Unable to install required compatibility package: ${Package}${CEND}"
          return 1
        }
    done

    if [ "$(getconf LONG_BIT 2>/dev/null)" == '64' ]; then
      Deb_Multiarch=$(dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null)
      [ -z "${Deb_Multiarch}" ] && Deb_Multiarch=$(gcc -print-multiarch 2>/dev/null)
      Deb_LibDir=/usr/lib/${Deb_Multiarch}
      if [ -n "${Deb_Multiarch}" ] && [ -d "${Deb_LibDir}" ] && \
        [ -e "${Deb_LibDir}/libaio.so.1t64" ] && \
        [ ! -e "${Deb_LibDir}/libaio.so.1" ] && [ ! -L "${Deb_LibDir}/libaio.so.1" ]; then
        ln -s libaio.so.1t64 "${Deb_LibDir}/libaio.so.1"
        ldconfig
      fi
    fi
  fi
}

installDepsRHEL() {
  [ -e '/etc/yum.conf' ] && sed -i 's@^exclude@#exclude@' /etc/yum.conf
  if [ "${RHEL_ver}" == '9' ]; then
    if [[ "${Platform}" =~ "rhel" ]]; then
      subscription-manager repos --enable codeready-builder-for-rhel-9-${ARCH}-rpms
      dnf -y install chrony oniguruma-devel rpcgen
    elif [[ "${Platform}" =~ "ol" ]]; then
      dnf config-manager --set-enabled ol9_codeready_builder
      dnf -y install chrony oniguruma-devel rpcgen
    else
      dnf -y --enablerepo=crb install chrony oniguruma-devel rpcgen
    fi
    systemctl enable chronyd
  elif [ "${RHEL_ver}" == '8' ]; then
    if [[ "${Platform}" =~ "rhel" ]]; then
      subscription-manager repos --enable codeready-builder-for-rhel-8-${ARCH}-rpms
      dnf -y install chrony oniguruma-devel rpcgen
    elif [[ "${Platform}" =~ "ol" ]]; then
      dnf config-manager --set-enabled ol8_codeready_builder
      dnf -y install chrony oniguruma-devel rpcgen
    else
      [ -z "`grep -w epel /etc/yum.repos.d/*.repo`" ] && yum -y install epel-release
      if grep -qw "^\[PowerTools\]" /etc/yum.repos.d/*.repo; then
        dnf -y --enablerepo=PowerTools install chrony oniguruma-devel rpcgen
      elif grep -qw "^\[powertools\]" /etc/yum.repos.d/*.repo; then
        dnf -y --enablerepo=powertools install chrony oniguruma-devel rpcgen
      fi
    fi
    systemctl enable chronyd
  elif [ "${RHEL_ver}" == '7' ]; then
    [ -z "`grep -w epel /etc/yum.repos.d/*.repo`" ] && yum -y install epel-release
    yum -y groupremove "Basic Web Server" "MySQL Database server" "MySQL Database client"
  fi

  if [ "${RHEL_ver}" == '9' ]; then
    [ ! -e "/usr/lib64/libtinfo.so.5" ] && ln -s /usr/lib64/libtinfo.so.6 /usr/lib64/libtinfo.so.5
    [ ! -e "/usr/lib64/libncurses.so.5" ] && ln -s /usr/lib64/libncurses.so.6 /usr/lib64/libncurses.so.5
  fi

  echo "${CMSG}Installing dependencies packages...${CEND}"
  # Install needed packages
  pkgList="perl-FindBin deltarpm libsodium-dev drpm gcc gcc-c++ make cmake autoconf libjpeg libjpeg-dev libjpeg-devel libbz2-dev libjpeg-turbo libjpeg-turbo-devel libpng libpng-devel libxml2 libxml2-devel zlib zlib-devel libzip libzip-devel glibc glibc-devel krb5-devel libcurl4-openssl-dev libc-client libc-client-devel glib2 glib2-devel bzip2 bzip2-devel ncurses ncurses-devel ncurses-compat-libs libaio numactl numactl-libs readline-devel curl curl-devel e2fsprogs e2fsprogs-devel krb5-devel libidn libidn-devel openssl openssl-devel net-tools libxslt-devel libssl-dev libicu-devel libevent-devel libtool libtool-ltdl bison gd-devel vim-enhanced pcre-devel libmcrypt libsqlite3-dev libmcrypt-devel mhash mhash-devel mcrypt zip unzip chrony oniguruma-devel rpcgen sqlite-devel sysstat patch bc expect expat-devel perl-devel oniguruma oniguruma-devel libtirpc-devel nss libnsl rsync rsyslog git lsof lrzsz psmisc wget which libatomic tmux chkconfig firewalld gnupg2"
  for Package in ${pkgList}; do
    yum -y install ${Package}
  done
  [ "${RHEL_ver}" -lt 8 ] && yum -y install cmake3

  yum -y update bash openssl glibc
}

installDepsUbuntu() {
  # Uninstall the conflicting software
  echo "${CMSG}Removing the conflicting packages...${CEND}"
  if [ "${apache_flag}" == 'y' ]; then
    killall apache2
    pkgList="apache2 apache2-doc apache2-utils apache2.2-common apache2.2-bin apache2-mpm-prefork apache2-doc apache2-mpm-worker php5 php5-common php5-cgi php5-cli php5-mysql php5-curl php5-gd libncurses5"
    for Package in ${pkgList};do
      apt-get -y purge ${Package}
    done
    dpkg -l | grep ^rc | awk '{print $2}' | xargs dpkg -P
  fi

  if [[ "${db_option}" =~ ^[0-9]$|^1[0-2]$|^15$ ]]; then
    pkgList="mysql-client mysql-server mysql-common mysql-server-core-5.5 mysql-client-5.5 mariadb-client mariadb-server mariadb-common"
    for Package in ${pkgList};do
      apt-get -y purge ${Package}
    done
    dpkg -l | grep ^rc | awk '{print $2}' | xargs dpkg -P
  fi

  echo "${CMSG}Installing dependencies packages...${CEND}"
  apt-get -y update
  apt-get -y autoremove
  apt-get -yf install
  export DEBIAN_FRONTEND=noninteractive
  [[ "${Ubuntu_ver}" =~ ^22$ ]] && apt-get -y --allow-downgrades install libicu70=70.1-2 libglib2.0-0=2.72.1-1 libxml2-dev

  # critical security updates
  grep security /etc/apt/sources.list > /tmp/security.sources.list
  apt-get -y upgrade -o Dir::Etc::SourceList=/tmp/security.sources.list

  # Install needed packages
  case "${Ubuntu_ver}" in
    16|17|18|19|20|21|22|23)
      pkgCompatList="libncurses5 libncurses5-dev libaio1 libidn11 libidn11-dev libpng12-0 libpng12-dev libpng3 libcloog-ppl1"
      ;;
    24|25|26)
      # Ubuntu 24.04+ uses the t64 libaio package and no longer ships the legacy packages.
      pkgCompatList="libncurses6 libtinfo6 libncurses-dev libaio1t64 libidn2-dev"
      ;;
    *)
      echo "${CFAILURE}Your system Ubuntu ${Ubuntu_ver} are not supported!${CEND}"
      kill -9 $$; exit 1;
      ;;
  esac
  pkgList="libperl-dev pkg-config libsodium-dev libbz2-dev libxslt-dev libjpeg-dev libxml2-dev libxpm-dev libfreetype-dev debian-keyring debian-archive-keyring build-essential gcc g++ make cmake autoconf libjpeg8 libjpeg8-dev libpng-dev libxml2 libxml2-dev zlib1g zlib1g-dev libc6 libc6-dev libc-client2007e-dev libglib2.0-0 libglib2.0-dev bzip2 libzip-dev libbz2-1.0 ${pkgCompatList} libaio-dev numactl libreadline-dev curl libcurl3-gnutls libcurl4-gnutls-dev libcurl4-openssl-dev e2fsprogs libkrb5-3 libkrb5-dev libltdl-dev openssl net-tools libssl-dev libtool libevent-dev re2c libsasl2-dev libxslt1-dev libicu-dev libsqlite3-dev bison patch vim zip unzip tmux htop bc dc expect libexpat1-dev rsyslog libonig-dev libtirpc-dev libnss3 rsync git lsof lrzsz chrony psmisc wget sysv-rc apt-transport-https ca-certificates software-properties-common gnupg ufw libiconv-dev libfreetype6-dev libexif-dev gettext-dev libgmp-dev"
  export DEBIAN_FRONTEND=noninteractive
  for Package in ${pkgList}; do
    apt-get --no-install-recommends -y install ${Package}
  done
}

installDepsBySrc() {
  pushd ${oneinstack_dir}/src > /dev/null
  if ! command -v icu-config > /dev/null 2>&1 || icu-config --version | grep '^3.' || [ "${Ubuntu_ver}" == "20" ]; then
    tar xzf icu4c-${icu4c_ver}-src.tgz
    pushd icu/source > /dev/null
    ./configure --prefix=/usr/local
    make -j ${THREAD} && make install
    popd > /dev/null
    rm -rf icu
  fi

  if command -v lsof >/dev/null 2>&1; then
    echo 'already initialize' > ~/.oneinstack
  else
    echo "${CFAILURE}${PM} config error parsing file failed${CEND}"
    kill -9 $$; exit 1;
  fi

  popd > /dev/null
}
