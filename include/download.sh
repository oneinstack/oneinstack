#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Parse_Version_Spec() {
  local variable_name="$1"
  local spec="${!variable_name}"
  local version checksum algorithm digest checksum_name

  case "${spec}" in
    *,sha256=*|*,md5=*)
      version=${spec%%,*}
      checksum=${spec#*,}
      algorithm=${checksum%%=*}
      digest=${checksum#*=}
      ;;
    *,*)
      version=${spec%%,*}
      digest=${spec#*,}
      [ "${#digest}" -eq 32 ] && algorithm=md5 || algorithm=sha256
      ;;
    *)
      return 0
      ;;
  esac

  [ -n "${version}" ] || {
    echo "Missing version in specification: ${variable_name}=${spec}"
    return 1
  }
  case "${algorithm}" in
    sha256)
      [[ "${digest}" =~ ^[[:xdigit:]]{64}$ ]] || {
        echo "Invalid SHA-256 in specification: ${variable_name}=${spec}"
        return 1
      }
      ;;
    md5)
      [[ "${digest}" =~ ^[[:xdigit:]]{32}$ ]] || {
        echo "Invalid MD5 in specification: ${variable_name}=${spec}"
        return 1
      }
      ;;
  esac

  checksum_name=${variable_name%_ver}
  checksum="${algorithm}=${digest}"
  printf -v "${variable_name}" '%s' "${version}"
  printf -v "${checksum_name}_checksum" '%s' "${checksum}"
  printf -v "${checksum_name}_${algorithm}" '%s' "${digest}"
}

Parse_Version_Specs() {
  local variable_name

  while IFS= read -r variable_name; do
    case "${variable_name}" in
      *_ver)
        Parse_Version_Spec "${variable_name}" || return 1
        ;;
    esac
  done < <(compgen -A variable)
}

if ! Parse_Version_Specs; then
  return 1 2>/dev/null || exit 1
fi

Trusted_Mirror_Link() {
  # Only the mirror explicitly published by the official oneinstack.com site is trusted.
  # 仅信任 oneinstack.com 官网明确公布的镜像，拒绝同名第三方及公共托管域名。
  [ "${mirror_link%/}" = 'https://mirrors.oneinstack.com' ]
}

Require_Trusted_Mirror() {
  if ! Trusted_Mirror_Link; then
    echo "${CFAILURE}Untrusted mirror_link rejected: ${mirror_link}${CEND}"
    echo "Use the official mirror: https://mirrors.oneinstack.com"
    return 1
  fi
}

File_SHA256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    return 1
  fi
}

File_MD5() {
  if command -v md5sum >/dev/null 2>&1; then
    md5sum "$1" | awk '{print $1}'
  elif command -v md5 >/dev/null 2>&1; then
    md5 -q "$1"
  else
    return 1
  fi
}

Verify_GPG_Signature() {
  local signed_file="$1"
  local signature_file="$2"
  local key_url="$3"
  local expected_fingerprint="$4"
  local key_file="${key_url##*/}"
  local gpg_bin
  local gpg_home
  local actual_fingerprint

  if command -v gpg >/dev/null 2>&1; then
    gpg_bin=gpg
  elif command -v gpg2 >/dev/null 2>&1; then
    gpg_bin=gpg2
  else
    echo "${CFAILURE}GnuPG is required to authenticate ${signed_file}.${CEND}"
    return 1
  fi

  src_url="${key_url}"
  Download_src no_kill || return 1
  gpg_home=$(mktemp -d /tmp/oneinstack-gpg.XXXXXX) || return 1
  chmod 0700 "${gpg_home}"

  actual_fingerprint=$("${gpg_bin}" --batch --with-colons --show-keys "${key_file}" 2>/dev/null |
    awk -F: '$1 == "fpr" {print $10; exit}')
  if [ "${actual_fingerprint}" != "${expected_fingerprint}" ] ||
    ! "${gpg_bin}" --homedir "${gpg_home}" --batch --quiet --import "${key_file}" ||
    ! "${gpg_bin}" --homedir "${gpg_home}" --batch --verify "${signature_file}" "${signed_file}"; then
    rm -rf "${gpg_home}"
    echo "${CFAILURE}GPG verification failed for ${signed_file}.${CEND}"
    return 1
  fi

  rm -rf "${gpg_home}"
  echo "${CSUCCESS}GPG signature verified: ${signed_file}${CEND}"
}

Validate_Downloaded_File() {
  local file="$1"
  local expected_sha256="$2"
  local content_name="${3:-$1}"
  local expected_md5="$4"
  local actual_sha256 normalized_expected_sha256 actual_md5 normalized_expected_md5
  local php_bin

  [ -s "${file}" ] || return 1

  case "${content_name}" in
    *.php)
      # PHP diagnostics legitimately contain HTML templates. Require an actual
      # PHP source prefix and lint the script instead of treating HTML markup as
      # an error page.
      # PHP 探针本身会包含 HTML；必须以 PHP 源码开头并通过语法检查，不能因
      # 正常的 HTML 模板而误判。
      LC_ALL=C head -c 512 "${file}" 2>/dev/null |
        LC_ALL=C grep -aEq '^[[:space:]]*<\?php([[:space:]]|$)' || return 1
      if [ -x "${php_install_dir:-}/bin/php" ]; then
        php_bin="${php_install_dir}/bin/php"
      elif command -v php >/dev/null 2>&1; then
        php_bin=$(command -v php)
      else
        echo "${CFAILURE}PHP CLI is required to validate ${content_name}.${CEND}"
        return 1
      fi
      "${php_bin}" -n -l "${file}" >/dev/null 2>&1 || return 1
      ;;
    *)
      # Error pages can be much larger than 1 KB. Never accept HTML as source
      # archives, patches, signatures, or executable data.
      # 错误页可能远大于 1 KB，源码归档、补丁、签名和可执行文件一律拒绝
      # HTML 内容。
      if LC_ALL=C head -c 4096 "${file}" 2>/dev/null |
        LC_ALL=C grep -aEiq '<!doctype[[:space:]]+html|<html([[:space:]>])|<head([[:space:]>])|<body([[:space:]>])|404[[:space:]]+not[[:space:]]+found|access[[:space:]]+denied'; then
        return 1
      fi
      ;;
  esac

  if [ -n "${expected_sha256}" ]; then
    [[ "${expected_sha256}" =~ ^[[:xdigit:]]{64}$ ]] || return 1
    actual_sha256=$(File_SHA256 "${file}") || return 1
    normalized_expected_sha256=$(printf '%s' "${expected_sha256}" | tr '[:upper:]' '[:lower:]')
    [ "${actual_sha256}" = "${normalized_expected_sha256}" ] || return 1
  fi
  if [ -n "${expected_md5}" ]; then
    [[ "${expected_md5}" =~ ^[[:xdigit:]]{32}$ ]] || return 1
    actual_md5=$(File_MD5 "${file}") || return 1
    normalized_expected_md5=$(printf '%s' "${expected_md5}" | tr '[:upper:]' '[:lower:]')
    [ "${actual_md5}" = "${normalized_expected_md5}" ] || return 1
  fi

  case "${content_name}" in
    *.tar.gz|*.tgz)
      tar tzf "${file}" >/dev/null 2>&1 || return 1
      tar tzf "${file}" 2>/dev/null |
        LC_ALL=C awk '$0 ~ /^\// || $0 ~ /(^|\/)\.\.(\/|$)/ { bad=1 } END { exit bad ? 0 : 1 }' && return 1
      ;;
    *.tar.xz)
      tar tJf "${file}" >/dev/null 2>&1 || return 1
      tar tJf "${file}" 2>/dev/null |
        LC_ALL=C awk '$0 ~ /^\// || $0 ~ /(^|\/)\.\.(\/|$)/ { bad=1 } END { exit bad ? 0 : 1 }' && return 1
      ;;
    *.tar.bz2|*.tbz2)
      tar tjf "${file}" >/dev/null 2>&1 || return 1
      tar tjf "${file}" 2>/dev/null |
        LC_ALL=C awk '$0 ~ /^\// || $0 ~ /(^|\/)\.\.(\/|$)/ { bad=1 } END { exit bad ? 0 : 1 }' && return 1
      ;;
    *.zip)
      unzip -tq "${file}" >/dev/null 2>&1 || return 1
      unzip -Z1 "${file}" 2>/dev/null |
        LC_ALL=C awk '$0 ~ /^\// || $0 ~ /(^|\/)\.\.(\/|$)/ { bad=1 } END { exit bad ? 0 : 1 }' && return 1
      ;;
  esac

  return 0
}

Download_src() {
  local requested_url="${src_url}"
  local clean_url="${requested_url%%\?*}"
  local requested_name="${src_name:-}"
  local filename="${requested_name:-${clean_url##*/}}"
  local checksum_spec="${src_checksum:-}"
  local expected_sha256 expected_md5
  local download_mode="${1:-}"
  local part_file="${filename}.part.$$"
  local url
  local urls=()

  # A checksum and an explicit filename apply to exactly one Download_src call
  # and must never leak to the next file.
  unset src_checksum src_name

  if [ -n "${checksum_spec}" ]; then
    case "${checksum_spec}" in
      sha256=*)
        expected_sha256=${checksum_spec#*=}
        ;;
      md5=*)
        expected_md5=${checksum_spec#*=}
        ;;
      *)
        echo "${CFAILURE}Unsupported checksum specification: ${checksum_spec}${CEND}"
        [ "${download_mode}" = 'no_kill' ] && return 1
        exit 1
        ;;
    esac
  fi
  if { [ -n "${expected_sha256}" ] && [ -n "${expected_md5}" ]; } ||
    { [ -n "${expected_sha256}" ] && [[ ! "${expected_sha256}" =~ ^[[:xdigit:]]{64}$ ]]; } ||
    { [ -n "${expected_md5}" ] && [[ ! "${expected_md5}" =~ ^[[:xdigit:]]{32}$ ]]; }; then
    echo "${CFAILURE}Invalid checksum for ${requested_url}.${CEND}"
    [ "${download_mode}" = 'no_kill' ] && return 1
    exit 1
  fi

  if ! Require_Trusted_Mirror; then
    [ "${download_mode}" = 'no_kill' ] && return 1
    exit 1
  fi

  case "${requested_url}" in
    https://*)
      ;;
    *)
      echo "${CFAILURE}Insecure download URL rejected: ${requested_url}${CEND}"
      [ "${download_mode}" = 'no_kill' ] && return 1
      exit 1
      ;;
  esac

  if [ -z "${filename}" ] || [ "${filename}" != "${filename##*/}" ] ||
    [ "${filename}" = '.' ] || [ "${filename}" = '..' ]; then
    echo "${CFAILURE}Unable to determine the download filename: ${requested_url}${CEND}"
    [ "${download_mode}" = 'no_kill' ] && return 1
    exit 1
  fi

  if [ -e "${filename}" ]; then
    if Validate_Downloaded_File "${filename}" "${expected_sha256}" "${filename}" "${expected_md5}"; then
      echo "[${CMSG}${filename}${CEND}] found and verified"
      return 0
    fi
    echo "${CWARNING}Removing invalid cached download: ${filename}${CEND}"
    rm -f "${filename}"
  fi

  # The requested upstream is authoritative. Only use equivalent mirrors for known projects.
  # 调用方指定的上游为权威来源，仅对已知项目添加等价镜像，不再全局劫持到 OneinStack 镜像。
  urls+=("${requested_url}")
  if [[ "${requested_url}" == *"mirrors.tuna.tsinghua.edu.cn"* ]]; then
    urls+=("${requested_url/mirrors.tuna.tsinghua.edu.cn/mirrors.ustc.edu.cn}")
  elif [[ "${requested_url}" == *"ftp.postgresql.org/pub"* ]]; then
    urls+=("${requested_url/ftp.postgresql.org\/pub/ftp.heanet.ie\/mirrors\/postgresql}")
  fi

  rm -f "${part_file}"
  for url in "${urls[@]}"; do
    echo "Downloading ${url}"
    if wget --https-only --limit-rate=100M --tries=3 --timeout=30 -O "${part_file}" "${url}" &&
      Validate_Downloaded_File "${part_file}" "${expected_sha256}" "${filename}" "${expected_md5}"; then
      mv -f "${part_file}" "${filename}"
      echo "[${CMSG}${filename}${CEND}] downloaded and verified"
      return 0
    fi
    echo "${CWARNING}Download or validation failed: ${url}${CEND}"
    rm -f "${part_file}"
  done

  echo "${CFAILURE}Auto download failed! You can manually download ${requested_url} into the oneinstack/src directory.${CEND}"
  if [ "${download_mode}" = 'no_kill' ]; then
    return 1
  fi
  exit 1
}
