[English](README.md) | [中文](README.zh-CN.md)

This script is written using the shell, in order to quickly deploy `LEMP`/`LAMP`/`LNMP`/`LNMPA`/`LTMP`(Linux, Nginx/Tengine/OpenResty, MySQL in a production environment/MariaDB/Percona, PHP, JAVA), applicable to RHEL 7, 8, 9(including CentOS,RedHat,AlmaLinux,Rocky), Debian 9, 10, 11, 12, Ubuntu 16, 18, 20, 22 and Fedora 27+ of 64.

Script properties:
- Continually updated, Provide Shell Interaction and Autoinstall
- Source compiler installation, most stable source is the latest version, and download from the official site
- Some security optimization
- Providing a plurality of database versions (MySQL-9.7 LTS, MySQL-8.4 LTS, MySQL-8.0, MySQL-5.7, MySQL-5.6, MySQL-5.5, MariaDB-10.11, MariaDB-10.5, MariaDB-10.4, MariaDB-5.5, Percona-8.0, Percona-5.7, Percona-5.6, Percona-5.5, PostgreSQL, MongoDB)
- Providing multiple PHP versions (PHP-8.5, PHP-8.4, PHP-8.3, PHP-8.2, PHP-8.1, PHP-8.0, PHP-7.4, PHP-7.3, PHP-7.2, PHP-7.1, PHP-7.0, PHP-5.6, PHP-5.5, PHP-5.4, PHP-5.3)
- Provide Nginx, Tengine, OpenResty, Caddy, Apache and ngx_lua_waf
- Providing a plurality of Tomcat version (Tomcat-10, Tomcat-9, Tomcat-8, Tomcat-7)
- Providing a plurality of JDK version (OpenJDK-8, OpenJDK-11, OpenJDK-17)
- According to their needs to install PHP Cache Accelerator provides ZendOPcache, xcache, apcu, eAccelerator. And php extensions,include ZendGuardLoader,ionCube,SourceGuardian,imagick,gmagick,fileinfo,imap,ldap,calendar,phalcon,yaf,yar,redis,memcached,memcache,mongodb,swoole,xdebug
- Installation Nodejs, Pureftpd, phpMyAdmin according to their needs
- Install memcached, redis according to their needs
- Jemalloc optimize MySQL, Nginx
- Providing add a virtual host script, include Let's Encrypt SSL certificate
- Provide Nginx/Tengine/OpenResty/Apache/Tomcat, MySQL/MariaDB/Percona, PHP, Redis, Memcached, phpMyAdmin upgrade script
- Provide local,remote(rsync between servers),Aliyun OSS,Qcloud COS,UPYUN,QINIU,Amazon S3,Google Drive and Dropbox backup script

## Installation

Install the dependencies for your distro, download the source and run the installation script.

#### CentOS/Redhat

```bash
yum -y install wget screen
```

#### Debian/Ubuntu

```bash
apt-get -y install wget screen
```

#### Download Source and Install

```bash
wget https://mirrors.oneinstack.com/oneinstack.tar.gz
tar xzf oneinstack.tar.gz
cd oneinstack
```

If you disconnect during installation, you can execute the command `screen -r oneinstack` to reconnect to the install window
```bash
screen -S oneinstack
```

If you need to modify the directory (installation, data storage, Nginx logs), modify `options.conf` file before running install.sh
```bash
./install.sh
```

### MySQL 9.7 LTS

MySQL 9.7 uses the official x86_64 binary package and requires RHEL 8+, Debian 12+, or Ubuntu 22+.

```bash
./install.sh --db_option 15 --dbinstallmethod 1 --dbrootpwd 'change-this-password'
```

An in-place upgrade from MySQL 8.4 LTS to MySQL 9.7 LTS is supported. Back up the server and test application compatibility before upgrading.

```bash
./upgrade.sh --db 9.7.1
```

### PHP 8.5

PHP 8.5 is available as the main PHP runtime or as an additional multi-PHP runtime. RHEL-family systems require RHEL 8 or newer.

```bash
./install.sh --php_option 15 --phpcache_option 1 --php_extensions imagick,redis,memcached,mongodb,swoole,xdebug
./install.sh --mphp_ver 85
```

Upgrade an existing PHP 8.5 installation within the same release series:

```bash
./upgrade.sh --php 8.5.8
```

## How to install another PHP version

```bash
~/oneinstack/install.sh --mphp_ver 54

```

## How to add Extensions

```bash
~/oneinstack/addons.sh

```

## How to add a virtual host

```bash
~/oneinstack/vhost.sh
```

## How to delete a virtual host

```bash
~/oneinstack/vhost.sh --del
```

## How to add FTP virtual user

```bash
~/oneinstack/pureftpd_vhost.sh
```

## How to backup

```bash
~/oneinstack/backup_setup.sh    // Backup parameters
~/oneinstack/backup.sh    // Perform the backup immediately
crontab -l    // Can be added to scheduled tasks, such as automatic backups every day 1:00
  0 1 * * * cd ~/oneinstack/backup.sh  > /dev/null 2>&1 &
```

## How to manage service

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

## Supply-chain security

- Keep `mirror_link=https://mirrors.oneinstack.com`. Third-party mirror domains are rejected.
- Downloads require HTTPS, use the URL selected by the component, and are validated before being moved into `src/`. PHP 8.5 uses a pinned SHA-256 checksum, and MySQL 9.7 requires a GPG signature from the pinned Oracle build-key fingerprint.
- The legacy tarball-based OneinStack self-updater is disabled. Update from the official Git repository and review the diff before running changed scripts as root.
- `acme.sh` and backup-provider CLIs must be installed using their vendor's verified installation instructions; OneinStack no longer downloads unverified executables as root.

## How to upgrade

```bash
~/oneinstack/upgrade.sh
```

## How to uninstall

```bash
~/oneinstack/uninstall.sh
```

## Installation

For feedback, questions, and to follow the progress of the project: <br />
[Telegram Group](https://t.me/oneinstackn)<br />
[OneinStack](https://oneinstack.com)<br />
