#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Download_src() {
  local filename="${src_url##*/}"
  
  # Remove pseudo-files from previous failed attempts
  if [ -e "${filename}" ]; then
    local sz=$(wc -c < "${filename}" 2>/dev/null | tr -d ' ')
    if [ -n "$sz" ] && [ "$sz" -lt 1000 ]; then
      if [[ "${filename}" == *.md5 ]]; then
        if grep -qi "<html>" "${filename}" 2>/dev/null; then
          rm -f "${filename}"
        fi
      else
        rm -f "${filename}"
      fi
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
    # Suppress output if it's trying the fallback, but show a nice message
    # echo "Attempting to download from: ${url}"
    wget --limit-rate=100M --tries=3 -c --no-check-certificate "${url}"
    
    if [ -e "${filename}" ]; then
      local sz=$(wc -c < "${filename}" 2>/dev/null | tr -d ' ')
      if [ -n "$sz" ] && [ "$sz" -lt 1000 ]; then
        if [[ "${filename}" == *.md5 ]]; then
          if grep -qi "<html>" "${filename}" 2>/dev/null; then
            rm -f "${filename}"
            continue
          fi
        else
          rm -f "${filename}"
          continue
        fi
      fi
      
      success=1
      break
    fi
  done

  if [ ${success} -eq 0 ]; then
    echo "${CFAILURE}Auto download failed! You can manually download ${src_url} into the oneinstack/src directory.${CEND}"
    if [ "$1" != "no_kill" ]; then
      kill -9 $$; exit 1;
    fi
  fi
}
