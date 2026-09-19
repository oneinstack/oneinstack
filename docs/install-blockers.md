# Install Blockers Tracking / 安装阻塞问题追踪

## Introduction / 简介

**English:**
This is an **append-only** log for tracking "unable to install" / install-blocker issues found during testing. Each new install failure gets ONE new section appended at the end. Do not rewrite history of older entries except to update status fields. Maintainers and contributors use this document for triage and tracking resolution progress.

**中文:**
这是一个**仅追加**的日志，用于跟踪测试期间发现的"无法安装"/安装阻塞问题。每个新的安装失败都会在末尾追加一个新的章节。除更新状态字段外，不要修改旧条目的历史记录。维护者和贡献者使用此文档进行问题分类和跟踪解决进度。

### Entry Fields / 条目字段

| Field / 字段 | Description / 描述 |
|---|---|
| Date / 日期 | When the issue was first recorded / 问题首次记录时间 |
| Status / 状态 | `open` \| `investigating` \| `fixed-pending-release` \| `fixed` \| `wontfix` |
| Component / 组件 | Affected component (PHP, Nginx, MySQL, etc.) / 受影响的组件 |
| OS / 环境 | Operating system and version / 操作系统及版本 |
| Machine / 机器 | IP or hostname if known / 已知的 IP 或主机名 |
| Symptom / 现象 | Observable behavior / 可观察到的行为 |
| Root cause / 根因 | Underlying cause (or TBD) / 根本原因（或待定） |
| Fix plan / 修复方案 | Proposed solution / 建议的解决方案 |
| Evidence / 证据 | Logs, URLs, Content-Length, issue numbers / 日志、URL、Content-Length、issue 编号 |
| Code changed? / 是否已改代码 | `no` \| PR link \| branch / `否` \| PR 链接 \| 分支名 |
| Related issues | GitHub issue numbers / GitHub issue 编号 |

---

## Table of Contents / 目录

- [IB-001: MySQL 8.0.39 package truncated on mirrors](#ib-001-mysql-8039-package-truncated-on-mirrors)
- [IB-002: EPEL default metalink unreachable off-shore](#ib-002-epel-default-metalink-unreachable-off-shore)
- [IB-003: Redis 8 loadmodule directives for missing modules](#ib-003-redis-8-loadmodule-directives-for-missing-modules)
- [IB-004: RediSearch/RedisJSON build fails without Rust toolchain](#ib-004-redisearchredisjson-build-fails-without-rust-toolchain)
- [IB-005: Caddy primary mirror 404 + false install success](#ib-005-caddy-primary-mirror-404--false-install-success)
- [IB-006: Tengine openssl-1.1.1w first install unstable (EXIT=137)](#ib-006-tengine-openssl-111w-first-install-unstable-exit137)
- [IB-007: PHP 8.3.33 link failure STT_GNU_IFUNC on Anolis](#ib-007-php-8333-link-failure-stt_gnu_ifunc-on-anolis)

---

## Entry Template / 条目模板

```markdown
### IB-NNN: short title
- **Date / 日期**: YYYY-MM-DD
- **Status / 状态**: open | investigating | fixed-pending-release | fixed | wontfix
- **Component / 组件**: PHP | Nginx | MySQL | ...
- **OS / 环境**: 
- **Machine / 机器**: IP or hostname if known
- **Symptom / 现象**: 
- **Root cause / 根因**: (or TBD)
- **Fix plan / 修复方案**: 
- **Evidence / 证据**: logs, URLs, Content-Length, issue numbers
- **Code changed? / 是否已改代码**: no | PR link | branch
- **Related issues**: #
```

---

## Issues / 问题列表

### IB-001: MySQL 8.0.39 package truncated on mirrors

- **Date / 日期**: 2026-09-19
- **Status / 状态**: open
- **Component / 组件**: MySQL
- **OS / 环境**: Linux (glibc 2.17+)
- **Machine / 机器**: N/A
- **Symptom / 现象**: MySQL 8.0.39 installation fails due to corrupted/incomplete package download. The downloaded file is significantly smaller than expected.
- **Root cause / 根因**: The MySQL 8.0.39 package (`mysql-8.0.39-linux-glibc2.17-x86_64.tar.xz`) hosted on `mirrors.oneinstack.com` is truncated. Mirror reports Content-Length ~109MB, but the official full package size is ~423MB. Additionally, the official Oracle CDN often returns 404.
- **Fix plan / 修复方案**: 
  1. Verify mirror integrity and re-sync with upstream
  2. Switch download source to a reliable alternative
  3. Add file size or MD5/SHA256 validation before extraction (preferred over blind version bump alone)
- **Evidence / 证据**: 
  - File: `mysql-8.0.39-linux-glibc2.17-x86_64.tar.xz`
  - Mirror Content-Length: ~109MB
  - Expected size: ~423MB
  - Official CDN status: frequently 404
  - Additional observation (IB-007 machine, 47.236.16.29 Anolis 8.10): truncated length=114542816, md5_bad=`950f19c1531cf6f4dd249491a9817352`; expected length=443772160, md5=`1c092c3814b10bfa0794077867f9f4ad`; official CDN retry succeeded
- **Code changed? / 是否已改代码**: no
- **Related issues**: #568

---

### IB-002: EPEL default metalink unreachable off-shore

- **Date / 日期**: 2026-09-19
- **Status / 状态**: open
- **Component / 组件**: EPEL / Yum Repository
- **OS / 环境**: AlmaLinux 9.8 (RHEL-family)
- **Machine / 机器**: 47.84.25.92 / oneinstack-test-01
- **Symptom / 现象**: `mirrors.fedoraproject.org:443 Connection refused` when attempting to reach EPEL metalink from off-shore (China) network. Installation stalls at EPEL dependency resolution. Manually fixing Aliyun baseurl recovers the install.
- **Root cause / 根因**: Default EPEL metalink endpoint (`mirrors.fedoraproject.org`) is blocked or unreachable from certain regions (e.g., mainland China).
- **Fix plan / 修复方案**: 
  1. Add offshore/region precheck to detect EPEL connectivity
  2. Auto-switch to usable EPEL mirror (e.g., Aliyun, Tsinghua) when metalink fails
  3. Document manual workaround for affected users
- **Evidence / 证据**: 
  - Connection refused on `mirrors.fedoraproject.org:443`
  - Aliyun mirror baseurl works as fallback
- **Code changed? / 是否已改代码**: no
- **Related issues**: N/A

---

### IB-003: Redis 8 loadmodule directives for missing modules

- **Date / 日期**: 2026-09-19
- **Status / 状态**: open
- **Component / 组件**: Redis
- **OS / 环境**: AlmaLinux 9.8
- **Machine / 机器**: 47.84.25.92 / oneinstack-test-01
- **Symptom / 现象**: Redis 8 first start aborts immediately. Default `redis.conf` contains `loadmodule` directives for RedisBloom, RediSearch, RedisJSON, and RedisTimeSeries, but modules are not installed under `/usr/local/redis/modules/`.
- **Root cause / 根因**: Script defect - `redis.conf` is generated with `loadmodule` lines regardless of whether Redis modules were actually built/installed. Redis server fails to start when it cannot load the specified module files.
- **Fix plan / 修复方案**: 
  1. Do not write `loadmodule` directives when modules were not built/installed
  2. Or: install modules first, then enable `loadmodule`
  3. Mitigation: comment out `loadmodule` lines manually
- **Evidence / 证据**: 
  - Install command: `install.sh --redis --memcached --php_extensions imagick,redis,memcached`
  - Redis fails to start with module load errors
  - Mitigation used: comment out `loadmodule` directives in `redis.conf`
- **Code changed? / 是否已改代码**: no
- **Related issues**: Script defect (no GitHub issue yet)

---

### IB-004: RediSearch/RedisJSON build fails without Rust toolchain

- **Date / 日期**: 2026-09-19
- **Status / 状态**: open
- **Component / 组件**: Redis Modules (RediSearch, RedisJSON)
- **OS / 环境**: AlmaLinux 9.8
- **Machine / 机器**: 47.84.25.92 / oneinstack-test-01
- **Symptom / 现象**: RediSearch and RedisJSON module compilation fails during install. Core Redis still installs and works, but modules are missing, triggering IB-003 when `loadmodule` is present in config.
- **Root cause / 根因**: RediSearch and RedisJSON require Rust/Cargo toolchain for compilation, which is not pre-installed and not automatically installed by the script.
- **Fix plan / 修复方案**: 
  1. Pre-install Rust/Cargo toolchain before attempting module build
  2. Or: skip module build with clear warning message when Rust is unavailable
  3. Never default to `loadmodule` for modules that failed to build
- **Evidence / 证据**: 
  - Build fails with missing `cargo`/`rustc`
  - Same environment as IB-003
- **Code changed? / 是否已改代码**: no
- **Related issues**: Related to IB-003

---

### IB-005: Caddy primary mirror 404 + false install success

- **Date / 日期**: 2026-09-20
- **Status / 状态**: open
- **Component / 组件**: Caddy
- **OS / 环境**: Ubuntu 22.04
- **Machine / 机器**: 47.84.16.208 (Oneinstack测试 R3c)
- **Symptom / 现象**: Primary mirror returns 404 for Caddy package. Package later downloaded from GitHub fallback, but `caddy.service` fails to start. Install script still reports success despite service failure.
- **Root cause / 根因**: 
  1. Missing package on primary mirror
  2. Install script does not verify systemd active state after installation
- **Fix plan / 修复方案**: 
  1. Restore missing package on primary mirror
  2. After install, require `systemctl is-active` check and exit non-zero on failure
- **Evidence / 证据**: 
  - R3c logs on test host `/root/r3-logs`
  - Service failed while script reported success
- **Workaround / 临时方案**: Manual unit fix via journalctl inspection (not scripted)
- **Code changed? / 是否已改代码**: no
- **Related issues**: N/A

---

### IB-006: Tengine openssl-1.1.1w first install unstable (EXIT=137)

- **Date / 日期**: 2026-09-20
- **Status / 状态**: open
- **Component / 组件**: Tengine / OpenSSL
- **OS / 环境**: Ubuntu 22.04
- **Machine / 机器**: 47.84.16.208 (Oneinstack测试 R3b)
- **Symptom / 现象**: First install attempt fails around `openssl-1.1.1w` tar extraction with EXIT=137. Retry succeeds, then uninstalled for further testing.
- **Root cause / 根因**: Likely OOM/SIGKILL or download/extract interrupt. Exit code 137 typically indicates SIGKILL (128+9).
- **Fix plan / 修复方案**: 
  1. Add download + extract checksums for integrity verification
  2. More robust extract/build with explicit retry logic
  3. Clearer error messaging on failure
- **Evidence / 证据**: 
  - First attempt: FAIL EXIT=137
  - Retry: PASS
  - Logs: `/root/r3-logs`
- **Workaround / 临时方案**: Retry succeeded
- **Code changed? / 是否已改代码**: no
- **Related issues**: N/A
- **Note**: OpenResty PASS; Apache 2.4.68 PASS (httpd still active) on same host — context only

---

### IB-007: PHP 8.3.33 link failure STT_GNU_IFUNC on Anolis

- **Date / 日期**: 2026-09-20
- **Status / 状态**: open
- **Component / 组件**: PHP
- **OS / 环境**: Anolis OS 8.10 RHCK; gcc 8.5.0; binutils 2.30
- **Machine / 机器**: 47.236.16.29 (Oneinstack测试-2 R1)
- **Symptom / 现象**: PHP `make` link stage fails with error: `STT_GNU_IFUNC symbol 'mb_utf16be_to_wchar' ... recompile with -fPIE and relink with -pie`. Both `sapi/cli/php` and `php-fpm` builds fail.
- **Root cause / 根因**: Anolis OS 8.10 / RHEL8 toolchain (gcc 8.5.0, binutils 2.30) requires position-independent executable flags (`-fPIE`/`-pie`) for proper linking of IFUNC symbols in PHP 8.3.
- **Fix plan / 修复方案**: 
  1. On Anolis/RHEL8, enable `-fPIE`/`-pie` (or equivalent) for PHP build
  2. Then rerun PHP install → start MySQL → verify site
- **Evidence / 证据**: 
  - Link error: `STT_GNU_IFUNC symbol 'mb_utf16be_to_wchar'`
  - Install command: `install.sh --nginx_option 1 --php_option 13 --db_option 1 --phpcache_option 1 --md5sum`
  - Current state: Nginx 1.30.5 installed/running; MySQL binary present but mysqld inactive; PHP not installed
  - Classification: Class D
- **Code changed? / 是否已改代码**: no
- **Related issues**: See IB-001 for MySQL mirror truncate observation on same machine
