#!/bin/bash

# Color
CFAILURE='\033[31m'
CSUCCESS='\033[32m'
CWARNING='\033[33m'
CINFO='\033[36m'
CEND='\033[0m'

# Check if JAVA_HOME is set  取消
#if [ -z "${JAVA_HOME}" ]; then
#    echo "${CFAILURE}JAVA_HOME environment variable is not set${CEND}"
#    echo "请设置JAVA_HOME环境变量，例如：export JAVA_HOME=/path/to/your/jdk && export PATH=\$JAVA_HOME/bin:\$PATH"
#    kill -9 $$; exit 1;
#fi

# Check if user is root
if [ "$(id -u)" != "0" ]; then
    echo "${CFAILURE}Error: You must be root to run this script${CEND}"
    exit 1
fi

# Tomcat version
tomcat_version="10.1.16"
# 更新为可用的下载链接
download_url="https://archive.apache.org/dist/tomcat/tomcat-10/v${tomcat_version}/bin/apache-tomcat-${tomcat_version}.tar.gz"
# Install directory
tomcat_install_dir="/usr/local/tomcat"
# User and group
tomcat_user="tomcat"
tomcat_group="tomcat"
# Memory settings
Xms_Mem="256"
XmxMem="512"
# APR version
apr_version="1.7.4"
# APR 下载 URL
apr_download_url="https://archive.apache.org/dist/apr/apr-${apr_version}.tar.gz"
# APR install directory
apr_install_dir="/usr/local/apr"

# Create user and group
groupadd -r ${tomcat_group}
useradd -r -g ${tomcat_group} -d ${tomcat_install_dir} -s /sbin/nologin ${tomcat_user}

# 下载 APR
echo "${CINFO}Installing APR...${CEND}"
retry=3
while [ $retry -gt 0 ]; do
    wget $apr_download_url
    if [ $? -eq 0 ]; then
        break
    fi
    echo "${CWARNING}APR download failed. Retrying...${CEND}"
    retry=$((retry - 1))
    sleep 5
done
if [ $retry -eq 0 ]; then
    echo "${CFAILURE}APR download failed after 3 attempts.${CEND}"
    exit 1
fi

tar -zxvf apr-${apr_version}.tar.gz
cd apr-${apr_version}
./configure --prefix=${apr_install_dir}
make && make install
cd ..
rm -rf apr-${apr_version} apr-${apr_version}.tar.gz

# 下载 Tomcat
echo "${CINFO}Downloading and extracting Tomcat...${CEND}"
retry=3
while [ $retry -gt 0 ]; do
    wget $download_url
    if [ $? -eq 0 ]; then
        break
    fi
    echo "${CWARNING}Tomcat download failed. Retrying...${CEND}"
    retry=$((retry - 1))
    sleep 5
done
if [ $retry -eq 0 ]; then
    echo "${CFAILURE}Tomcat download failed after 3 attempts.${CEND}"
    exit 1
fi

tar -zxvf apache-tomcat-${tomcat_version}.tar.gz
mv apache-tomcat-${tomcat_version} ${tomcat_install_dir}
rm -rf apache-tomcat-${tomcat_version}.tar.gz

# Set permissions
chown -R ${tomcat_user}:${tomcat_group} ${tomcat_install_dir}
chmod -R g+r ${tomcat_install_dir}/conf
chmod g+x ${tomcat_install_dir}/conf
chown -R ${tomcat_user}:${tomcat_group} ${tomcat_install_dir}/logs ${tomcat_install_dir}/temp ${tomcat_install_dir}/webapps ${tomcat_install_dir}/work
chown -R ${tomcat_user}:${tomcat_group} ${tomcat_install_dir}/bin ${tomcat_install_dir}/lib
chmod +x ${tomcat_install_dir}/bin/*.sh

# Set environment variables
cat > ${tomcat_install_dir}/bin/setenv.sh << EOF
JAVA_OPTS='-Djava.security.egd=file:/dev/./urandom -server -Xms${Xms_Mem}m -Xmx${XmxMem}m -Dfile.encoding=UTF-8'
CATALINA_OPTS="-Djava.library.path=${apr_install_dir}/lib"
# 以下配置项被注释，若需要使用，请取消注释并根据实际情况修改
# -Djava.rmi.server.hostname=$IPADDR
# -Dcom.sun.management.jmxremote.password.file=\$CATALINA_BASE/conf/jmxremote.password
# -Dcom.sun.management.jmxremote.access.file=\$CATALINA_BASE/conf/jmxremote.access
# -Dcom.sun.management.jmxremote.ssl=false
EOF

# Create systemd service
cat > /etc/systemd/system/tomcat.service << EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

Environment=JAVA_HOME=${JAVA_HOME}
Environment=CATALINA_PID=${tomcat_install_dir}/temp/tomcat.pid
Environment=CATALINA_HOME=${tomcat_install_dir}
Environment=CATALINA_BASE=${tomcat_install_dir}
Environment='CATALINA_OPTS=-Xms${Xms_Mem}m -Xmx${XmxMem}m -server -XX:+UseParallelGC'
Environment='JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom'

ExecStart=${tomcat_install_dir}/bin/startup.sh
ExecStop=/bin/kill -15 \$MAINPID

User=${tomcat_user}
Group=${tomcat_group}
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd manager configuration
systemctl daemon-reload

# Start and enable Tomcat service
systemctl start tomcat
systemctl enable tomcat

echo "${CSUCCESS}Tomcat ${tomcat_version} installed successfully!${CEND}"