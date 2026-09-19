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
