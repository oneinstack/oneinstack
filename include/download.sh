#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

verify_archive_integrity() {
  local target="$1"
  [ ! -f "${target}" ] && return 1
  case "${target}" in
    *.tar.gz|*.tgz)
      gzip -t "${target}" >/dev/null 2>&1 || return 1
      ;;
    *.tar.xz|*.xz)
      which xz >/dev/null 2>&1 && { xz -t "${target}" >/dev/null 2>&1 || return 1; }
      ;;
    *.tar.bz2|*.bz2)
      which bzip2 >/dev/null 2>&1 && { bzip2 -t "${target}" >/dev/null 2>&1 || return 1; }
      ;;
    *.zip)
      which unzip >/dev/null 2>&1 && { unzip -tq "${target}" >/dev/null 2>&1 || return 1; }
      ;;
  esac
  return 0
}

Download_src() {
  local filename="${src_url##*/}"
  
  # Remove pseudo-files from previous failed attempts or corrupted archives
  if [ -e "${filename}" ]; then
    local sz=$(wc -c < "${filename}" 2>/dev/null | tr -d ' ')
    if [ -n "$sz" ] && [ "$sz" -lt 1000 ]; then
      if grep -qi "<html>\|404 Not Found\|301 Moved" "${filename}" 2>/dev/null; then
        rm -f "${filename}"
      fi
    fi
    if [ -f "${filename}" ] && ! verify_archive_integrity "${filename}"; then
      echo "${CWARNING}Existing file ${filename} is corrupted or truncated, removing to re-download...${CEND}"
      rm -f "${filename}"
    fi
  fi

  if [ -s "${filename}" ]; then
    echo "[${CMSG}${filename}${CEND}] found"
    return 0
  fi

  # Build URL fallback array
  local urls=()
  
  # 1. ALWAYS inject mirrors.oneinstack.com/oneinstack/src as the absolute primary
  local oneinstack_url="https://mirrors.oneinstack.com/oneinstack/src/${filename}"
  urls+=("${oneinstack_url}")
  
  # 2. Add the requested src_url if it's different
  if [ "${src_url}" != "${oneinstack_url}" ]; then
    urls+=("${src_url}")
  fi

  # 3. Add known regional/alternative backups
  if [[ "${src_url}" == *"mirrors.tuna.tsinghua.edu.cn"* ]]; then
    urls+=("${src_url/mirrors.tuna.tsinghua.edu.cn/mirrors.ustc.edu.cn}")
  elif [[ "${src_url}" == *"ftp.postgresql.org/pub"* ]]; then
    urls+=("${src_url/ftp.postgresql.org\/pub/ftp.heanet.ie\/mirrors\/postgresql}")
  elif [[ "${src_url}" == *"mirrors.oneinstack.com"* ]]; then
    urls+=("${src_url/mirrors.oneinstack.com/mirrors.linuxeye.com}")
  fi

  local success=0
  for url in "${urls[@]}"; do
    wget --limit-rate=100M --tries=3 -c --no-check-certificate "${url}"
    
    if [ -e "${filename}" ]; then
      local sz=$(wc -c < "${filename}" 2>/dev/null | tr -d ' ')
      if [ -n "$sz" ] && [ "$sz" -lt 1000 ]; then
        if grep -qi "<html>\|404 Not Found\|301 Moved" "${filename}" 2>/dev/null; then
          rm -f "${filename}"
          continue
        fi
      fi
      
      if ! verify_archive_integrity "${filename}"; then
        echo "${CWARNING}Downloaded file ${filename} from ${url} is incomplete or corrupted, removing...${CEND}"
        rm -f "${filename}"
        continue
      fi

      success=1
      break
    fi
  done

  if [ ${success} -eq 0 ]; then
    echo "${CFAILURE}Auto download failed or package corrupted! You can manually download ${filename} from ${src_url} into oneinstack/src directory.${CEND}"
    if [ "$1" != "no_kill" ]; then
      kill -9 $$; exit 1;
    fi
  fi
}
