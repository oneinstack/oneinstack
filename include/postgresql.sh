#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Install_PostgreSQL() {
  pushd ${oneinstack_dir}/src > /dev/null
  
  # 首先安装必要的依赖包
  if [ "${PM}" == 'yum' ]; then
    yum -y install flex bison readline-devel zlib-devel openssl-devel
  elif [ "${PM}" == 'apt-get' ]; then
    apt-get -y install flex bison libreadline-dev zlib1g-dev libssl-dev
  fi
  
  id -u postgres >/dev/null 2>&1
  [ $? -ne 0 ] && useradd -d ${pgsql_install_dir} -s /bin/bash postgres
  
  mkdir -p ${pgsql_data_dir}
  chown -R postgres:postgres ${pgsql_data_dir}
  
  tar xzf postgresql-${pgsql_ver}.tar.gz
  pushd postgresql-${pgsql_ver}
  
  # 配置和编译
  ./configure --prefix=${pgsql_install_dir} \
    --with-openssl \
    --with-libxml \
    --with-libxslt \
    --with-icu
  
  if [ $? -ne 0 ]; then
    echo "${CFAILURE}PostgreSQL configure failed! ${CEND}"
    kill -9 $$; exit 1;
  fi
  
  make -j ${THREAD}
  if [ $? -ne 0 ]; then
    echo "${CFAILURE}PostgreSQL make failed! ${CEND}"
    kill -9 $$; exit 1;
  fi
  
  make install
  if [ $? -ne 0 ]; then
    echo "${CFAILURE}PostgreSQL make install failed! ${CEND}"
    kill -9 $$; exit 1;
  fi
  
  # 设置权限
  chmod 755 ${pgsql_install_dir}
  chown -R postgres:postgres ${pgsql_install_dir}
  
  # 复制并修改服务文件
  /bin/cp ${oneinstack_dir}/init.d/postgresql.service /lib/systemd/system/
  sed -i "s@=/usr/local/pgsql@=${pgsql_install_dir}@g" /lib/systemd/system/postgresql.service
  sed -i "s@PGDATA=.*@PGDATA=${pgsql_data_dir}@" /lib/systemd/system/postgresql.service
  
  # 启用服务
  systemctl enable postgresql
  
  # 初始化数据库
  su - postgres -c "${pgsql_install_dir}/bin/initdb -D ${pgsql_data_dir}"
  if [ $? -ne 0 ]; then
    echo "${CFAILURE}PostgreSQL initdb failed! ${CEND}"
    kill -9 $$; exit 1;
  fi
  
  # 启动服务
  systemctl start postgresql
  if [ $? -ne 0 ]; then
    echo "${CFAILURE}PostgreSQL start failed! ${CEND}"
    kill -9 $$; exit 1;
  fi
  
  sleep 5
  
  # 设置密码
  su - postgres -c "${pgsql_install_dir}/bin/psql -c \"alter user postgres with password '$dbpostgrespwd';\""
  
  # 配置远程访问
  sed -i 's@^host.*@#&@g' ${pgsql_data_dir}/pg_hba.conf
  sed -i 's@^local.*@#&@g' ${pgsql_data_dir}/pg_hba.conf
  echo 'local   all             all                                     md5' >> ${pgsql_data_dir}/pg_hba.conf
  echo 'host    all             all             0.0.0.0/0               md5' >> ${pgsql_data_dir}/pg_hba.conf
  
  # 允许远程连接
  sed -i "s@^#listen_addresses.*@listen_addresses = '*'@" ${pgsql_data_dir}/postgresql.conf
  
  # 重新加载配置
  systemctl reload postgresql
  
  if [ -e "${pgsql_install_dir}/bin/psql" ]; then
    sed -i "s+^dbpostgrespwd.*+dbpostgrespwd='$dbpostgrespwd'+" ../options.conf
    echo "${CSUCCESS}PostgreSQL installed successfully! ${CEND}"
  else
    rm -rf ${pgsql_install_dir} ${pgsql_data_dir}
    echo "${CFAILURE}PostgreSQL install failed, Please contact the author! ${CEND}" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
    kill -9 $$; exit 1;
  fi
  
  popd
  popd
  [ -z "$(grep ^'export PATH=' /etc/profile)" ] && echo "export PATH=${pgsql_install_dir}/bin:\$PATH" >> /etc/profile
  [ -n "$(grep ^'export PATH=' /etc/profile)" -a -z "$(grep ${pgsql_install_dir} /etc/profile)" ] && sed -i "s@^export PATH=\(.*\)@export PATH=${pgsql_install_dir}/bin:\1@" /etc/profile
  . /etc/profile
}
