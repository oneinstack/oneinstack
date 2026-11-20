#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Upgrade_PostgreSQL() {
  pushd "${oneinstack_dir}/src" > /dev/null || return 1
  if [ ! -x "${pgsql_install_dir}/bin/pg_config" ]; then
    echo "${CWARNING}PostgreSQL is not installed in ${pgsql_install_dir}! ${CEND}"
    popd > /dev/null
    return 1
  fi
  if [ ! -f "${pgsql_data_dir}/PG_VERSION" ]; then
    echo "${CWARNING}PostgreSQL data directory ${pgsql_data_dir} is not initialized! ${CEND}"
    popd > /dev/null
    return 1
  fi

  local OLD_pgsql_ver
  local OLD_pgsql_major
  local data_pgsql_major
  local Latest_pgsql_ver
  local NEW_pgsql_major
  local PACKAGE_FILE
  local pgsql_mirror_base
  local pgsql_official_base
  local expected_sha256
  local actual_sha256
  local timestamp
  local pgsql_stage_root
  local pgsql_stage_install
  local pgsql_backup_dir
  local pgsql_failed_dir
  local was_active
  local pgsql_port

  OLD_pgsql_ver=$("${pgsql_install_dir}/bin/pg_config" --version | awk '{print $2}')
  OLD_pgsql_major=$(awk -F. '{if ($1 < 10) print $1 "." $2; else print $1}' <<< "${OLD_pgsql_ver}")
  data_pgsql_major=$(awk -F. '{if ($1 < 10) print $1 "." $2; else print $1}' "${pgsql_data_dir}/PG_VERSION")
  if [ -z "${OLD_pgsql_ver}" ] || [ "${OLD_pgsql_major}" != "${data_pgsql_major}" ]; then
    echo "${CWARNING}PostgreSQL binaries and data directory versions do not match! ${CEND}"
    popd > /dev/null
    return 1
  fi

  Latest_pgsql_ver=${pgsql_ver:-${OLD_pgsql_ver}}
  echo
  echo "Current PostgreSQL Version: ${CMSG}${OLD_pgsql_ver}${CEND}"
  echo "Prepared PostgreSQL major-version targets: ${pgsql14_ver}, ${pgsql15_ver}, ${pgsql16_ver}, ${pgsql17_ver}, ${pgsql18_ver}"
  while :; do
    [ "${postgresql_flag}" != 'y' ] && read -e -p "Please input upgrade PostgreSQL Version(default: ${Latest_pgsql_ver}): " NEW_pgsql_ver
    NEW_pgsql_ver=${NEW_pgsql_ver:-${Latest_pgsql_ver}}
    if [[ ! "${NEW_pgsql_ver}" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
      echo "${CWARNING}Invalid PostgreSQL version format! ${CEND}"
      [ "${postgresql_flag}" == 'y' ] && { popd > /dev/null; return 1; }
      unset NEW_pgsql_ver
      continue
    fi

    NEW_pgsql_major=$(awk -F. '{if ($1 < 10) print $1 "." $2; else print $1}' <<< "${NEW_pgsql_ver}")
    if [ "${NEW_pgsql_major}" != "${OLD_pgsql_major}" ]; then
      PostgreSQL_Major_Upgrade "$OLD_pgsql_ver" "$NEW_pgsql_ver"
      local upgrade_status=$?
      popd > /dev/null
      return "$upgrade_status"
    fi
    if [ "${NEW_pgsql_ver}" == "${OLD_pgsql_ver}" ]; then
      echo "${CWARNING}PostgreSQL is already at ${NEW_pgsql_ver}. ${CEND}"
      popd > /dev/null
      return 0
    fi
    if [ "$(printf '%s\n' "${OLD_pgsql_ver}" "${NEW_pgsql_ver}" | sort -V | head -n 1)" != "${OLD_pgsql_ver}" ]; then
      echo "${CWARNING}Downgrading PostgreSQL is not supported by this script. ${CEND}"
      [ "${postgresql_flag}" == 'y' ] && { popd > /dev/null; return 1; }
      unset NEW_pgsql_ver
      continue
    fi

    PACKAGE_FILE=postgresql-${NEW_pgsql_ver}.tar.gz
    pgsql_mirror_base=https://mirrors.oneinstack.com/oneinstack/src
    pgsql_official_base=https://ftp.postgresql.org/pub/source/v${NEW_pgsql_ver}
    if [ ! -s "${PACKAGE_FILE}" ]; then
      if ! curl -fL --retry 2 --connect-timeout 20 -o "${PACKAGE_FILE}" "${pgsql_mirror_base}/${PACKAGE_FILE}" > /dev/null 2>&1; then
        rm -f "${PACKAGE_FILE}"
        if [ "${OUTIP_STATE}"x == "China"x ]; then
          if ! curl -fL --retry 2 --connect-timeout 20 -o "${PACKAGE_FILE}" "https://mirrors.tuna.tsinghua.edu.cn/postgresql/source/v${NEW_pgsql_ver}/${PACKAGE_FILE}" > /dev/null 2>&1; then
            rm -f "${PACKAGE_FILE}"
          fi
        fi
        if [ ! -s "${PACKAGE_FILE}" ]; then
          rm -f "${PACKAGE_FILE}"
          curl -fL --retry 2 --connect-timeout 20 -o "${PACKAGE_FILE}" "${pgsql_official_base}/${PACKAGE_FILE}" > /dev/null 2>&1
        fi
      fi
    fi
    if [ ! -s "${PACKAGE_FILE}" ] || ! gzip -t "${PACKAGE_FILE}" >/dev/null 2>&1; then
      echo "${CWARNING}PostgreSQL ${NEW_pgsql_ver} source package is unavailable or corrupt! ${CEND}"
      rm -f "${PACKAGE_FILE}"
      [ "${postgresql_flag}" == 'y' ] && { popd > /dev/null; return 1; }
      unset NEW_pgsql_ver
      continue
    fi

    if [ ! -s "${PACKAGE_FILE}.sha256" ]; then
      curl -fL --retry 2 --connect-timeout 20 -o "${PACKAGE_FILE}.sha256" "${pgsql_mirror_base}/${PACKAGE_FILE}.sha256" > /dev/null 2>&1
      if [ ! -s "${PACKAGE_FILE}.sha256" ]; then
        rm -f "${PACKAGE_FILE}.sha256"
        curl -fL --retry 2 --connect-timeout 20 -o "${PACKAGE_FILE}.sha256" "${pgsql_official_base}/${PACKAGE_FILE}.sha256" > /dev/null 2>&1
      fi
    fi
    expected_sha256=$(awk 'NR == 1 {print $1}' "${PACKAGE_FILE}.sha256" 2>/dev/null)
    actual_sha256=$(sha256sum "${PACKAGE_FILE}" 2>/dev/null | awk '{print $1}')
    if [[ ! "${expected_sha256}" =~ ^[[:xdigit:]]{64}$ ]] || [ "${actual_sha256}" != "${expected_sha256}" ]; then
      echo "${CWARNING}PostgreSQL ${NEW_pgsql_ver} SHA-256 verification failed! ${CEND}"
      rm -f "${PACKAGE_FILE}" "${PACKAGE_FILE}.sha256"
      [ "${postgresql_flag}" == 'y' ] && { popd > /dev/null; return 1; }
      unset NEW_pgsql_ver
      continue
    fi
    break
  done

  echo "Download [${CMSG}${PACKAGE_FILE}${CEND}] verified successfully."
  if [ "${postgresql_flag}" != 'y' ]; then
    echo "PostgreSQL minor updates keep the existing data directory. The old program directory will be retained for rollback."
    echo "Press Ctrl+c to cancel or Press any key to continue..."
    char=$(get_char)
  fi

  if [ ! -d "${pgsql_install_dir}" ] || [ "${pgsql_install_dir#/}" = "${pgsql_install_dir}" ]; then
    echo "${CWARNING}PostgreSQL install directory must be an existing absolute path! ${CEND}"
    popd > /dev/null
    return 1
  fi

  tar xzf "${PACKAGE_FILE}" || { popd > /dev/null; return 1; }
  pushd "postgresql-${NEW_pgsql_ver}" > /dev/null || { popd > /dev/null; return 1; }
  ./configure --prefix="${pgsql_install_dir}" --with-openssl --with-libxml --with-libxslt --with-icu
  if [ $? -ne 0 ]; then
    echo "${CFAILURE}PostgreSQL configure failed! ${CEND}"
    popd > /dev/null
    popd > /dev/null
    return 1
  fi
  make -j "${THREAD:-1}"
  if [ $? -ne 0 ]; then
    echo "${CFAILURE}PostgreSQL make failed! ${CEND}"
    popd > /dev/null
    popd > /dev/null
    return 1
  fi

  timestamp=$(date +%Y%m%d_%H%M%S)
  pgsql_stage_root=${pgsql_install_dir}.stage_${timestamp}
  pgsql_stage_install=${pgsql_stage_root}${pgsql_install_dir}
  pgsql_backup_dir=${pgsql_install_dir}_old_${timestamp}
  pgsql_failed_dir=${pgsql_install_dir}_failed_${timestamp}
  if [ -e "${pgsql_stage_root}" ] || [ -e "${pgsql_backup_dir}" ] || [ -e "${pgsql_failed_dir}" ]; then
    echo "${CFAILURE}PostgreSQL upgrade staging path already exists! ${CEND}"
    popd > /dev/null
    popd > /dev/null
    return 1
  fi
  mkdir -p "${pgsql_stage_install}"
  cp -a "${pgsql_install_dir}/." "${pgsql_stage_install}/"
  if [ $? -ne 0 ]; then
    echo "${CFAILURE}Unable to stage the existing PostgreSQL install directory! ${CEND}"
    rm -rf "${pgsql_stage_root}"
    popd > /dev/null
    popd > /dev/null
    return 1
  fi
  make DESTDIR="${pgsql_stage_root}" install
  if [ $? -ne 0 ] || [ ! -x "${pgsql_stage_install}/bin/postgres" ]; then
    echo "${CFAILURE}PostgreSQL staged install failed! ${CEND}"
    rm -rf "${pgsql_stage_root}"
    popd > /dev/null
    popd > /dev/null
    return 1
  fi
  if [ "`${pgsql_stage_install}/bin/postgres --version | awk '{print $3}'`" != "${NEW_pgsql_ver}" ]; then
    echo "${CFAILURE}Staged PostgreSQL binaries do not match ${NEW_pgsql_ver}! ${CEND}"
    rm -rf "${pgsql_stage_root}"
    popd > /dev/null
    popd > /dev/null
    return 1
  fi
  chown -R postgres:postgres "${pgsql_stage_install}"
  if [ $? -ne 0 ]; then
    echo "${CFAILURE}Unable to set PostgreSQL install ownership! ${CEND}"
    rm -rf "${pgsql_stage_root}"
    popd > /dev/null
    popd > /dev/null
    return 1
  fi
  popd > /dev/null

  was_active=n
  systemctl is-active --quiet postgresql && was_active=y
  if ! systemctl stop postgresql; then
    echo "${CFAILURE}Unable to stop PostgreSQL; leaving the current install untouched. ${CEND}"
    rm -rf "${pgsql_stage_root}"
    [ "${was_active}" == 'y' ] && systemctl start postgresql
    popd > /dev/null
    return 1
  fi
  if ! mv "${pgsql_install_dir}" "${pgsql_backup_dir}"; then
    echo "${CFAILURE}Unable to preserve the current PostgreSQL install directory. ${CEND}"
    rm -rf "${pgsql_stage_root}"
    [ "${was_active}" == 'y' ] && systemctl start postgresql
    popd > /dev/null
    return 1
  fi
  if ! mv "${pgsql_stage_install}" "${pgsql_install_dir}"; then
    mv "${pgsql_backup_dir}" "${pgsql_install_dir}"
    rm -rf "${pgsql_stage_root}"
    [ "${was_active}" == 'y' ] && systemctl start postgresql
    echo "${CFAILURE}Unable to activate the new PostgreSQL binaries; restored the previous install. ${CEND}"
    popd > /dev/null
    return 1
  fi
  rm -rf "${pgsql_stage_root}"

  if [ "${was_active}" == 'y' ]; then
    pgsql_port=$(sed -n 's/^[[:space:]]*port[[:space:]]*=[[:space:]]*\([0-9][0-9]*\).*/\1/p' "${pgsql_data_dir}/postgresql.conf" | head -n 1)
    pgsql_port=${pgsql_port:-5432}
    if ! systemctl start postgresql || ! systemctl is-active --quiet postgresql || ! "${pgsql_install_dir}/bin/pg_isready" -q -h 127.0.0.1 -p "${pgsql_port}"; then
      systemctl stop postgresql >/dev/null 2>&1
      if mv "${pgsql_install_dir}" "${pgsql_failed_dir}" && mv "${pgsql_backup_dir}" "${pgsql_install_dir}"; then
        systemctl start postgresql
        echo "${CFAILURE}PostgreSQL ${NEW_pgsql_ver} did not pass startup checks; restored the previous binaries from ${pgsql_backup_dir}. ${CEND}"
      else
        echo "${CFAILURE}PostgreSQL startup failed and automatic rollback was incomplete. Keep ${pgsql_backup_dir} for manual recovery. ${CEND}"
      fi
      popd > /dev/null
      return 1
    fi
  fi

  rm -rf "postgresql-${NEW_pgsql_ver}"
  echo "You have ${CMSG}successfully${CEND} upgraded PostgreSQL from ${CMSG}${OLD_pgsql_ver}${CEND} to ${CMSG}${NEW_pgsql_ver}${CEND}."
  echo "Previous binaries are preserved in ${CMSG}${pgsql_backup_dir}${CEND}. PostgreSQL data remains in ${CMSG}${pgsql_data_dir}${CEND}."
  popd > /dev/null
}
