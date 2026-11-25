#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Upgrade_OneinStack() {
  pushd ${oneinstack_dir} > /dev/null
  local default_mirror="https://cdn.oneinstack.com"
  local effective_mirror="${mirror_link:-${default_mirror}}"

  _fetch_oneinstack_md5() {
    local url="$1"
    local content=""
    if command -v curl >/dev/null 2>&1; then
      content=$(curl --connect-timeout 5 -m 15 -fsSL "${url}" 2>/dev/null)
      [ -z "${content}" ] && content=$(curl --connect-timeout 5 -m 15 -fsSLk "${url}" 2>/dev/null)
    fi
    if [ -z "${content}" ] && command -v wget >/dev/null 2>&1; then
      content=$(wget --no-check-certificate -qO- -T 15 -t 2 "${url}" 2>/dev/null)
    fi
    printf '%s\n' "${content}" | tr -d '\r' | awk '$2 == "oneinstack.tar.gz" {print $1; exit}'
  }

  local Latest_OneinStack_MD5=""
  Latest_OneinStack_MD5=$(_fetch_oneinstack_md5 "${effective_mirror}/md5sum.txt")
  if [[ ! "${Latest_OneinStack_MD5}" =~ ^[0-9a-fA-F]{32}$ ]] && [ "${effective_mirror}" != "${default_mirror}" ]; then
    echo "${CWARNING}Failed to fetch version info from ${effective_mirror}, trying ${default_mirror}...${CEND}"
    effective_mirror="${default_mirror}"
    Latest_OneinStack_MD5=$(_fetch_oneinstack_md5 "${effective_mirror}/md5sum.txt")
  fi
  if [[ ! "${Latest_OneinStack_MD5}" =~ ^[0-9a-fA-F]{32}$ ]]; then
    echo "${CFAILURE}Error: Failed to fetch latest OneinStack version info from ${effective_mirror}/md5sum.txt! Please check your network or curl/wget installation.${CEND}"
    popd > /dev/null
    return 1
  fi

  local ois_flag=""
  [ ! -e README.md ] && ois_flag=n
  if [ "${oneinstack_md5}" != "${Latest_OneinStack_MD5}" ]; then
    local tmp_tar="/tmp/oneinstack.tar.gz"
    local tmp_opt="/tmp/options.conf.$$"
    local tmp_dir=""
    rm -f "${tmp_tar}"
    if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
      echo "${CFAILURE}Error: Neither wget nor curl is installed!${CEND}"
      popd > /dev/null
      return 1
    fi
    if command -v wget >/dev/null 2>&1; then
      wget --no-check-certificate -q -T 30 -t 2 "${effective_mirror}/oneinstack.tar.gz" -O "${tmp_tar}"
    fi
    if { [ ! -s "${tmp_tar}" ] || ! gzip -t "${tmp_tar}" >/dev/null 2>&1; } && command -v curl >/dev/null 2>&1; then
      rm -f "${tmp_tar}"
      curl --connect-timeout 10 -m 120 -fsSLk "${effective_mirror}/oneinstack.tar.gz" -o "${tmp_tar}"
    fi
    if [ ! -s "${tmp_tar}" ] || ! gzip -t "${tmp_tar}" >/dev/null 2>&1; then
      echo "${CFAILURE}Error: Failed to download valid oneinstack.tar.gz from ${effective_mirror}!${CEND}"
      rm -f "${tmp_tar}"
      popd > /dev/null
      return 1
    fi
    if command -v md5sum >/dev/null 2>&1; then
      local downloaded_md5
      downloaded_md5=$(md5sum "${tmp_tar}" | awk '{print $1}')
      if [ "${downloaded_md5}" != "${Latest_OneinStack_MD5}" ]; then
        echo "${CFAILURE}Error: Downloaded oneinstack.tar.gz md5 (${downloaded_md5}) does not match expected (${Latest_OneinStack_MD5})!${CEND}"
        rm -f "${tmp_tar}"
        popd > /dev/null
        return 1
      fi
    fi

    /bin/cp -a options.conf "${tmp_opt}"
    sed -i '/^oneinstack_dir=/d' "${tmp_opt}"
    tmp_dir=$(mktemp -d /tmp/oneinstack_upgrade.XXXXXX)
    if ! tar xzf "${tmp_tar}" -C "${tmp_dir}"; then
      echo "${CFAILURE}Error: Failed to extract ${tmp_tar}!${CEND}"
      rm -rf "${tmp_tar}" "${tmp_opt}" "${tmp_dir}"
      popd > /dev/null
      return 1
    fi
    if [ -d "${tmp_dir}/oneinstack" ]; then
      /bin/cp -a "${tmp_dir}/oneinstack/." "${oneinstack_dir}/"
    else
      /bin/cp -a "${tmp_dir}/." "${oneinstack_dir}/"
    fi
    rm -rf "${tmp_dir}"

    while IFS= read -r L; do
      [ -z "${L}" ] && continue
      [[ "${L}" =~ ^[[:space:]]*# ]] && continue
      [[ "${L}" != *"="* ]] && continue
      local Key="${L%%=*}"
      local Value="${L#*=}"
      if [ "${Key}" == "mirror_link" ]; then
        case "${Value}" in
          *mirrors.linuxeye.com*|*mirrors.oneinstack.com*|"")
            continue
            ;;
        esac
      fi
      local Escaped_Value
      Escaped_Value=$(printf '%s\n' "${Value}" | sed -e 's/[\\&|]/\\&/g')
      sed -i "s|^${Key}=.*|${Key}=${Escaped_Value}|" ./options.conf
    done < "${tmp_opt}"
    rm -rf "${tmp_tar}" "${tmp_opt}"
    [ "${ois_flag}" == "n" ] && rm -f ss.sh LICENSE README.md
    sed -i "s@^oneinstack_md5=.*@oneinstack_md5=${Latest_OneinStack_MD5}@" ./options.conf
    oneinstack_md5="${Latest_OneinStack_MD5}"
    if [ -e "change_jdk_version.sh" ]; then
      rm -f change_jdk_version.sh
      wget --no-check-certificate -qc "${effective_mirror}/scripts/change_jdk_version.sh"
      chmod +x change_jdk_version.sh
    fi
    if [ -e "${php_install_dir}/sbin/php-fpm" ]; then
      [ -n "`grep ^cgi.fix_pathinfo=0 ${php_install_dir}/etc/php.ini`" ] && sed -i 's@^cgi.fix_pathinfo.*@;&@' ${php_install_dir}/etc/php.ini
      [ -e "/usr/local/php53/etc/php.ini" ] && sed -i 's@^cgi.fix_pathinfo=0@;&@' /usr/local/php53/etc/php.ini 2>/dev/null
      [ -e "/usr/local/php54/etc/php.ini" ] && sed -i 's@^cgi.fix_pathinfo=0@;&@' /usr/local/php54/etc/php.ini 2>/dev/null
      [ -e "/usr/local/php55/etc/php.ini" ] && sed -i 's@^cgi.fix_pathinfo=0@;&@' /usr/local/php55/etc/php.ini 2>/dev/null
      [ -e "/usr/local/php56/etc/php.ini" ] && sed -i 's@^cgi.fix_pathinfo=0@;&@' /usr/local/php56/etc/php.ini 2>/dev/null
      [ -e "/usr/local/php70/etc/php.ini" ] && sed -i 's@^cgi.fix_pathinfo=0@;&@' /usr/local/php70/etc/php.ini 2>/dev/null
      [ -e "/usr/local/php71/etc/php.ini" ] && sed -i 's@^cgi.fix_pathinfo=0@;&@' /usr/local/php71/etc/php.ini 2>/dev/null
      [ -e "/usr/local/php72/etc/php.ini" ] && sed -i 's@^cgi.fix_pathinfo=0@;&@' /usr/local/php72/etc/php.ini 2>/dev/null
      [ -e "/usr/local/php73/etc/php.ini" ] && sed -i 's@^cgi.fix_pathinfo=0@;&@' /usr/local/php73/etc/php.ini 2>/dev/null
      [ -e "/usr/local/php74/etc/php.ini" ] && sed -i 's@^cgi.fix_pathinfo=0@;&@' /usr/local/php74/etc/php.ini 2>/dev/null
      [ -e "/usr/local/php80/etc/php.ini" ] && sed -i 's@^cgi.fix_pathinfo=0@;&@' /usr/local/php80/etc/php.ini 2>/dev/null
      [ -e "/usr/local/php81/etc/php.ini" ] && sed -i 's@^cgi.fix_pathinfo=0@;&@' /usr/local/php81/etc/php.ini 2>/dev/null
      [ -e "/usr/local/php82/etc/php.ini" ] && sed -i 's@^cgi.fix_pathinfo=0@;&@' /usr/local/php82/etc/php.ini 2>/dev/null
      [ -e "/usr/local/php83/etc/php.ini" ] && sed -i 's@^cgi.fix_pathinfo=0@;&@' /usr/local/php83/etc/php.ini 2>/dev/null
      [ -e "/usr/local/php84/etc/php.ini" ] && sed -i 's@^cgi.fix_pathinfo=0@;&@' /usr/local/php84/etc/php.ini 2>/dev/null
      [ -e "/usr/local/php85/etc/php.ini" ] && sed -i 's@^cgi.fix_pathinfo=0@;&@' /usr/local/php85/etc/php.ini 2>/dev/null
      [ -e "/usr/local/php86/etc/php.ini" ] && sed -i 's@^cgi.fix_pathinfo=0@;&@' /usr/local/php86/etc/php.ini 2>/dev/null
    fi
    [ -e "/lib/systemd/system/php-fpm.service" ] && { sed -i 's@^PrivateTmp.*@#&@g' /lib/systemd/system/php-fpm.service; systemctl daemon-reload; }
    echo
    echo "${CSUCCESS}Congratulations! OneinStack upgrade successful! Please re-run ./upgrade.sh to load the latest scripts. ${CEND}"
    echo
  else
    echo "${CWARNING}Your OneinStack already has the latest version (md5: ${Latest_OneinStack_MD5}) or does not need to be upgraded! ${CEND}"
  fi
  popd > /dev/null
}
