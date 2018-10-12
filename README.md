# oneinstack多版本PHP共存

## 使用方法

	第一次直接执行install.sh 安装， 

	第二次安装另外的PHP版本，直接选择下面需要安装的命令即可

```shell
	#PHP5.3安装
	./install.sh --php_option 1 --phpcache_option 1 --php_extensions zendguardloader,imagick,gmagick,memcached,memcache,redis


	#PHP5.4安装
	./install.sh --php_option 2 --phpcache_option 1 --php_extensions zendguardloader,imagick,gmagick,memcached,memcache,redis

	#PHP5.5安装
	./install.sh --php_option 3 --phpcache_option 1 --php_extensions zendguardloader,imagick,gmagick,memcached,memcache,redis

	#PHP5.6安装
	./install.sh --php_option 4 --phpcache_option 1 --php_extensions zendguardloader,imagick,gmagick,memcached,memcache,redis

	#PHP7.0安装
	./install.sh --php_option 5 --phpcache_option 1 --php_extensions zendguardloader,imagick,gmagick,memcached,memcache,redis

	#PHP7.1安装
	./install.sh --php_option 6 --phpcache_option 1 --php_extensions zendguardloader,imagick,gmagick,memcached,memcache,redis

	#PHP7.2安装
	./install.sh --php_option 7 --phpcache_option 1 --php_extensions zendguardloader,imagick,gmagick,memcached,memcache,redis
```


## 说明
	只能使用于php-fpm方式，做了如下改动
	在 options.conf 文件中增加了变量 php_vn数字版本号【取值 53--72】
	php_vn=70
	修改php_install_dir的目录为
	php_install_dir=/usr/local/phpXX 形式 XX为对应的 php_vn

	nginx.conf 配置文件中的PHP配置可选使用  
	include phpXX.conf 的方式载入

默认目录
	网站默认目录 /home/wwwroot
	备份目录 /home/backup
	数据库文件目录 /home/data

PHP端口
	如果使用端口连接则 端口号为  90XX , 如  9070 表示为php7.0的版本

系统环境
系统环境中的PHP默认为最后一次安装的PHP版本，如需要调整，自行修改 /etc/profile 文件中的PATH变量为你想要的PHP版本即可


addons.sh插件安装
	如果是PHP插件，则默认的PHP版本为上次安装的PHP版本，如需要为其他版本安装PHP插件，则需要修改options.conf文件中相关的PHP版本号，即：
```conf
	php_install_dir=/usr/local/php70
	php_vn=70
```

命令行修改 
先加入{oneinstack_dir}目录后执行
```shell
	sed -i 's@^php_install_dir=.*@php_install_dir=/usr/local/php70@' ./options.conf
	sed -i 's@^php_vn=.*@php_vn=70@' ./options.conf
```
把上面命令中的70换成你需要的版本【53--72】
{oneinstack_dir}为你的oneinstack的存放目录


# oneinstack
[![PayPal donate button](https://img.shields.io/badge/paypal-donate-green.svg)](https://paypal.me/yeho) [![支付宝捐助按钮](https://img.shields.io/badge/%E6%94%AF%E4%BB%98%E5%AE%9D-%E5%90%91TA%E6%8D%90%E5%8A%A9-green.svg)](https://static.oneinstack.com/images/alipay.png) [![微信捐助按钮](https://img.shields.io/badge/%E5%BE%AE%E4%BF%A1-%E5%90%91TA%E6%8D%90%E5%8A%A9-green.svg)](https://static.oneinstack.com/images/weixin.png)

This script is written using the shell, in order to quickly deploy `LEMP`/`LAMP`/`LNMP`/`LNMPA`/`LTMP`(Linux, Nginx/Tengine/OpenResty, MySQL in a production environment/MariaDB/Percona, PHP, JAVA), applicable to CentOS 6 ~ 7(including redhat), Debian 6 ~ 9, Ubuntu 12 ~ 16, Fedora 27~28 of 32 and 64.

Script properties:
- Continually updated, Provide Shell Interaction and Autoinstall
- Source compiler installation, most stable source is the latest version, and download from the official site
- Some security optimization
- Providing a plurality of database versions (MySQL-8.0, MySQL-5.7, MySQL-5.6, MySQL-5.5, MariaDB-10.3, MariaDB-10.2, MariaDB-10.1, MariaDB-10.0, MariaDB-5.5, Percona-5.7, Percona-5.6, Percona-5.5, AliSQL-5.6, PostgreSQL, MongoDB)
- Providing multiple PHP versions (PHP-7.2, PHP-7.1, PHP-7.0, PHP-5.6, PHP-5.5, PHP-5.4, PHP-5.3)
- Provide Nginx, Tengine, OpenResty and ngx_lua_waf
- Providing a plurality of Tomcat version (Tomcat-9, Tomcat-8, Tomcat-7, Tomcat-6)
- Providing a plurality of JDK version (JDK-10, JDK-1.8, JDK-1.7, JDK-1.6)
- Providing a plurality of Apache version (Apache-2.4, Apache-2.2)
- According to their needs to install PHP Cache Accelerator provides ZendOPcache, xcache, apcu, eAccelerator. And php encryption and decryption tool ionCube, ZendGuardLoader, swoole, xdebug, Composer
- Installation Pureftpd, phpMyAdmin according to their needs
- Install memcached, redis according to their needs
- Jemalloc optimize MySQL, Nginx
- Providing add a virtual host script, include Let's Encrypt SSL certificate
- Provide Nginx/Tengine/OpenResty/Apache, MySQL/MariaDB/Percona, PHP, Redis, Memcached, phpMyAdmin upgrade script
- Provide local backup,remote backup (rsync between servers),Aliyun OSS,Qcloud COS,UPYUN and QINIU script
- Provided under HHVM install CentOS 6,7

## How to use

If your server system: CentOS/Redhat (Do not enter "//" and "// subsequent sentence)
```bash
yum -y install wget screen python   // for CentOS / Redhat
wget https://github.com/tekintian/oneinstack_mphp/archive/master.tar.gz   // Contains the source code
tar xzf oneinstack_mphp.tar.gz
cd oneinstack_mphp   // If you need to modify the directory (installation, data storage, Nginx logs), modify options.conf file
screen -S oneinstack_mphp    // If network interruption, you can execute the command `screen -r oneinstack_mphp` reconnect install window
./install.sh   // Do not sh install.sh or bash install.sh such execution
```
If your server system: Debian/Ubuntu (Do not enter "//" and "// subsequent sentence)
```bash
apt-get -y install wget screen python    // for Debian / Ubuntu
wget http://mirrors.linuxeye.com/oneinstack_mphp.tar.gz   // Contains the source code
tar xzf oneinstack_mphp.tar.gz
cd oneinstack_mphp    // If you need to modify the directory (installation, data storage, Nginx logs), modify options.conf file
screen -S oneinstack_mphp    // If network interruption, you can execute the command `screen -r oneinstack_mphp` reconnect install window
./install.sh   // Do not sh install.sh or bash install.sh such execution
```

## How to add Extensions

```bash
cd ~/oneinstack_mphp    // Must enter the directory execution under oneinstack_mphp
./addons.sh    // Do not sh addons.sh or bash addons.sh such execution

```

## How to add a virtual host

```bash
cd ~/oneinstack_mphp    // Must enter the directory execution under oneinstack_mphp
./vhost.sh    // Do not sh vhost.sh or bash vhost.sh such execution
```

## How to delete a virtual host

```bash
cd ~/oneinstack_mphp
./vhost.sh del
```

## How to add FTP virtual user

```bash
cd ~/oneinstack_mphp
./pureftpd_vhost.sh
```

## How to backup

```bash
cd ~/oneinstack_mphp
./backup_setup.sh    // Backup parameters
./backup.sh    // Perform the backup immediately
crontab -l    // Can be added to scheduled tasks, such as automatic backups every day 1:00
  0 1 * * * cd ~/oneinstack_mphp;./backup.sh  > /dev/null 2>&1 &
```

## How to manage service

Nginx/Tengine/OpenResty:
```bash
service nginx {start|stop|status|restart|reload|configtest}
```
MySQL/MariaDB/Percona:
```bash
service mysqld {start|stop|restart|reload|status}
```
PostgreSQL:
```bash
service postgresql {start|stop|restart|status}
```
MongoDB:
```bash
service mongod {start|stop|status|restart|reload}
```
PHP:
根据你的版本不一样 phpXX-fpm 有不同，XX为你的数字版本号 【53-72】
```bash
service php70-fpm {start|stop|restart|reload|status}
```
HHVM:
```bash
#centos7
systemctl {start|stop|status|restart} hhvm
#centos6
service supervisord {start|stop|status|restart|reload}
```
Apache:
```bash
service httpd {start|restart|stop}
```
Tomcat:
```bash
service tomcat {start|stop|status|restart}
```
Pure-FTPd:
```bash
service pureftpd {start|stop|restart|status}
```
Redis:
```bash
service redis-server {start|stop|status|restart|reload}
```
Memcached:
```bash
service memcached {start|stop|status|restart|reload}
```

## How to upgrade

```bash
./upgrade.sh
```

## How to uninstall

```bash
./uninstall.sh
```

## Installation

For feedback, questions, and to follow the progress of the project: <br />
[OneinStack多版本PHP共存版](https://github.com/tekintian/oneinstack_mphp)<br />
[OneinStack](https://oneinstack_mphp.com)<br />
