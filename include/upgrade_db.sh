#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Upgrade_MySQL_To_97() {
  local mysql97_package="mysql-${mysql97_ver}-linux-glibc2.28-x86_64"
  local mysql97_url="https://cdn.mysql.com/Downloads/MySQL-9.7/${mysql97_package}.tar.xz"
  local upgrade_stamp="$(date +"%Y%m%d_%H%M%S")"
  local old_binary_dir="${mysql_install_dir}_old_${upgrade_stamp}"
  local old_config_file="/etc/my.cnf.old_${upgrade_stamp}"
  local prepared_config="${oneinstack_dir}/src/my.cnf.mysql97.${upgrade_stamp}"
  local native_accounts
  local redo_capacity
  local expected_md5
  local actual_md5
  local mysql_ready=0
  local running_version

  MySQL97_OS_Supported || {
    echo "${CFAILURE}MySQL 9.7 requires x86_64 with RHEL 8+, Debian 12+, or Ubuntu 22+. ${CEND}"
    return 1
  }

  # mysql_native_password was removed in MySQL 9.0. Refuse the upgrade until every account is migrated.
  # MySQL 9.0 已移除 mysql_native_password；相关账号迁移完成前拒绝升级。
  native_accounts=$(${mysql_install_dir}/bin/mysql -uroot -p"${dbrootpwd}" --batch --skip-column-names \
    -e "SELECT CONCAT(User,'@',Host) FROM mysql.user WHERE plugin='mysql_native_password';" 2>/dev/null)
  if [ -n "${native_accounts}" ]; then
    echo "${CFAILURE}Upgrade blocked: these accounts still use mysql_native_password:${CEND}"
    echo "${native_accounts}"
    echo "Migrate them to caching_sha2_password, verify the applications, and retry."
    return 1
  fi

  echo "Running pre-upgrade table checks..."
  ${mysql_install_dir}/bin/mysqlcheck -uroot -p"${dbrootpwd}" --all-databases --check >/dev/null || {
    echo "${CFAILURE}Pre-upgrade table checks failed. Repair the reported tables before retrying. ${CEND}"
    return 1
  }

  [ "${OLD_db_ver%.*}" == '8.4' ] && redo_capacity=$(${mysql_install_dir}/bin/mysql -uroot -p"${dbrootpwd}" --batch --skip-column-names \
    -e "SELECT @@innodb_log_file_size * @@innodb_log_files_in_group;" 2>/dev/null)
  [[ ! "${redo_capacity}" =~ ^[0-9]+$ ]] && redo_capacity=''

  echo "Downloading MySQL ${mysql97_ver} LTS..."
  src_url=${mysql97_url} && Download_src
  src_url=${mysql97_url}.asc && Download_src
  Verify_GPG_Signature "${mysql97_package}.tar.xz" "${mysql97_package}.tar.xz.asc" \
    "${mysql_gpg_key_url}" "${mysql_gpg_fingerprint}" || return 1
  expected_md5=${mysql97_md5}
  actual_md5=$(md5sum ${mysql97_package}.tar.xz | awk '{print $1}')
  if [[ ! "${expected_md5}" =~ ^[[:xdigit:]]{32}$ ]] || [ "${actual_md5}" != "${expected_md5}" ]; then
    rm -f ${mysql97_package}.tar.xz
    echo "${CFAILURE}MySQL 9.7 package checksum verification failed. ${CEND}"
    return 1
  fi

  rm -rf ${mysql97_package}
  tar xJf ${mysql97_package}.tar.xz || return 1
  [ -x "${mysql97_package}/bin/mysqld" ] || {
    echo "${CFAILURE}MySQL 9.7 package is incomplete. ${CEND}"
    return 1
  }

  /bin/cp /etc/my.cnf ${prepared_config} || return 1
  # Remove options eliminated after 8.4; preserve the effective redo capacity under its replacement option.
  # 清理 8.4 之后被移除的选项，并用新选项保留等价的 redo 容量。
  sed -i -E '/^[[:space:]]*(default_authentication_plugin|mysql_native_password|mysql_native_password_proxy_users|innodb_log_file_size|innodb_log_files_in_group|innodb_undo_tablespaces)[[:space:]]*=/d' ${prepared_config}
  [ -n "${redo_capacity}" ] && sed -i "/^\[mysqld\]/a innodb_redo_log_capacity = ${redo_capacity}" ${prepared_config}

  if ! ${mysql97_package}/bin/mysqld --defaults-file=${prepared_config} \
    --basedir=${oneinstack_dir}/src/${mysql97_package} --validate-config; then
    echo "${CFAILURE}MySQL 9.7 rejected the current configuration. ${CEND}"
    echo "Prepared configuration kept at: ${prepared_config}"
    echo "The running MySQL instance has not been stopped or changed."
    return 1
  fi

  if [ "${db_flag}" != 'y' ]; then
    echo "MySQL will be stopped and its data directory upgraded in place."
    echo "Press Ctrl+c to cancel or Press any key to continue..."
    get_char >/dev/null
  fi

  # A slow shutdown is required before replacing 8.4 binaries with the next LTS series.
  # 跨 LTS 原地升级前执行慢关闭，确保 redo 与脏页完整落盘。
  ${mysql_install_dir}/bin/mysql -uroot -p"${dbrootpwd}" -e "SET GLOBAL innodb_fast_shutdown=0;" || return 1
  service mysqld stop || return 1
  for mysql_wait in {1..30}; do
    ${mysql_install_dir}/bin/mysqladmin -uroot -p"${dbrootpwd}" ping >/dev/null 2>&1 || break
    sleep 1
  done
  if ${mysql_install_dir}/bin/mysqladmin -uroot -p"${dbrootpwd}" ping >/dev/null 2>&1; then
    echo "${CFAILURE}MySQL did not stop; binaries were not changed. ${CEND}"
    return 1
  fi

  /bin/cp /etc/my.cnf ${old_config_file} || return 1
  mv ${mysql_install_dir} ${old_binary_dir} || return 1
  mv ${mysql97_package} ${mysql_install_dir} || {
    mv ${old_binary_dir} ${mysql_install_dir}
    service mysqld start
    return 1
  }
  if ! /bin/cp ${prepared_config} /etc/my.cnf; then
    mv ${mysql_install_dir} ${mysql_install_dir}_failed_${upgrade_stamp}
    mv ${old_binary_dir} ${mysql_install_dir}
    /bin/cp ${old_config_file} /etc/my.cnf
    service mysqld start
    return 1
  fi

  [ -e "${mysql_install_dir}/bin/mysqld_safe" ] && [ -e /usr/local/lib/libjemalloc.so ] && {
    sed -i 's@executing mysqld_safe@executing mysqld_safe\nexport LD_PRELOAD=/usr/local/lib/libjemalloc.so@' ${mysql_install_dir}/bin/mysqld_safe
    sed -i "s@/usr/local/mysql@${mysql_install_dir}@g" ${mysql_install_dir}/bin/mysqld_safe
  }
  /bin/cp ${mysql_install_dir}/support-files/mysql.server /etc/init.d/mysqld
  sed -i "s@^basedir=.*@basedir=${mysql_install_dir}@" /etc/init.d/mysqld
  sed -i "s@^datadir=.*@datadir=${mysql_data_dir}@" /etc/init.d/mysqld
  chmod +x /etc/init.d/mysqld
  rm -rf /etc/ld.so.conf.d/{mysql,mariadb,percona}*.conf
  echo "${mysql_install_dir}/lib" > /etc/ld.so.conf.d/z-mysql.conf
  ldconfig
  chown mysql:mysql -R ${mysql_data_dir}

  service mysqld start
  for mysql_wait in {1..120}; do
    ${mysql_install_dir}/bin/mysqladmin -uroot -p"${dbrootpwd}" ping >/dev/null 2>&1 && { mysql_ready=1; break; }
    sleep 1
  done
  if [ "${mysql_ready}" != '1' ]; then
    echo "${CFAILURE}MySQL 9.7 did not become ready. Do not restore old binaries over an upgraded data directory. ${CEND}"
    echo "Review ${mysql_data_dir}/mysql-error.log. Old binaries: ${old_binary_dir}; config backup: ${old_config_file}."
    return 1
  fi

  running_version=$(${mysql_install_dir}/bin/mysql -uroot -p"${dbrootpwd}" --batch --skip-column-names -e "SELECT VERSION();")
  if [[ ! "${running_version}" =~ ^9\.7\. ]]; then
    echo "${CFAILURE}Unexpected MySQL version after upgrade: ${running_version}. ${CEND}"
    return 1
  fi
  ${mysql_install_dir}/bin/mysqlcheck -uroot -p"${dbrootpwd}" --all-databases --check >/dev/null || {
    echo "${CWARNING}MySQL 9.7 is running, but post-upgrade table checks reported errors. ${CEND}"
    return 1
  }

  rm -f ${prepared_config}
  echo "You have ${CMSG}successfully${CEND} upgraded MySQL from ${CMSG}${OLD_db_ver}${CEND} to ${CMSG}${running_version}${CEND}."
  echo "Logical backup: ${oneinstack_dir}/src/${DB_BACKUP_FILE}"
  echo "Old binaries: ${old_binary_dir}; old configuration: ${old_config_file}"
}

Upgrade_DB() {
  pushd ${oneinstack_dir}/src > /dev/null
  [ ! -e "${db_install_dir}/bin/mysql" ] && echo "${CWARNING}MySQL/MariaDB/Percona is not installed on your system! ${CEND}" && exit 1
  [ "${armplatform}" == 'y' ] && echo "${CWARNING}The arm architecture operating system does not support upgrading MySQL/MariaDB/Percona! ${CEND}" && exit 1

  # check db passwd
  while :; do
    ${db_install_dir}/bin/mysql -uroot -p${dbrootpwd} -e "quit" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      break
    else
      echo
      read -e -p "Please input the root password of database: " NEW_dbrootpwd
      ${db_install_dir}/bin/mysql -uroot -p${NEW_dbrootpwd} -e "quit" >/dev/null 2>&1
      if [ $? -eq 0 ]; then
        dbrootpwd=${NEW_dbrootpwd}
        sed -i "s+^dbrootpwd.*+dbrootpwd='$dbrootpwd'+" ../options.conf
        break
      else
        echo "${CFAILURE}${DB} root password incorrect,Please enter again! ${CEND}"
      fi
    fi
  done

  OLD_db_ver_tmp=`${db_install_dir}/bin/mysql -uroot -p${dbrootpwd} -e 'select version()\G;' | grep version | awk '{print $2}'`
  if [ -n "`${db_install_dir}/bin/mysql -V | grep -o MariaDB`" ]; then
    [ "${OUTIP_STATE}"x == "China"x ] && DOWN_ADDR=https://mirrors.tuna.tsinghua.edu.cn/mariadb || DOWN_ADDR=https://archive.mariadb.org
    DB=MariaDB
    OLD_db_ver=`echo ${OLD_db_ver_tmp} | awk -F'-' '{print $1}'`
  elif [ -n "`${db_install_dir}/bin/mysql -V | grep -o Percona`" ]; then
    DB=Percona
    OLD_db_ver=${OLD_db_ver_tmp}
  else
    DOWN_ADDR=https://cdn.mysql.com/Downloads
    DB=MySQL
    OLD_db_ver=${OLD_db_ver_tmp%%-log}
  fi

  #backup
  echo
  echo "${CSUCCESS}Starting ${DB} backup${CEND}......"
  DB_BACKUP_FILE="DB_all_backup_$(date +"%Y%m%d_%H%M%S").sql"
  if ! ${db_install_dir}/bin/mysqldump -uroot -p"${dbrootpwd}" --opt --routines --events --all-databases > ${DB_BACKUP_FILE}; then
    rm -f ${DB_BACKUP_FILE}
    echo "${CFAILURE}${DB} backup failed; upgrade aborted. ${CEND}"
    popd > /dev/null
    return 1
  fi
  if [ ! -s "${DB_BACKUP_FILE}" ]; then
    rm -f ${DB_BACKUP_FILE}
    echo "${CFAILURE}${DB} backup is empty; upgrade aborted. ${CEND}"
    popd > /dev/null
    return 1
  fi
  echo "${DB} backup success, Backup file: ${MSG}`pwd`/${DB_BACKUP_FILE}${CEND}"

  #upgrade
  echo
  echo "Current ${DB} Version: ${CMSG}${OLD_db_ver}${CEND}"
  while :; do echo
    [ "${db_flag}" != 'y' ] && read -e -p "Please input upgrade ${DB} Version(example: ${OLD_db_ver}): " NEW_db_ver
    if [ "${DB}" == 'MySQL' ] && [[ "${OLD_db_ver%.*}" =~ ^(8\.4|9\.7)$ ]] && [ "${NEW_db_ver}" == "${mysql97_ver}" ]; then
      if [ "${OLD_db_ver}" == "${NEW_db_ver}" ]; then
        echo "MySQL ${NEW_db_ver} is already installed."
        popd > /dev/null
        return 0
      fi
      Upgrade_MySQL_To_97
      local mysql97_upgrade_status=$?
      popd > /dev/null
      return ${mysql97_upgrade_status}
    fi
    if [ `echo ${NEW_db_ver} | awk -F. '{print $1"."$2}'` == `echo ${OLD_db_ver} | awk -F. '{print $1"."$2}'` ]; then
      if [ "${DB}" == 'MariaDB' ]; then
        DB_filename=mariadb-${NEW_db_ver}-linux-systemd-x86_64
        DB_URL=${DOWN_ADDR}/mariadb-${NEW_db_ver}/bintar-linux-systemd-x86_64/${DB_filename}.tar.gz
      elif [ "${DB}" == 'Percona' ]; then
        if [[ "`echo ${NEW_db_ver} | awk -F. '{print $1"."$2}'`" =~ ^5.[5-6]$ ]]; then
          perconaVerStr1=$(echo ${NEW_db_ver} | sed "s@-@-rel@")
        else
          perconaVerStr1=${NEW_db_ver}
        fi
        if [[ "`echo ${NEW_db_ver} | awk -F. '{print $1"."$2}'`" =~ ^8.0$ ]]; then
           DB_filename=Percona-Server-${perconaVerStr1}-Linux.x86_64.glibc2.28
        elif [[ "`echo ${NEW_db_ver} | awk -F. '{print $1"."$2}'`" =~ ^5.7$ ]]; then
           DB_filename=Percona-Server-${perconaVerStr1}-Linux.x86_64.glibc2.17
        else
           DB_filename=Percona-Server-${perconaVerStr1}-Linux.x86_64.${sslLibVer}
        fi
        DB_URL=https://www.percona.com/downloads/Percona-Server-`echo ${NEW_db_ver} | awk -F. '{print $1"."$2}'`/Percona-Server-${NEW_db_ver}/binary/tarball/${DB_filename}.tar.gz
      elif [ "${DB}" == 'MySQL' ]; then
        DB_filename=mysql-${NEW_db_ver}-linux-glibc2.12-x86_64
        if [ `echo ${OLD_db_ver} | awk -F. '{print $1"."$2}'` == '8.0' ]; then
          DB_URL=${DOWN_ADDR}/MySQL-`echo ${NEW_db_ver} | awk -F. '{print $1"."$2}'`/${DB_filename}.tar.xz
        else
          DB_URL=${DOWN_ADDR}/MySQL-`echo ${NEW_db_ver} | awk -F. '{print $1"."$2}'`/${DB_filename}.tar.gz
        fi
      fi
      if [ ! -e "`ls ${DB_filename}.tar.?z 2>/dev/null`" ]; then
        src_url=${DB_URL}
        Download_src no_kill
      fi
      if [ -e "`ls ${DB_filename}.tar.?z 2>/dev/null`" ]; then
        echo "Download [${CMSG}`ls ${DB_filename}.tar.?z 2>/dev/null`${CEND}] successfully! "
      else
        echo "${CWARNING}${DB} version does not exist! ${CEND}"
      fi
      break
    else
      echo "${CWARNING}input error! ${CEND}Please only input '${CMSG}${OLD_db_ver%.*}.xx${CEND}'"
      [ "${db_flag}" == 'y' ] && exit
    fi
  done

  if [ -e "`ls ${DB_filename}.tar.?z 2>/dev/null`" ]; then
    echo "[${CMSG}`ls ${DB_filename}.tar.?z 2>/dev/null`${CEND}] found"
    if [ "${db_flag}" != 'y' ]; then
      echo "Press Ctrl+c to cancel or Press any key to continue..."
      char=`get_char`
    fi
    if [ "${DB}" == 'MariaDB' ]; then
      tar xzf ${DB_filename}.tar.gz
      service mysqld stop
      mv ${mariadb_install_dir}{,_old_`date +"%Y%m%d_%H%M%S"`}
      mv ${mariadb_data_dir}{,_old_`date +"%Y%m%d_%H%M%S"`}
      [ ! -d "${mariadb_install_dir}" ] && mkdir -p ${mariadb_install_dir}
      mkdir -p ${mariadb_data_dir};chown mysql:mysql -R ${mariadb_data_dir}
      mv ${DB_filename}/* ${mariadb_install_dir}/
      sed -i 's@executing mysqld_safe@executing mysqld_safe\nexport LD_PRELOAD=/usr/local/lib/libjemalloc.so@' ${mariadb_install_dir}/bin/mysqld_safe
      ${mariadb_install_dir}/scripts/mysql_install_db --user=mysql --basedir=${mariadb_install_dir} --datadir=${mariadb_data_dir}
      chown mysql:mysql -R ${mariadb_data_dir}
      service mysqld start
      ${mariadb_install_dir}/bin/mysql < ${DB_BACKUP_FILE}
      service mysqld restart
      ${mariadb_install_dir}/bin/mysql -uroot -p${dbrootpwd} -e "drop database test;" >/dev/null 2>&1
      ${mariadb_install_dir}/bin/mysql -uroot -p${dbrootpwd} -e "reset master;" >/dev/null 2>&1
      ${mariadb_install_dir}/bin/mysql_upgrade -uroot -p${dbrootpwd} >/dev/null 2>&1
      [ $? -eq 0 ] &&  echo "You have ${CMSG}successfully${CEND} upgrade from ${CMSG}${OLD_db_ver}${CEND} to ${CMSG}${NEW_db_ver}${CEND}"
    elif [ "${DB}" == 'Percona' ]; then
      tar xzf ${DB_filename}.tar.gz
      service mysqld stop
      mv ${percona_install_dir}{,_old_`date +"%Y%m%d_%H%M%S"`}
      mv ${percona_data_dir}{,_old_`date +"%Y%m%d_%H%M%S"`}
      [ ! -d "${percona_install_dir}" ] && mkdir -p ${percona_install_dir}
      mkdir -p ${percona_data_dir};chown mysql:mysql -R ${percona_data_dir}
      mv ${DB_filename}/* ${percona_install_dir}/
      sed -i 's@executing mysqld_safe@executing mysqld_safe\nexport LD_PRELOAD=/usr/local/lib/libjemalloc.so@' ${percona_install_dir}/bin/mysqld_safe
      sed -i "s@/usr/local/${DB_filename}@${percona_install_dir}@g" ${percona_install_dir}/bin/mysqld_safe
      if [[ "`echo ${NEW_db_ver} | awk -F. '{print $1"."$2}'`" =~ ^5.[5-6]$ ]]; then
        ${percona_install_dir}/scripts/mysql_install_db --user=mysql --basedir=${percona_install_dir} --datadir=${percona_data_dir}
      else
        ${percona_install_dir}/bin/mysqld --initialize-insecure --user=mysql --basedir=${percona_install_dir} --datadir=${percona_data_dir}
      fi
      chown mysql:mysql -R ${percona_data_dir}
      service mysqld start
      ${percona_install_dir}/bin/mysql < ${DB_BACKUP_FILE}
      service mysqld restart
      ${percona_install_dir}/bin/mysql -uroot -p${dbrootpwd} -e "drop database test;" >/dev/null 2>&1
      ${percona_install_dir}/bin/mysql -uroot -p${dbrootpwd} -e "reset master;" >/dev/null 2>&1
      ${percona_install_dir}/bin/mysql_upgrade -uroot -p${dbrootpwd} >/dev/null 2>&1
      [ $? -eq 0 ] &&  echo "You have ${CMSG}successfully${CEND} upgrade from ${CMSG}${OLD_db_ver}${CEND} to ${CMSG}${NEW_db_ver}${CEND}"
    elif [ "${DB}" == 'MySQL' ]; then
      if [ `echo ${OLD_db_ver} | awk -F. '{print $1"."$2}'` == '8.0' ]; then
        tar xJf ${DB_filename}.tar.xz
      else
        tar xzf ${DB_filename}.tar.gz
      fi
      service mysqld stop
      mv ${mysql_install_dir}{,_old_`date +"%Y%m%d_%H%M%S"`}
      mv ${mysql_data_dir}{,_old_`date +"%Y%m%d_%H%M%S"`}
      [ ! -d "${mysql_install_dir}" ] && mkdir -p ${mysql_install_dir}
      mkdir -p ${mysql_data_dir};chown mysql:mysql -R ${mysql_data_dir}
      mv ${DB_filename}/* ${mysql_install_dir}/
      sed -i 's@executing mysqld_safe@executing mysqld_safe\nexport LD_PRELOAD=/usr/local/lib/libjemalloc.so@' ${mysql_install_dir}/bin/mysqld_safe
      sed -i "s@/usr/local/mysql@${mysql_install_dir}@g" ${mysql_install_dir}/bin/mysqld_safe
      if [[ "`echo ${NEW_db_ver} | awk -F. '{print $1"."$2}'`" =~ ^5.[5-6]$ ]]; then
        ${mysql_install_dir}/scripts/mysql_install_db --user=mysql --basedir=${mysql_install_dir} --datadir=${mysql_data_dir}
      else
        ${mysql_install_dir}/bin/mysqld --initialize-insecure --user=mysql --basedir=${mysql_install_dir} --datadir=${mysql_data_dir}
      fi

      chown mysql:mysql -R ${mysql_data_dir}
      [ -e "${mysql_install_dir}/my.cnf" ] && rm -rf ${mysql_install_dir}/my.cnf
      sed -i '/myisam_repair_threads/d' /etc/my.cnf
      service mysqld start
      ${mysql_install_dir}/bin/mysql < ${DB_BACKUP_FILE}
      service mysqld restart
      ${mysql_install_dir}/bin/mysql -uroot -p${dbrootpwd} -e "drop database test;" >/dev/null 2>&1
      ${mysql_install_dir}/bin/mysql -uroot -p${dbrootpwd} -e "reset master;" >/dev/null 2>&1
      ${mysql_install_dir}/bin/mysql_upgrade -uroot -p${dbrootpwd} >/dev/null 2>&1
      [ $? -eq 0 ] &&  echo "You have ${CMSG}successfully${CEND} upgrade from ${CMSG}${OLD_db_ver}${CEND} to ${CMSG}${NEW_db_ver}${CEND}"
    fi
  fi
}
