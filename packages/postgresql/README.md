# PostgreSQL 安装包（供运维上传）

版本目录中每个版本有三个文件，请原样上传到 OneinStack 镜像目录：

    /oneinstack/src/

- postgresql-VERSION.tar.gz
- postgresql-VERSION.tar.gz.md5：供安装程序校验
- postgresql-VERSION.tar.gz.sha256：供升级程序校验

源包从 PostgreSQL 源码公开镜像下载。每个 tar.gz 的 SHA-256 均与 PostgreSQL 官方 FTP 发布的校验值独立核对过。

| PostgreSQL 大版本 | 安装包版本 | 生命周期 |
| --- | --- | --- |
| 18 | 18.7 | 官方支持中 |
| 17 | 17.12 | 官方支持中 |
| 16 | 16.16 | 官方支持中 |
| 15 | 15.20 | 官方支持中 |
| 14 | 14.25 | 最终版本；官方支持已于 2026-11-12 结束 |

准备的安装包目录：

- https://ftp.postgresql.org/pub/source/v18.7/
- https://ftp.postgresql.org/pub/source/v17.12/
- https://ftp.postgresql.org/pub/source/v16.16/
- https://ftp.postgresql.org/pub/source/v15.20/
- https://ftp.postgresql.org/pub/source/v14.25/

当前不包含 PostgreSQL 19：准备这些包时 PostgreSQL 官方发布信息仍将 19 标为 RC，而不是正式稳定版。

OneinStack 升级命令支持表中的目标版本。跨大版本升级使用 pg_upgrade 复制模式并先做兼容性检查；目标服务器仍需检查扩展和自定义配置、可用磁盘空间，以及 pg_upgrade 生成的后续脚本。
