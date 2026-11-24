#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

PostgreSQL_Add_Upgrade_Peer_Rule() {
  local pgsql_hba_file="$1"
  local pgsql_hba_tmp="$pgsql_hba_file.oneinstack_upgrade"

  {
    printf '%s\n' 'local all postgres peer'
    cat "$pgsql_hba_file"
  } > "$pgsql_hba_tmp" || return 1
  chown --reference="$pgsql_hba_file" "$pgsql_hba_tmp" || return 1
  chmod --reference="$pgsql_hba_file" "$pgsql_hba_tmp" || return 1
  cat "$pgsql_hba_tmp" > "$pgsql_hba_file" || return 1
  rm -f "$pgsql_hba_tmp"
}

PostgreSQL_Restore_Original_HBA() {
  local pgsql_hba_backup="$1"
  local pgsql_hba_file="$2"

  [ -s "$pgsql_hba_backup" ] || return 1
  cat "$pgsql_hba_backup" > "$pgsql_hba_file"
}

PostgreSQL_Major_Upgrade() {
  local OLD_pgsql_ver="$1"
  local NEW_pgsql_ver="$2"
  local OLD_pgsql_major
  local NEW_pgsql_major
  local PACKAGE_FILE
  local package_dir
  local package_path
  local pgsql_mirror_base
  local pgsql_official_base
  local expected_sha256
  local actual_sha256
  local timestamp
  local stage_root
  local stage_install
  local old_install_backup
  local old_data_backup
  local old_hba_backup
  local new_data_dir
  local failed_install
  local failed_data
  local work_dir
  local was_active=n
  local pgsql_port
  local pgsql_listen_addresses
  local pgsql_listen_escaped
  local pgsql_socket_dir
  local pgsql_socket_escaped
  local pgsql_checksum_version
  local pgsql_no_checksum_supported
  local postgres_home
  local jobs
  local confirm_upgrade

  OLD_pgsql_major=$(awk -F. '{if ($1 < 10) print $1 "." $2; else print $1}' <<< "$OLD_pgsql_ver")
  NEW_pgsql_major=$(awk -F. '{if ($1 < 10) print $1 "." $2; else print $1}' <<< "$NEW_pgsql_ver")

  case "$NEW_pgsql_ver" in
    "$pgsql14_ver"|"$pgsql15_ver"|"$pgsql16_ver"|"$pgsql17_ver"|"$pgsql18_ver") ;;
    *)
      echo "${CWARNING}OneinStack currently supports PostgreSQL major upgrades to: $pgsql14_ver, $pgsql15_ver, $pgsql16_ver, $pgsql17_ver, $pgsql18_ver.${CEND}"
      echo "No installation files or database data were changed."
      echo "Official PostgreSQL $NEW_pgsql_major upgrade guide: https://www.postgresql.org/docs/$NEW_pgsql_major/upgrading.html"
      echo "Official pg_upgrade guide: https://www.postgresql.org/docs/$NEW_pgsql_major/pgupgrade.html"
      return 1
      ;;
  esac

  if [ "$(printf '%s\n' "$OLD_pgsql_ver" "$NEW_pgsql_ver" | sort -V | head -n 1)" != "$OLD_pgsql_ver" ]; then
    echo "${CWARNING}Downgrading PostgreSQL is not supported. No installation files or database data were changed.${CEND}"
    return 1
  fi
  if [ "$NEW_pgsql_major" == '14' ]; then
    echo "${CWARNING}PostgreSQL 14 reached end of support on 2026-11-12. Upgrading into 14 is not recommended.${CEND}"
  fi

  PACKAGE_FILE="postgresql-$NEW_pgsql_ver.tar.gz"
  package_dir="$oneinstack_dir/packages/postgresql/$NEW_pgsql_ver"
  package_path="$package_dir/$PACKAGE_FILE"
  pgsql_mirror_base="${mirror_link:-https://cdn.oneinstack.com}/oneinstack/src"
  pgsql_official_base="https://ftp.postgresql.org/pub/source/v$NEW_pgsql_ver"

  if [ ! -s "$PACKAGE_FILE" ] && [ -s "$package_path" ]; then
    cp "$package_path" "$PACKAGE_FILE"
  fi
  if [ ! -s "$PACKAGE_FILE" ]; then
    if ! curl -fL --retry 2 --connect-timeout 20 -o "$PACKAGE_FILE" "$pgsql_mirror_base/$PACKAGE_FILE" > /dev/null 2>&1; then
      rm -f "$PACKAGE_FILE"
      if [ "$OUTIP_STATE"x == "China"x ]; then
        curl -fL --retry 2 --connect-timeout 20 -o "$PACKAGE_FILE" "https://mirrors.tuna.tsinghua.edu.cn/postgresql/source/v$NEW_pgsql_ver/$PACKAGE_FILE" > /dev/null 2>&1 || rm -f "$PACKAGE_FILE"
      fi
      if [ ! -s "$PACKAGE_FILE" ]; then
        curl -fL --retry 2 --connect-timeout 20 -o "$PACKAGE_FILE" "$pgsql_official_base/$PACKAGE_FILE" > /dev/null 2>&1 || rm -f "$PACKAGE_FILE"
      fi
    fi
  fi
  if [ ! -s "$PACKAGE_FILE" ] || ! gzip -t "$PACKAGE_FILE" >/dev/null 2>&1; then
    echo "${CWARNING}PostgreSQL $NEW_pgsql_ver source package is unavailable or corrupt.${CEND}"
    rm -f "$PACKAGE_FILE"
    return 1
  fi

  if [ ! -s "$PACKAGE_FILE.sha256" ] && [ -s "$package_path.sha256" ]; then
    cp "$package_path.sha256" "$PACKAGE_FILE.sha256"
  fi
  if [ ! -s "$PACKAGE_FILE.sha256" ]; then
    curl -fL --retry 2 --connect-timeout 20 -o "$PACKAGE_FILE.sha256" "$pgsql_mirror_base/$PACKAGE_FILE.sha256" > /dev/null 2>&1 || rm -f "$PACKAGE_FILE.sha256"
    if [ ! -s "$PACKAGE_FILE.sha256" ]; then
      curl -fL --retry 2 --connect-timeout 20 -o "$PACKAGE_FILE.sha256" "$pgsql_official_base/$PACKAGE_FILE.sha256" > /dev/null 2>&1 || rm -f "$PACKAGE_FILE.sha256"
    fi
  fi
  expected_sha256=$(awk 'NR == 1 {print $1}' "$PACKAGE_FILE.sha256" 2>/dev/null | tr '[:upper:]' '[:lower:]')
  actual_sha256=$(sha256sum "$PACKAGE_FILE" 2>/dev/null | awk '{print $1}')
  if [[ ! "$expected_sha256" =~ ^[[:xdigit:]]{64}$ ]] || [ "$actual_sha256" != "$expected_sha256" ]; then
    echo "${CWARNING}PostgreSQL $NEW_pgsql_ver SHA-256 verification failed.${CEND}"
    rm -f "$PACKAGE_FILE" "$PACKAGE_FILE.sha256"
    return 1
  fi

  if ! id postgres >/dev/null 2>&1; then
    echo "${CWARNING}The postgres operating-system account does not exist.${CEND}"
    return 1
  fi
  if [ ! -d "$pgsql_install_dir" ] || [ ! -d "$pgsql_data_dir" ]; then
    echo "${CWARNING}PostgreSQL install or data directory is missing.${CEND}"
    return 1
  fi

  timestamp=$(date +%Y%m%d_%H%M%S)
  stage_root="$pgsql_install_dir".stage_"$timestamp"
  stage_install="$stage_root$pgsql_install_dir"
  old_install_backup="$pgsql_install_dir"_old_"$timestamp"
  old_data_backup="$pgsql_data_dir"_old_"$timestamp"
  new_data_dir="$pgsql_data_dir".new_"$timestamp"
  failed_install="$pgsql_install_dir"_failed_"$timestamp"
  failed_data="$pgsql_data_dir"_failed_"$timestamp"
  work_dir="$pgsql_data_dir".upgrade_"$timestamp"
  old_hba_backup="$work_dir/pg_hba.conf.original"
  jobs=$THREAD
  [ -n "$jobs" ] || jobs=1
  postgres_home=$(getent passwd postgres | awk -F: '{print $6}')
  [ -n "$postgres_home" ] || postgres_home=$pgsql_install_dir

  if [ -e "$stage_root" ] || [ -e "$old_install_backup" ] || [ -e "$old_data_backup" ] || [ -e "$new_data_dir" ] || [ -e "$failed_install" ] || [ -e "$failed_data" ] || [ -e "$work_dir" ]; then
    echo "${CFAILURE}A PostgreSQL upgrade staging or backup path already exists.${CEND}"
    return 1
  fi

  echo "Preparing PostgreSQL $NEW_pgsql_ver binaries. The existing database will be stopped for compatibility checking and migration."
  echo "pg_upgrade will use its default copy mode. The old data directory and binaries will be preserved for rollback."
  echo "Ensure you have a separate backup and sufficient free disk space before continuing."
  if [ "$postgresql_flag" != 'y' ]; then
    read -r -p "Type UPGRADE to continue: " confirm_upgrade
    [ "$confirm_upgrade" == 'UPGRADE' ] || { echo "Upgrade cancelled."; return 1; }
  fi

  tar xzf "$PACKAGE_FILE" || return 1
  if [ ! -d "postgresql-$NEW_pgsql_ver" ]; then
    echo "${CFAILURE}PostgreSQL source archive did not contain the expected directory.${CEND}"
    return 1
  fi
  mkdir -p "$stage_install" || return 1
  if ! (cd "postgresql-$NEW_pgsql_ver" && ./configure --prefix="$pgsql_install_dir" --with-openssl --with-libxml --with-libxslt --with-icu && make -j "$jobs" && make DESTDIR="$stage_root" install); then
    echo "${CFAILURE}PostgreSQL $NEW_pgsql_ver build or staged install failed. The running installation and database were not changed.${CEND}"
    rm -rf "$stage_root"
    return 1
  fi
  if [ ! -x "$stage_install/bin/pg_upgrade" ] || [ "$("$stage_install/bin/postgres" --version | awk '{print $3}')" != "$NEW_pgsql_ver" ]; then
    echo "${CFAILURE}Staged PostgreSQL binaries do not match $NEW_pgsql_ver.${CEND}"
    rm -rf "$stage_root"
    return 1
  fi
  chown -R postgres:postgres "$stage_install" || { rm -rf "$stage_root"; return 1; }

  pgsql_port=$(runuser -u postgres -- env HOME="$postgres_home" "$pgsql_install_dir/bin/postgres" -D "$pgsql_data_dir" -C port 2>/dev/null)
  pgsql_listen_addresses=$(runuser -u postgres -- env HOME="$postgres_home" "$pgsql_install_dir/bin/postgres" -D "$pgsql_data_dir" -C listen_addresses 2>/dev/null)
  pgsql_socket_dir=$(runuser -u postgres -- env HOME="$postgres_home" "$pgsql_install_dir/bin/postgres" -D "$pgsql_data_dir" -C unix_socket_directories 2>/dev/null | awk -F, '{print $1}' | sed "s/^['\"]//;s/['\"]$//;s/^ *//;s/ *$//")
  pgsql_checksum_version=$(runuser -u postgres -- env HOME="$postgres_home" "$pgsql_install_dir/bin/pg_controldata" -D "$pgsql_data_dir" 2>/dev/null | awk -F: '/Data page checksum version:/ {gsub(/[[:space:]]/, "", $2); print $2}')
  [[ "$pgsql_port" =~ ^[0-9]+$ ]] || pgsql_port=5432
  [ -n "$pgsql_listen_addresses" ] || pgsql_listen_addresses=localhost
  [ -n "$pgsql_socket_dir" ] || pgsql_socket_dir=/tmp
  if [[ ! "$pgsql_checksum_version" =~ ^[0-9]+$ ]]; then
    echo "${CFAILURE}Could not read the existing cluster's data checksum setting; no upgrade was started.${CEND}"
    rm -rf "$stage_root"
    return 1
  fi

  systemctl is-active --quiet postgresql && was_active=y
  if ! systemctl stop postgresql; then
    echo "${CFAILURE}Unable to stop PostgreSQL; the current installation and data were left in place.${CEND}"
    rm -rf "$stage_root"
    [ "$was_active" == 'y' ] && systemctl start postgresql
    return 1
  fi
  if ! mv "$pgsql_install_dir" "$old_install_backup" || ! mv "$stage_install" "$pgsql_install_dir"; then
    [ ! -e "$pgsql_install_dir" ] && [ -e "$old_install_backup" ] && mv "$old_install_backup" "$pgsql_install_dir"
    echo "${CFAILURE}Unable to activate the staged PostgreSQL binaries; restored the previous installation where possible.${CEND}"
    rm -rf "$stage_root"
    [ "$was_active" == 'y' ] && systemctl start postgresql
    return 1
  fi
  rm -rf "$stage_root"

  mkdir -p "$new_data_dir" "$work_dir"
  chown postgres:postgres "$new_data_dir" "$work_dir"
  chmod 700 "$work_dir"
  pgsql_no_checksum_supported=n
  "$pgsql_install_dir/bin/initdb" --help 2>&1 | grep -q -- '--no-data-checksums' && pgsql_no_checksum_supported=y
  if [ "$pgsql_checksum_version" -gt 0 ]; then
    runuser -u postgres -- env HOME="$postgres_home" "$pgsql_install_dir/bin/initdb" --data-checksums -D "$new_data_dir"
  elif [ "$pgsql_no_checksum_supported" == 'y' ]; then
    runuser -u postgres -- env HOME="$postgres_home" "$pgsql_install_dir/bin/initdb" --no-data-checksums -D "$new_data_dir"
  else
    runuser -u postgres -- env HOME="$postgres_home" "$pgsql_install_dir/bin/initdb" -D "$new_data_dir"
  fi
  if [ $? -ne 0 ]; then
    echo "${CFAILURE}Could not initialize the new PostgreSQL cluster. Restoring the previous binaries.${CEND}"
    mv "$pgsql_install_dir" "$failed_install"
    mv "$old_install_backup" "$pgsql_install_dir"
    [ "$was_active" == 'y' ] && systemctl start postgresql
    echo "The failed new cluster is preserved at $new_data_dir."
    return 1
  fi

  if ! cp "$pgsql_data_dir/pg_hba.conf" "$old_hba_backup"; then
    echo "${CFAILURE}Could not save the existing pg_hba.conf; restoring the previous binaries.${CEND}"
    mv "$pgsql_install_dir" "$failed_install"
    mv "$old_install_backup" "$pgsql_install_dir"
    [ "$was_active" == 'y' ] && systemctl start postgresql
    return 1
  fi
  chown postgres:postgres "$old_hba_backup"
  chmod 600 "$old_hba_backup"
  if ! PostgreSQL_Add_Upgrade_Peer_Rule "$pgsql_data_dir/pg_hba.conf"; then
    PostgreSQL_Restore_Original_HBA "$old_hba_backup" "$pgsql_data_dir/pg_hba.conf"
    mv "$pgsql_install_dir" "$failed_install"
    mv "$old_install_backup" "$pgsql_install_dir"
    [ "$was_active" == 'y' ] && systemctl start postgresql
    echo "${CFAILURE}Could not temporarily enable local peer authentication for pg_upgrade.${CEND}"
    return 1
  fi

  echo "Checking PostgreSQL cluster compatibility. This does not migrate or modify the old data."
  if ! (cd "$work_dir" && runuser -u postgres -- env HOME="$postgres_home" "$pgsql_install_dir/bin/pg_upgrade" -b "$old_install_backup/bin" -B "$pgsql_install_dir/bin" -d "$pgsql_data_dir" -D "$new_data_dir" -U postgres -j "$jobs" --check --socketdir="$work_dir"); then
    PostgreSQL_Restore_Original_HBA "$old_hba_backup" "$pgsql_data_dir/pg_hba.conf"
    mv "$pgsql_install_dir" "$failed_install"
    mv "$old_install_backup" "$pgsql_install_dir"
    [ "$was_active" == 'y' ] && systemctl start postgresql
    echo "${CFAILURE}pg_upgrade compatibility check failed. The old data directory was not changed.${CEND}"
    echo "The new cluster and diagnostics are preserved at $new_data_dir and $work_dir."
    echo "Official PostgreSQL upgrade guide: https://www.postgresql.org/docs/$NEW_pgsql_major/upgrading.html"
    echo "Official pg_upgrade guide: https://www.postgresql.org/docs/$NEW_pgsql_major/pgupgrade.html"
    return 1
  fi

  if ! mv "$pgsql_data_dir" "$old_data_backup" || ! mv "$new_data_dir" "$pgsql_data_dir"; then
    [ -e "$pgsql_data_dir/pg_hba.conf" ] && PostgreSQL_Restore_Original_HBA "$old_hba_backup" "$pgsql_data_dir/pg_hba.conf"
    [ -e "$old_data_backup/pg_hba.conf" ] && PostgreSQL_Restore_Original_HBA "$old_hba_backup" "$old_data_backup/pg_hba.conf"
    [ ! -e "$pgsql_data_dir" ] && [ -e "$old_data_backup" ] && mv "$old_data_backup" "$pgsql_data_dir"
    mv "$pgsql_install_dir" "$failed_install"
    mv "$old_install_backup" "$pgsql_install_dir"
    [ "$was_active" == 'y' ] && systemctl start postgresql
    echo "${CFAILURE}Unable to prepare the destination data directory; restored the previous cluster.${CEND}"
    return 1
  fi

  echo "Migrating the database with pg_upgrade in copy mode..."
  if ! (cd "$work_dir" && runuser -u postgres -- env HOME="$postgres_home" "$pgsql_install_dir/bin/pg_upgrade" -b "$old_install_backup/bin" -B "$pgsql_install_dir/bin" -d "$old_data_backup" -D "$pgsql_data_dir" -U postgres -j "$jobs" --socketdir="$work_dir"); then
    systemctl stop postgresql >/dev/null 2>&1
    PostgreSQL_Restore_Original_HBA "$old_hba_backup" "$old_data_backup/pg_hba.conf"
    mv "$pgsql_data_dir" "$failed_data"
    mv "$old_data_backup" "$pgsql_data_dir"
    mv "$pgsql_install_dir" "$failed_install"
    mv "$old_install_backup" "$pgsql_install_dir"
    [ "$was_active" == 'y' ] && systemctl start postgresql
    echo "${CFAILURE}pg_upgrade failed. The old data and binaries were restored; the failed destination is preserved at $failed_data.${CEND}"
    echo "Diagnostics are preserved at $work_dir."
    return 1
  fi

  if ! PostgreSQL_Restore_Original_HBA "$old_hba_backup" "$old_data_backup/pg_hba.conf" || ! cp "$old_hba_backup" "$pgsql_data_dir/pg_hba.conf"; then
    mv "$pgsql_data_dir" "$failed_data"
    mv "$old_data_backup" "$pgsql_data_dir"
    mv "$pgsql_install_dir" "$failed_install"
    mv "$old_install_backup" "$pgsql_install_dir"
    [ "$was_active" == 'y' ] && systemctl start postgresql
    echo "${CFAILURE}Could not restore PostgreSQL authentication settings; the previous cluster was restored.${CEND}"
    return 1
  fi
  pgsql_listen_escaped=$(printf '%s' "$pgsql_listen_addresses" | sed "s/'/''/g")
  pgsql_socket_escaped=$(printf '%s' "$pgsql_socket_dir" | sed "s/'/''/g")
  if ! sed -i '/^[[:space:]]*listen_addresses[[:space:]]*=/d;/^[[:space:]]*port[[:space:]]*=/d;/^[[:space:]]*unix_socket_directories[[:space:]]*=/d' "$pgsql_data_dir/postgresql.conf" || ! printf "\nlisten_addresses = '%s'\nport = %s\nunix_socket_directories = '%s'\n" "$pgsql_listen_escaped" "$pgsql_port" "$pgsql_socket_escaped" >> "$pgsql_data_dir/postgresql.conf" || ! chown postgres:postgres "$pgsql_data_dir/postgresql.conf" "$pgsql_data_dir/pg_hba.conf"; then
    mv "$pgsql_data_dir" "$failed_data"
    mv "$old_data_backup" "$pgsql_data_dir"
    mv "$pgsql_install_dir" "$failed_install"
    mv "$old_install_backup" "$pgsql_install_dir"
    [ "$was_active" == 'y' ] && systemctl start postgresql
    echo "${CFAILURE}Could not restore PostgreSQL configuration; the previous cluster was restored.${CEND}"
    return 1
  fi

  if ! systemctl start postgresql || ! systemctl is-active --quiet postgresql || ! runuser -u postgres -- env HOME="$postgres_home" "$pgsql_install_dir/bin/pg_ctl" status -D "$pgsql_data_dir" >/dev/null 2>&1 || ! "$pgsql_install_dir/bin/pg_isready" -q -h "$pgsql_socket_dir" -p "$pgsql_port"; then
    systemctl stop postgresql >/dev/null 2>&1
    mv "$pgsql_data_dir" "$failed_data"
    mv "$old_data_backup" "$pgsql_data_dir"
    mv "$pgsql_install_dir" "$failed_install"
    mv "$old_install_backup" "$pgsql_install_dir"
    [ "$was_active" == 'y' ] && systemctl start postgresql
    echo "${CFAILURE}The upgraded server failed its startup checks; the old data and binaries were restored.${CEND}"
    echo "The failed destination is preserved at $failed_data; diagnostics are at $work_dir."
    return 1
  fi
  if [ "$was_active" != 'y' ]; then
    systemctl stop postgresql
  fi

  rm -rf "postgresql-$NEW_pgsql_ver"
  echo "You have ${CMSG}successfully${CEND} upgraded PostgreSQL from ${CMSG}${OLD_pgsql_ver}${CEND} to ${CMSG}${NEW_pgsql_ver}${CEND}."
  echo "Previous binaries: $old_install_backup"
  echo "Previous data and configuration: $old_data_backup"
  echo "Review old postgresql.conf and postgresql.auto.conf in the previous data directory and merge any custom settings that are still valid."
  echo "Check extension compatibility, review the generated scripts in $work_dir, and run analyze_new_cluster.sh when appropriate."
  echo "Keep the previous data and binaries until the upgraded cluster has been verified and backed up."
  return 0
}
