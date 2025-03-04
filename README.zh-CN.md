[English](README.md) | [中文](README.zh-CN.md)

此脚本使用shell编写，用于快速部署`LEMP`/`LAMP`/`LNMP`/`LNMPA`/`LTMP`（Linux、Nginx/Tengine/OpenResty、MySQL/MariaDB/Percona、PHP、JAVA）环境，适用于64位的RHEL 7、8、9（包括CentOS、RedHat、AlmaLinux、Rocky）、Debian 9、10、11、12、Ubuntu 16、18、20、22和Fedora 27+。

脚本特点：
- 持续更新，提供交互式安装和自动安装
- 源码编译安装，采用最新稳定版本，并从官方站点下载
- 提供多重安全优化
- 提供多个数据库版本（MySQL-8.0、MySQL-5.7、MySQL-5.6、MySQL-5.5、MariaDB-10.11、MariaDB-10.5、MariaDB-10.4、MariaDB-5.5、Percona-8.0、Percona-5.7、Percona-5.6、Percona-5.5、PostgreSQL、MongoDB）
- 提供多个PHP版本（PHP-8.3、PHP-8.2、PHP-8.1、PHP-8.0、PHP-7.4、PHP-7.3、PHP-7.2、PHP-7.1、PHP-7.0、PHP-5.6、PHP-5.5、PHP-5.4、PHP-5.3）
- 提供Nginx、Tengine、OpenResty、Caddy、Apache和ngx_lua_waf
- 提供多个Tomcat版本（Tomcat-10、Tomcat-9、Tomcat-8、Tomcat-7）
- 提供多个JDK版本（OpenJDK-8、OpenJDK-11、OpenJDK-17）
- 根据需求安装PHP缓存加速器（ZendOPcache、xcache、apcu、eAccelerator）和PHP扩展，包括ZendGuardLoader、ionCube、SourceGuardian、imagick、gmagick、fileinfo、imap、ldap、calendar、phalcon、yaf、yar、redis、memcached、memcache、mongodb、swoole、xdebug
- 可选安装Nodejs、Pureftpd、phpMyAdmin
- 可选安装memcached、redis
- 使用Jemalloc优化MySQL、Nginx
- 提供添加虚拟主机脚本，包括Let's Encrypt SSL证书
- 提供Nginx/Tengine/OpenResty/Apache/Tomcat、MySQL/MariaDB/Percona、PHP、Redis、Memcached、phpMyAdmin升级脚本
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
wget http://mirrors.oneinstack.com/oneinstack-full.tar.gz
tar xzf oneinstack-full.tar.gz
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
Redis:
```bash
systemctl {start|stop|status|restart|reload} redis-server
```
Memcached:
```bash
systemctl {start|stop|status|restart|reload} memcached
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