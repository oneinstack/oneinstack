[English](README.md) | [中文](README.zh-CN.md)

此脚本使用shell编写，用于快速部署`LEMP`/`LAMP`/`LNMP`/`LNMPA`/`LTMP`（Linux、Nginx/Tengine/OpenResty、MySQL/MariaDB/Percona、PHP、JAVA）环境，适用于64位的RHEL 7、8、9（包括CentOS、RedHat、AlmaLinux、Rocky）、Debian 9、10、11、12、Ubuntu 16、18、20、22和Fedora 27+。

脚本特点：
- 持续更新，提供交互式安装和自动安装
- 源码编译安装，采用最新稳定版本，并从官方站点下载
- 提供多重安全优化
- 提供多个数据库版本（MySQL-9.7 LTS、MySQL-8.4 LTS、MySQL-8.0、MySQL-5.7、MySQL-5.6、MySQL-5.5、MariaDB-10.11、MariaDB-10.5、MariaDB-10.4、MariaDB-5.5、Percona-8.0、Percona-5.7、Percona-5.6、Percona-5.5、PostgreSQL、MongoDB）
- 提供多个PHP版本（PHP-8.5、PHP-8.4、PHP-8.3、PHP-8.2、PHP-8.1、PHP-8.0、PHP-7.4、PHP-7.3、PHP-7.2、PHP-7.1、PHP-7.0、PHP-5.6、PHP-5.5、PHP-5.4、PHP-5.3）
- 提供Nginx、Tengine、OpenResty、Caddy、Apache和ngx_lua_waf
- 提供多个Tomcat版本（Tomcat-10、Tomcat-9、Tomcat-8、Tomcat-7）
- 提供 OpenJDK 8、11（legacy）、17、18（legacy/EOL）、21 和 25
- 根据需求安装PHP缓存加速器（ZendOPcache、xcache、apcu、eAccelerator）和PHP扩展，包括ZendGuardLoader、ionCube、SourceGuardian、imagick、gmagick、fileinfo、imap、ldap、calendar、phalcon、yaf、yar、redis、memcached、memcache、mongodb、pgsql、sqlsrv、swoole、xdebug
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

### 可选数据库客户端扩展

现有 PHP 可按需、独立安装 LDAP、PostgreSQL 和 Microsoft SQL Server
支持。`pgsql` 会同时安装 `pgsql` 与 `pdo_pgsql`，且仅依赖 PostgreSQL
客户端库；`sqlsrv` 会同时安装 `sqlsrv` 与 `pdo_sqlsrv`，要求 PHP 8.3
或更新版本。

```bash
./install.sh --php_extensions ldap,pgsql,sqlsrv
```

SQL Server 选项不会在本机安装数据库服务端。它会在校验仓库签名密钥完整
指纹后，从 Microsoft 官方签名仓库安装 ODBC Driver 18；该选项仅支持
Microsoft 提供官方仓库的 Debian、Ubuntu 与 RHEL。

### JDK 支持与许可

新的 Tomcat 安装默认使用 OpenJDK 21。OpenJDK 8 为 Java EE 8 和其他
旧应用继续保留；OpenJDK 11 与已经停止维护的 OpenJDK 18 暂退为兼容选项，
原有选项编号保持不变。它们至少保留一个弃用周期后再移除，且不会被静默
映射到其他版本。OpenJDK 17 与 25 是另外两条受支持的 LTS 版本线。

OneinStack 只安装操作系统提供的 OpenJDK 或采用 GPLv2 + Classpath
Exception 的 Eclipse Temurin，不会下载 Oracle JDK。需要启用 Temurin
仓库时，会先校验 Adoptium 仓库签名密钥的完整指纹。

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

## 版本与下载元数据

`versions.txt` 是组件版本及可选下载完整性元数据的统一登记表。普通条目只
包含版本号；需要固定摘要或签名身份时，在版本后使用逗号追加带明确名称的
字段：

```text
component_ver=1.2.3
component_ver=1.2.3,sha256=64位十六进制摘要
component_ver=1.2.3,md5=32位十六进制摘要
component_ver=1.2.3,sha256=64位十六进制摘要,gpg_key=https://example.com/key.asc,gpg_finger=40或64位十六进制指纹
```

支持的元数据名称为 `sha256`、`md5`、`gpg_key` 和 `gpg_finger`。每个条目
只能指定一种摘要算法；`gpg_key` 与 `gpg_finger` 必须同时提供，且密钥地址
必须使用 HTTPS。空字段、重复字段、未知字段及格式错误会直接终止解析，
不会静默降低校验强度。

更新条目时，应从权威上游获取摘要和签名密钥指纹，确认对应组件的下载流程
实际使用这些元数据，并在发布前复核最终下载地址与文件名。

## 供应链安全

- 保持 `mirror_link=https://mirrors.oneinstack.com`，程序会拒绝第三方镜像域名。
- 下载必须使用 HTTPS，并以组件明确指定的地址为准；文件通过内容和压缩包检查后才会移入 `src/`。PHP 8.5 会校验固定的 SHA-256，MySQL 9.7 必须通过固定 Oracle 构建密钥指纹的 GPG 签名验证。
- 已禁用旧的压缩包覆盖式 OneinStack 自更新。请从官方 Git 仓库更新，并在以 root 运行新脚本前审查差异。
- `acme.sh` 和备份服务 CLI 需按厂商的可验证安装流程预先安装，OneinStack 不再以 root 自动下载未校验的可执行文件。

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
