#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

if [ -e "/etc/os-release" ]; then
  . /etc/os-release
else
  echo "${CFAILURE}/etc/os-release does not exist! ${CEND}"
  kill -9 $$; exit 1;
fi

# Get OS Version
Platform=${ID,,}
VERSION_MAIN_ID=${VERSION_ID%%.*}
ARCH=$(arch)
if [[ "${Platform}" =~ ^centos$|^rhel$|^almalinux$|^rocky$|^fedora$|^amzn$|^ol$|^alinux$|^anolis$|^tencentos$|^opencloudos$|^euleros$|^openeuler$|^kylin$|^uos$|^kylinsecos$ ]]; then
  PM=yum
  Family=rhel
  RHEL_ver=${VERSION_MAIN_ID}
  if [[ "${Platform}" =~ ^centos$ ]]; then
    if [ "${VERSION_MAIN_ID}" == '6' ]; then
      sed -i "s@centos/\$releasever@centos-vault/6.10@g" /etc/yum.repos.d/CentOS-Base.repo
      sed -i 's@centos/RPM-GPG@centos-vault/RPM-GPG@g' /etc/yum.repos.d/CentOS-Base.repo
      [ -e /etc/yum.repos.d/epel.repo ] && rm -f /etc/yum.repos.d/epel.repo
    elif [ "${VERSION_MAIN_ID}" == '7' ]; then
      # CentOS 7 reached EOL (2024-06-30): mirrorlist.centos.org/mirror.centos.org are offline,
      # so every yum call fails. Switch the stock repos to the vault archive.
      if grep -qE '^mirrorlist=https?://mirrorlist.centos.org|^baseurl=https?://mirror.centos.org' /etc/yum.repos.d/CentOS-*.repo 2>/dev/null; then
        if curl --connect-timeout 3 -m 5 -sI https://vault.centos.org > /dev/null 2>&1; then
          c7_vault=https://vault.centos.org
        else
          c7_vault=https://mirrors.aliyun.com/centos-vault
        fi
        sed -i -e 's@^mirrorlist=@#mirrorlist=@g' \
               -e "s@^#\?baseurl=https\?://mirror.centos.org/centos/\$releasever@baseurl=${c7_vault}/7.9.2009@g" \
               -e "s@^#\?baseurl=https\?://mirror.centos.org/altarch/\$releasever@baseurl=${c7_vault}/altarch/7.9.2009@g" \
               /etc/yum.repos.d/CentOS-*.repo
        yum clean all > /dev/null 2>&1
      fi
    fi
  elif [[ "${Platform}" =~ ^fedora$ ]]; then
    Fedora_ver=${VERSION_MAIN_ID}
    [ ${VERSION_MAIN_ID} -ge 19 ] && [ ${VERSION_MAIN_ID} -lt 28 ] && RHEL_ver=7
    [ ${VERSION_MAIN_ID} -ge 28 ] && [ ${VERSION_MAIN_ID} -lt 34 ] && RHEL_ver=8
    [ ${VERSION_MAIN_ID} -ge 34 ] && [ ${VERSION_MAIN_ID} -lt 40 ] && RHEL_ver=9
    [ ${VERSION_MAIN_ID} -ge 40 ] && RHEL_ver=10
  elif [[ "${Platform}" =~ ^amzn$|^alinux$|^tencentos$|^euleros$ ]]; then
    [[ "${VERSION_MAIN_ID}" =~ ^2$ ]] && RHEL_ver=7
    [[ "${VERSION_MAIN_ID}" =~ ^3$ ]] && RHEL_ver=8
    [[ "${VERSION_MAIN_ID}" =~ ^4$ ]] && RHEL_ver=9
  elif [[ "${Platform}" =~ ^openeuler$ ]]; then
    [[ "${RHEL_ver}" =~ ^20$ ]] && RHEL_ver=7
    [[ "${RHEL_ver}" =~ ^2[1,2]$ ]] && RHEL_ver=8
  elif [[ "${Platform}" =~ ^kylin$ ]]; then
    [[ "${RHEL_ver}" =~ ^V10$ ]] && RHEL_ver=7
  elif [[ "${Platform}" =~ ^uos$ ]]; then
    [[ "${RHEL_ver}" =~ ^20$ ]] && RHEL_ver=8
  elif [[ "${Platform}" =~ ^kylinsecos$ ]]; then
    [[ "${VERSION_ID}" =~ ^3.4 ]] && RHEL_ver=7
    [[ "${VERSION_ID}" =~ ^3.5 ]] && RHEL_ver=8
  fi
elif [[ "${Platform}" =~ ^debian$|^deepin$|^kali$ ]]; then
  PM=apt-get
  Family=debian
  Debian_ver=${VERSION_MAIN_ID}
  if [[ "${Platform}" =~ ^deepin$ ]]; then
    [[ "${Debian_ver}" =~ ^20$ ]] && Debian_ver=10
    [[ "${Debian_ver}" =~ ^23$ ]] && Debian_ver=11
  elif [[ "${Platform}" =~ ^kali$ ]]; then
    [[ "${Debian_ver}" =~ ^202 ]] && Debian_ver=10
  fi
elif [[ "${Platform}" =~ ^ubuntu$|^linuxmint$|^elementary$ ]]; then
  PM=apt-get
  Family=ubuntu
  Ubuntu_ver=${VERSION_MAIN_ID}
  if [[ "${Platform}" =~ ^linuxmint$ ]]; then
    [[ "${VERSION_MAIN_ID}" =~ ^18$ ]] && Ubuntu_ver=16
    [[ "${VERSION_MAIN_ID}" =~ ^19$ ]] && Ubuntu_ver=18
    [[ "${VERSION_MAIN_ID}" =~ ^20$ ]] && Ubuntu_ver=20
    [[ "${VERSION_MAIN_ID}" =~ ^21$ ]] && Ubuntu_ver=22
    [[ "${VERSION_MAIN_ID}" =~ ^22$ ]] && Ubuntu_ver=24
  elif [[ "${Platform}" =~ ^elementary$ ]]; then
    [[ "${VERSION_MAIN_ID}" =~ ^5$ ]] && Ubuntu_ver=18
    [[ "${VERSION_MAIN_ID}" =~ ^6$ ]] && Ubuntu_ver=20
    [[ "${VERSION_MAIN_ID}" =~ ^7$ ]] && Ubuntu_ver=22
    [[ "${VERSION_MAIN_ID}" =~ ^8$ ]] && Ubuntu_ver=24
  fi
else
  echo "${CFAILURE}Does not support this OS ${CEND}"
  kill -9 $$; exit 1;
fi

# Check OS Version
if [ ${RHEL_ver} -lt 7 >/dev/null 2>&1 ] || [ ${Debian_ver} -lt 9 >/dev/null 2>&1 ] || [ ${Ubuntu_ver} -lt 16 >/dev/null 2>&1 ]; then
  echo "${CFAILURE}Does not support this OS, Please install CentOS 7+,Debian 9+,Ubuntu 16+ ${CEND}"
  kill -9 $$; exit 1;
fi

if ! command -v gcc > /dev/null 2>&1 || ! command -v getopt > /dev/null 2>&1 || ! command -v make > /dev/null 2>&1; then
  [ "${PM}" == 'apt-get' ] && apt-get -y update > /dev/null
  ${PM} -y install gcc make util-linux > /dev/null
fi
gcc_ver=$(gcc -dumpversion | awk -F. '{print $1}')

[ ${gcc_ver} -lt 5 >/dev/null 2>&1 ] && redis_ver=${redis_oldver}
# jemalloc 5.4.0+ uses __has_include in #if, which GCC < 5 (e.g. CentOS 7 GCC 4.8) cannot parse
[ ${gcc_ver} -lt 5 >/dev/null 2>&1 ] && jemalloc_ver=${jemalloc_oldver}
# libiconv 1.18+ po/Makefile uses the '!=' shell assignment, which needs GNU make 4.0+ (CentOS 7 ships make 3.82)
make_ver=$(make --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)
[ -n "${make_ver}" ] && [ "${make_ver%%.*}" -lt 4 >/dev/null 2>&1 ] && libiconv_ver=${libiconv_oldver}

# Compatibility CFLAGS for building legacy C code (PHP etc.) with GCC 14+/C23 defaults.
# Only pass flags the local GCC understands: -std=gnu17 needs GCC 8+, and
# -Wincompatible-pointer-types/-Wdiscarded-qualifiers/-Wint-conversion need GCC 5+ (CentOS 7 ships GCC 4.8).
if [ ${gcc_ver} -ge 8 >/dev/null 2>&1 ]; then
  compat_cflags='-std=gnu17 -Wno-error=incompatible-pointer-types -Wno-error=discarded-qualifiers -Wno-error=int-conversion'
  compat_cflags_c89='-std=gnu89 -Wno-error=int-conversion -Wno-error=incompatible-pointer-types'
elif [ ${gcc_ver} -ge 5 >/dev/null 2>&1 ]; then
  compat_cflags='-std=gnu11 -Wno-error=incompatible-pointer-types -Wno-error=discarded-qualifiers -Wno-error=int-conversion'
  compat_cflags_c89='-std=gnu89 -Wno-error=int-conversion -Wno-error=incompatible-pointer-types'
else
  compat_cflags=''
  compat_cflags_c89='-std=gnu89'
fi
compat_cflags="${compat_cflags} -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-return-type"
compat_cflags_c89="${compat_cflags_c89} -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-return-type"

# MySQL 8.0.46+/8.4.11+ only ship glibc2.28 binaries; older systems (e.g. CentOS 7) use the last glibc2.17 build
glibc_ver=$(ldd --version 2>&1 | head -n1 | grep -oE '[0-9]+\.[0-9]+$')
if [ -n "${glibc_ver}" ] && [ "$(printf '%s\n' 2.28 "${glibc_ver}" | sort -V | head -n1)" == "2.28" ]; then
  mysql_glibc=2.28
else
  mysql_glibc=2.17
  mysql84_ver=${mysql84_oldver}
  mysql80_ver=${mysql80_oldver}
fi

# MongoDB 8.0 only provides distro-specific binary packages
mongodb_distro=''
case "${Family}" in
  rhel)
    [ "${RHEL_ver}" == '8' ] && mongodb_distro=rhel8
    [ "${RHEL_ver}" -ge 9 >/dev/null 2>&1 ] && mongodb_distro=rhel93
    ;;
  debian)
    [ "${Debian_ver}" -ge 12 >/dev/null 2>&1 ] && [ "$(arch)" == 'x86_64' ] && mongodb_distro=debian12
    ;;
  ubuntu)
    [ "${Ubuntu_ver}" == '20' ] && mongodb_distro=ubuntu2004
    [ "${Ubuntu_ver}" == '22' ] && mongodb_distro=ubuntu2204
    [ "${Ubuntu_ver}" -ge 24 >/dev/null 2>&1 ] && mongodb_distro=ubuntu2404
    ;;
esac
[ -n "${mongodb_distro}" ] && mongodb_pkg=mongodb-linux-$(arch)-${mongodb_distro}-${mongodb_ver}

if uname -m | grep -Eqi "arm|aarch64"; then
  armplatform="y"
  if uname -m | grep -Eqi "armv7"; then
    TARGET_ARCH="armv7"
  elif uname -m | grep -Eqi "armv8"; then
    TARGET_ARCH="arm64"
  elif uname -m | grep -Eqi "aarch64"; then
    TARGET_ARCH="aarch64"
  else
    TARGET_ARCH="unknown"
  fi
fi

if [ "$(uname -r | awk -F- '{print $3}' 2>/dev/null)" == "Microsoft" ]; then
  Wsl=true
fi

if [ "$(getconf WORD_BIT)" == "32" ] && [ "$(getconf LONG_BIT)" == "64" ]; then
  if [ "${TARGET_ARCH}" == 'aarch64' ]; then
    SYS_ARCH=arm64
    SYS_ARCH_i=aarch64
    SYS_ARCH_n=arm64
  else
    SYS_ARCH=amd64 #openjdk
    SYS_ARCH_i=x86-64 #ioncube
    SYS_ARCH_n=x64 #nodejs
  fi
else
  echo "${CWARNING}32-bit OS are not supported! ${CEND}"
  kill -9 $$; exit 1;
fi

THREAD=$(grep 'processor' /proc/cpuinfo | sort -u | wc -l)

# MySQL 9.7 generic binaries require a modern x86_64 userspace.
MySQL97_OS_Supported() {
  [ "${ARCH}" != 'x86_64' ] && return 1

  case "${Family}" in
    rhel) [ "${RHEL_ver:-0}" -ge 8 ] ;;
    debian) [ "${Debian_ver:-0}" -ge 12 ] ;;
    ubuntu) [ "${Ubuntu_ver:-0}" -ge 22 ] ;;
    *) return 1 ;;
  esac
}

# Percona binary: https://docs.percona.com/percona-server/5.7/installation/binary-tarball.html
if [ ${Debian_ver} -lt 9 >/dev/null 2>&1 ]; then
  sslLibVer=ssl100
elif [ "${RHEL_ver}" == '7' ] && [ "${Platform}" != 'fedora' ]; then
  sslLibVer=ssl101
elif [ ${Debian_ver} -ge 9 >/dev/null 2>&1 ] || [ ${Ubuntu_ver} -ge 16 >/dev/null 2>&1 ]; then
  sslLibVer=ssl102
elif [ ${Fedora_ver} -ge 27 >/dev/null 2>&1 ]; then
  sslLibVer=ssl102
elif [ "${RHEL_ver}" == '8' ]; then
  sslLibVer=ssl1:111
else
  sslLibVer=unknown
fi
