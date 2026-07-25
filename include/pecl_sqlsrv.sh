#!/bin/bash
# Microsoft Drivers for PHP for SQL Server.
# The PECL sources are checksum-pinned in versions.txt. ODBC 18 is installed
# only from Microsoft's HTTPS repository after its signing key fingerprint and
# repository definition have been validated.

Verify_Microsoft_Repository_Key() {
  local key_file="$1"
  local expected_fingerprint="$2"
  local actual_fingerprint

  actual_fingerprint=$(gpg --batch --with-colons --show-keys "${key_file}" 2>/dev/null |
    awk -F: '$1 == "fpr" { print toupper($10); exit }')
  if [ "${actual_fingerprint}" != "${expected_fingerprint}" ]; then
    echo "${CFAILURE}Microsoft repository key fingerprint mismatch.${CEND}"
    echo "Expected: ${expected_fingerprint}"
    echo "Actual:   ${actual_fingerprint:-unavailable}"
    return 1
  fi
}

Select_Microsoft_Repository_Key() {
  case "${Platform}" in
    debian)
      if [ "${VERSION_MAIN_ID:-0}" -ge 13 ]; then
        microsoft_repo_key_url=${microsoft_repo_2025_gpg_key}
        microsoft_repo_key_fingerprint=${microsoft_repo_2025_gpg_finger}
      else
        microsoft_repo_key_url=${microsoft_repo_legacy_gpg_key}
        microsoft_repo_key_fingerprint=${microsoft_repo_legacy_gpg_finger}
      fi
      ;;
    ubuntu)
      if dpkg --compare-versions "${VERSION_ID}" ge 25.10; then
        microsoft_repo_key_url=${microsoft_repo_2025_gpg_key}
        microsoft_repo_key_fingerprint=${microsoft_repo_2025_gpg_finger}
      else
        microsoft_repo_key_url=${microsoft_repo_legacy_gpg_key}
        microsoft_repo_key_fingerprint=${microsoft_repo_legacy_gpg_finger}
      fi
      ;;
    rhel)
      if [ "${RHEL_ver:-0}" -ge 10 ]; then
        microsoft_repo_key_url=${microsoft_repo_2025_gpg_key}
        microsoft_repo_key_fingerprint=${microsoft_repo_2025_gpg_finger}
      else
        microsoft_repo_key_url=${microsoft_repo_legacy_gpg_key}
        microsoft_repo_key_fingerprint=${microsoft_repo_legacy_gpg_finger}
      fi
      ;;
    *)
      echo "${CFAILURE}Microsoft ODBC repository is not enabled for ${Platform}.${CEND}"
      echo "Supported official repository targets: Debian, Ubuntu and RHEL."
      return 1
      ;;
  esac
}

Install_Microsoft_ODBC_APT() {
  local key_file="$1"
  local repo_file repo_line installed_repo
  local keyring=/usr/share/keyrings/microsoft-prod.gpg

  repo_file="microsoft-prod-${Platform}-${VERSION_ID}.list"
  src_url="https://packages.microsoft.com/config/${Platform}/${VERSION_ID}/prod.list"
  src_name=${repo_file}
  Download_src no_kill || return 1

  repo_line=$(sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "${repo_file}")
  if [ "$(printf '%s\n' "${repo_line}" | wc -l)" -ne 1 ] ||
    ! printf '%s\n' "${repo_line}" |
      grep -Eq "^deb( \\[[^]]+\\])? https://packages\\.microsoft\\.com/${Platform}/${VERSION_ID}/prod [^[:space:]]+ main$"; then
    echo "${CFAILURE}Unexpected Microsoft APT repository definition.${CEND}"
    return 1
  fi
  printf '%s\n' "${repo_line}" |
    grep -Eqi '(trusted|allow-insecure|allow-weak|allow-downgrade-to-insecure)=(yes|true)' && {
    echo "${CFAILURE}Unsigned Microsoft APT repository definition rejected.${CEND}"
    return 1
  }

  gpg --batch --yes --dearmor --output "${keyring}" "${key_file}" ||
    return 1
  chmod 0644 "${keyring}"

  installed_repo=$(printf '%s\n' "${repo_line}" |
    sed -E "s#signed-by=[^] ]+#signed-by=${keyring}#")
  if ! printf '%s\n' "${installed_repo}" | grep -q 'signed-by='; then
    installed_repo=$(printf '%s\n' "${installed_repo}" |
      sed "s#^deb #deb [signed-by=${keyring}] #")
  fi
  printf '%s\n' "${installed_repo}" \
    > /etc/apt/sources.list.d/microsoft-prod.list || return 1

  apt-get update || return 1
  ACCEPT_EULA=Y DEBIAN_FRONTEND=noninteractive \
    apt-get --no-install-recommends -y install msodbcsql18 || return 1
}

Install_Microsoft_ODBC_RPM() {
  local key_file="$1"
  local repo_file=microsoft-prod.repo
  local key_path=/etc/pki/rpm-gpg/MICROSOFT-RPM-GPG-KEY

  src_url="https://packages.microsoft.com/config/rhel/${RHEL_ver}/prod.repo"
  src_name=${repo_file}
  Download_src no_kill || return 1
  if [ "$(grep -Ec '^baseurl=' "${repo_file}")" -ne 1 ] ||
    [ "$(grep -Ec '^gpgcheck=' "${repo_file}")" -ne 1 ] ||
    [ "$(grep -Ec '^repo_gpgcheck=' "${repo_file}")" -ne 1 ] ||
    ! grep -Eq '^baseurl=https://packages\.microsoft\.com/rhel/[0-9]+/prod/?$' \
      "${repo_file}" ||
    ! grep -Eq '^gpgcheck=1$' "${repo_file}" ||
    ! grep -Eq '^repo_gpgcheck=1$' "${repo_file}"; then
    echo "${CFAILURE}Unexpected Microsoft RPM repository definition.${CEND}"
    return 1
  fi
  if grep -E '^baseurl=' "${repo_file}" |
    grep -Ev '^baseurl=https://packages\.microsoft\.com/' |
    grep -q .; then
    echo "${CFAILURE}Untrusted Microsoft RPM repository URL rejected.${CEND}"
    return 1
  fi

  install -m 0644 "${key_file}" "${key_path}" || return 1
  sed -E \
    "s#^gpgkey=.*#gpgkey=file://${key_path}#" \
    "${repo_file}" > /etc/yum.repos.d/microsoft-prod.repo || return 1
  grep -q '^sslverify=' /etc/yum.repos.d/microsoft-prod.repo ||
    echo 'sslverify=1' >> /etc/yum.repos.d/microsoft-prod.repo

  ACCEPT_EULA=Y yum -y install msodbcsql18 || return 1
}

Install_Microsoft_ODBC() {
  local key_file

  Select_Microsoft_Repository_Key || return 1
  case "${Platform}" in
    debian|ubuntu)
      apt-get --no-install-recommends -y install ca-certificates gnupg g++ \
        unixodbc-dev || return 1
      ;;
    rhel)
      yum -y install ca-certificates gnupg2 gcc-c++ unixODBC-devel ||
        return 1
      ;;
  esac

  (
    cd "${oneinstack_dir}/src" || return 1
    key_file="microsoft-repository-$(basename "${microsoft_repo_key_url}")"
    src_url=${microsoft_repo_key_url}
    src_name=${key_file}
    Download_src no_kill || return 1

    Verify_Microsoft_Repository_Key "${key_file}" \
      "${microsoft_repo_key_fingerprint}" || return 1

    case "${Platform}" in
      debian|ubuntu)
        Install_Microsoft_ODBC_APT "${key_file}"
        ;;
      rhel)
        Install_Microsoft_ODBC_RPM "${key_file}"
        ;;
    esac
  )
}

Build_pecl_sqlsrv_extension() {
  local extension_name="$1"
  local extension_version="$2"

  (
    cd "${oneinstack_dir}/src" || return 1
    rm -rf "${extension_name}-${extension_version}"
    tar xzf "${extension_name}-${extension_version}.tgz" || return 1
    cd "${extension_name}-${extension_version}" || return 1
    "${php_install_dir}/bin/phpize" || return 1
    ./configure --with-php-config="${php_install_dir}/bin/php-config" ||
      return 1
    make -j "${THREAD}" && make install
  )
}

Install_pecl_sqlsrv() {
  local php_version_id php_extension_dir

  if [ ! -x "${php_install_dir}/bin/phpize" ] ||
    [ ! -x "${php_install_dir}/bin/php-config" ]; then
    echo "${CFAILURE}PHP phpize and php-config are required to install sqlsrv.${CEND}"
    return 1
  fi

  php_version_id=$("${php_install_dir}/bin/php-config" --version |
    awk -F. '{ print ($1 * 100) + $2 }')
  if [ "${php_version_id:-0}" -lt 803 ]; then
    echo "${CFAILURE}sqlsrv ${sqlsrv_ver} requires PHP 8.3 or newer.${CEND}"
    return 1
  fi

  Install_Microsoft_ODBC || return 1

  (
    cd "${oneinstack_dir}/src" || return 1
    src_url="https://pecl.php.net/get/sqlsrv-${sqlsrv_ver}.tgz"
    src_checksum=${sqlsrv_checksum:-}
    Download_src no_kill || return 1
    src_url="https://pecl.php.net/get/pdo_sqlsrv-${pdo_sqlsrv_ver}.tgz"
    src_checksum=${pdo_sqlsrv_checksum:-}
    Download_src no_kill
  ) || return 1

  Build_pecl_sqlsrv_extension sqlsrv "${sqlsrv_ver}" || return 1
  Build_pecl_sqlsrv_extension pdo_sqlsrv "${pdo_sqlsrv_ver}" || return 1

  php_extension_dir=$("${php_install_dir}/bin/php-config" --extension-dir) ||
    return 1
  if [ -f "${php_extension_dir}/sqlsrv.so" ] &&
    [ -f "${php_extension_dir}/pdo_sqlsrv.so" ]; then
    {
      echo 'extension=sqlsrv.so'
      echo 'extension=pdo_sqlsrv.so'
    } > "${php_install_dir}/etc/php.d/07-sqlsrv.ini"
    echo "${CSUCCESS}PHP sqlsrv and pdo_sqlsrv modules installed successfully! ${CEND}"
    return 0
  fi

  echo "${CFAILURE}PHP sqlsrv modules were not installed.${CEND}"
  return 1
}

Uninstall_pecl_sqlsrv() {
  if [ -e "${php_install_dir}/etc/php.d/07-sqlsrv.ini" ]; then
    rm -f "${php_install_dir}/etc/php.d/07-sqlsrv.ini"
    echo
    echo "${CMSG}PHP sqlsrv and pdo_sqlsrv modules uninstall completed${CEND}"
  else
    echo
    echo "${CWARNING}PHP sqlsrv modules do not exist! ${CEND}"
  fi
}
