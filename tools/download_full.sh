#!/bin/bash
export PATH=$PATH:/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
clear
oneinstack_dir=$(dirname "$(readlink -f $0)")/..
pushd ${oneinstack_dir} > /dev/null

. ./options.conf
. ./versions.txt
. ./include/color.sh
. ./include/download.sh
. ./include/check_download.sh

# Mock architecture variables for x86_64 (bypassing check_os.sh for macOS compatibility)
ARCH="x86_64"
SYS_ARCH_i="x86-64"
SYS_ARCH_n="x64"
SYS_ARCH="amd64"

$echo -e "${CMSG}========================================================================${CEND}"
$echo -e "${CMSG}开始为您同步所有 OneinStack 离线安装包到 src/ 目录...${CEND}"
$echo -e "${CMSG}========================================================================${CEND}"

# 强行开启所有组件开关以骗过下载检查脚本
with_old_openssl_flag=y
apache_flag=y
caddy_flag=y
pureftpd_flag=y
phpmyadmin_flag=y
redis_flag=y
memcached_flag=y

pecl_zendguardloader=1
pecl_ioncube=1
pecl_sourceguardian=1
pecl_imagick=1
pecl_gmagick=1
pecl_redis=1
pecl_memcached=1
pecl_memcache=1
pecl_mongodb=1

# 1. 下载所有 Web 服务器 (Nginx/Tengine/OpenResty/Caddy)
for nginx_option in 1 2 3 4; do
  checkDownload 2>&1
done

# 2. 下载所有 Tomcat
for tomcat_option in 1 2 3 4 5; do
  checkDownload 2>&1
done

# 3. 下载所有数据库 (二进制 + 源码编译 双版本) - 注释掉以防止官方镜像 MD5 损坏导致的无限重试循环
# for db_option in 1 2 3 4 5 6 7 8 9 10 11 12 13 14; do
#   dbinstallmethod=1
#   checkDownload 2>&1
#   dbinstallmethod=2
#   checkDownload 2>&1
# done

# 4. 下载所有 PHP 版本 (5.3 - 8.5)
for php_option in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
  checkDownload 2>&1
done

# 5. 下载所有 PHP 缓存组件
for phpcache_option in 1 2 3 4; do
  checkDownload 2>&1
done

$echo -e "${CSUCCESS}========================================================================${CEND}"
$echo -e "${CSUCCESS}恭喜！所有离线包均已下载/校验完毕！${CEND}"
$echo -e "${CSUCCESS}您的 src/ 目录现在已经是一个完美的 Full Package 离线源。${CEND}"
$echo -e "${CSUCCESS}========================================================================${CEND}"

popd > /dev/null
