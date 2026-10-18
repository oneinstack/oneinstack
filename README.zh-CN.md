[English](README.md) | [中文](README.zh-CN.md)

此脚本使用shell编写，用于快速部署`LEMP`/`LAMP`/`LNMP`/`LNMPA`/`LTMP`（Linux、Nginx/Tengine/OpenResty/Caddy、MySQL/MariaDB/Percona/PostgreSQL/ClickHouse/MongoDB、PHP、JAVA、Valkey/Redis）环境，适用于64位的RHEL 7、8、9（包括CentOS、RedHat、AlmaLinux、Rocky、Anolis）、Debian 9、10、11、12、13、Ubuntu 16、18、20、22、24、TencentOS 3~4.4、openEuler、Kylin和Fedora 27+。

脚本特点：
- 持续更新，提供交互式安装和自动安装
- 源码编译安装，采用最新稳定版本，并从官方或高速镜像站点下载
- 提供多重安全优化
- 提供多个数据库版本（MySQL-9.7 LTS、MySQL-8.4 LTS、MySQL-8.2、MySQL-8.0、MySQL-5.7、MySQL-5.6、MySQL-5.5、MariaDB-13.0、MariaDB-10.11、MariaDB-11.8 LTS、MariaDB-11.4 LTS、MariaDB-5.5、Percona-8.0、Percona-5.7、Percona-5.6、Percona-5.5、PostgreSQL-18.6、ClickHouse、MongoDB）
- 提供多个PHP版本（PHP-8.5、PHP-8.4、PHP-8.3、PHP-8.2、PHP-8.1、PHP-8.0、PHP-7.4、PHP-7.3、PHP-7.2、PHP-7.1、PHP-7.0、PHP-5.6、PHP-5.5、PHP-5.4、PHP-5.3）
- 提供Nginx（原生支持 HTTP/3 & QUIC、OpenSSL 3.5.8）、Tengine、OpenResty、Caddy、Apache和ngx_lua_waf
- 提供多个Tomcat版本（Tomcat-11、Tomcat-10、Tomcat-9、Tomcat-8、Tomcat-7）
- 提供多个JDK版本（OpenJDK-8、OpenJDK-11、OpenJDK-17、OpenJDK-18）
- 根据需求安装PHP缓存加速器（ZendOPcache、xcache、apcu、eAccelerator）和PHP扩展，包括ZendGuardLoader、ionCube、SourceGuardian、imagick、gmagick、fileinfo、imap、ldap、calendar、phalcon、yaf、yar、redis、memcached、memcache、mongodb、swoole、xdebug、xlswriter、grpc
- 可选安装Nodejs、Pureftpd、phpMyAdmin
- 可选安装Valkey（开源Redis替代版）、Redis、Memcached
- 使用Jemalloc优化MySQL、Nginx
- 提供虚拟主机管理脚本，包含Let's Encrypt SSL与主流DNS服务商（Cloudflare、阿里云DNS、DNSPod）DNS-01泛域名证书自动化申请与续期
- 提供Nginx/Tengine/OpenResty/Apache/Tomcat、MySQL/MariaDB/Percona、PHP、Valkey、Redis、Memcached、phpMyAdmin升级脚本
- 提供本地、远程（服务器间rsync）、阿里云OSS、腾讯云COS、又拍云、七牛云、亚马逊S3、Google Drive和Dropbox备份脚本

## 安装

根据您的发行版安装依赖，下载源码并运行安装脚本。

#### CentOS/Redhat

```bash
yum -y install wget screen
```

#### Debian/Ubuntu

```bash
apt-get -y install wget screen
```

#### 下载源码并安装

```bash
wget https://mirrors.oneinstack.com/oneinstack.tar.gz
tar xzf oneinstack.tar.gz
cd oneinstack
```

如果在安装过程中断开连接，可以执行命令`screen -r oneinstack`重新连接到安装窗口
```bash
screen -S oneinstack
```

如果需要修改目录（安装、数据存储、Nginx日志），请在运行install.sh之前修改`options.conf`文件
```bash
./install.sh
```

## 如何安装其他PHP版本

```bash
~/oneinstack/install.sh --mphp_ver 54
```

## 如何添加扩展

```bash
~/oneinstack/addons.sh
```

## 如何添加虚拟主机

```bash
~/oneinstack/vhost.sh
```

## 如何删除虚拟主机

```bash
~/oneinstack/vhost.sh --del
```

## 如何添加FTP虚拟用户

```bash
~/oneinstack/pureftpd_vhost.sh
```

## 如何备份

```bash
~/oneinstack/backup_setup.sh    # 备份参数设置
~/oneinstack/backup.sh    # 立即执行备份
crontab -l    # 可添加到计划任务，例如每天凌晨1点自动备份
  0 1 * * * cd ~/oneinstack/backup.sh  > /dev/null 2>&1 &
```

## 如何管理服务

Nginx/Tengine/OpenResty:
```bash
systemctl {start|stop|status|restart|reload} nginx
```
MySQL/MariaDB/Percona:
```bash
systemctl {start|stop|restart|reload|status} mysqld
```
PostgreSQL:
```bash
systemctl {start|stop|restart|status} postgresql
```
MongoDB:
```bash
systemctl {start|stop|status|restart|reload} mongod
```
PHP:
```bash
systemctl {start|stop|restart|reload|status} php-fpm
```
Apache:
```bash
systemctl {start|restart|stop} httpd
```
Tomcat:
```bash
systemctl {start|stop|status|restart} tomcat
```
Pure-FTPd:
```bash
systemctl {start|stop|restart|status} pureftpd
```
Valkey:
```bash
systemctl {start|stop|status|restart} valkey-server
```
Redis:
```bash
systemctl {start|stop|status|restart|reload} redis-server
```
Memcached:
```bash
systemctl {start|stop|status|restart|reload} memcached
```
ClickHouse:
```bash
systemctl {start|stop|status|restart} clickhouse-server
```

## 如何升级

```bash
~/oneinstack/upgrade.sh
```

## 如何卸载

```bash
~/oneinstack/uninstall.sh
```

## 获取帮助

如需反馈、提问，以及关注项目进展：<br />
[Telegram 群组](https://t.me/oneinstackn)<br />
[OneinStack官网](https://oneinstack.com)<br />

## 匿名安装统计与隐私说明

为了更好地驱动 OneinStack 后续版本的持续维护与更新迭代，`install.sh` 在安装开始与完成时会以非阻塞后台方式发送一次匿名统计请求：

1. **统计内容**：
   - **基础环境信息**：操作系统发行版与版本号（如 `ubuntu-24.04`、`debian-12`、`rocky-9`）、CPU 架构（如 `x86_64`、`aarch64`）、网络所在区域标识（用于优化镜像源加速策略）。
   - **选配组件参数**：本次安装所选择的软件版本与开关项（如 Web 服务器类型、PHP 版本及扩展名、数据库版本与安装方式、JDK/Tomcat、Redis/Valkey/Memcached 等）。
   - **安装状态与耗时**：随机生成的单次安装会话 ID（`install_id`）、安装开始/完成状态以及安装总耗时（分钟）。
2. **统计目的**：
   - 统计各 Linux 发行版及各软件组件版本（PHP、MySQL/MariaDB/Percona、Web 服务及扩展等）的真实使用热度、平均编译耗时与安装成功率，为后续版本更新、新系统兼容性适配、组件升级优先级及镜像站资源调配提供数据支撑。
3. **隐私承诺**：
   - **本次更新绝不收集任何用户隐私或敏感数据**：不收集也不上传数据库密码、SSH 端口、服务器主机名、系统账号、网站域名、业务文件或任何个人身份信息。
   - 统计请求在后台静默异步执行（超时时间仅 2~3 秒），任何网络异常或请求失败均不会影响您的正常安装流程。

