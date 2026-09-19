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
- [IB-008: Tomcat Native hard-depends on /usr/local/openssl](#ib-008-tomcat-native-hard-depends-on-usrlocalopenssl)
- [IB-009: Install_* | tee causes EXIT=1 after successful install](#ib-009-install_--tee-causes-exit1-after-successful-install)

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
- **Symptom / 现象**: Primary mirror returns 404 for Caddy package. Package downloaded from GitHub fallback, but `caddy.service` fails to start with status=217/USER. Script still prints "Caddy installed successfully!" despite service failure.
- **Root cause / 根因**: 
  1. **Primary**: systemd unit hardcodes `User=caddy` / `Group=caddy`, but `include/caddy.sh` only creates `www` user from `run_user=www` — does NOT create `caddy` user
  2. Journal error: `Failed at step USER spawning ... status=217/USER`
  3. **Secondary**: Primary mirror 404 (contributing, not blocking after GitHub fallback)
  4. **Secondary**: Permission denied noise on `/home/caddy` when caddy user has no home directory
  5. Script does not verify systemd active state after `systemctl start caddy` — reports success on failure
- **Fix plan / 修复方案**: 
  1. Align systemd unit `User`/`Group` with `run_user` (e.g., use `www`), OR create `caddy` user + home directory during install
  2. `systemctl is-active` check must fail the install with non-zero exit when service is not running
- **Evidence / 证据**: 
  - R3c logs on test host `/root/r3-logs`
  - Journal: `Failed at step USER ... status=217/USER`
  - Manual `useradd caddy` → service becomes active, `curl` returns 200
  - Script prints success message after `systemctl start caddy` fails
- **Workaround / 临时方案**: `useradd caddy` manually, then restart service (not scripted)
- **Code changed? / 是否已改代码**: no
- **Related issues**: N/A

---

### IB-006: Tengine openssl-1.1.1w first install unstable (EXIT=137)

- **Date / 日期**: 2026-09-20
- **Status / 状态**: open
- **Component / 组件**: Tengine / OpenSSL
- **OS / 环境**: Ubuntu 22.04
- **Machine / 机器**: 47.84.16.208 (Oneinstack测试 R3b)
- **Symptom / 现象**: First install attempt fails around `openssl-1.1.1w` with EXIT=137. Retry with pre-filled source succeeds (Tengine/3.1.0, curl 200). Also observed: on success path script may still EXIT=1 after printing "Congratulations" — exit code unreliable.
- **Root cause / 根因**: 
  1. **Primary**: Tengine build requires `openssl-1.1.1w` (per `versions.txt` `openssl11_ver`), but download logic preferentially/only fetched `openssl-3.5.8`; `src/` missing `openssl-1.1.1w.tar.gz` → first failure
  2. EXIT=137 also observed (SIGKILL / possible OOM during failed state)
  3. **Secondary**: Success path exit code unreliable — script may exit 1 after printing success message
- **Fix plan / 修复方案**: 
  1. Fetch `openssl11` (1.1.1w) per component dependency when Tengine is selected
  2. Verify download integrity after fetch (checksum)
  3. Success path must exit 0 — fix exit code logic
- **Evidence / 证据**: 
  - First attempt: FAIL EXIT=137, `src/` missing `openssl-1.1.1w.tar.gz`
  - Pre-fill `openssl-1.1.1w.tar.gz` → retry PASS (Tengine/3.1.0, curl 200)
  - Script may exit 1 after "Congratulations" message
  - Logs: `/root/r3-logs`
- **Workaround / 临时方案**: Pre-fill `openssl-1.1.1w.tar.gz` in `src/` before install
- **Code changed? / 是否已改代码**: no
- **Related issues**: N/A
- **Note**: OpenResty PASS; Apache 2.4.68 PASS (httpd still active) on same host — context only

---

### IB-007: PHP 8.3.33 link failure STT_GNU_IFUNC on Anolis

- **Date / 日期**: 2026-09-20
- **Status / 状态**: investigating (workaround verified, code change pending)
- **Component / 组件**: PHP
- **OS / 环境**: Anolis OS 8.10 RHCK; gcc 8.5.0; binutils 2.30
- **Machine / 机器**: 47.236.16.29 (Oneinstack测试-2 R1)
- **Symptom / 现象**: PHP `make` link stage fails with error: `STT_GNU_IFUNC symbol 'mb_utf16be_to_wchar' ... recompile with -fPIE and relink with -pie`. Both `sapi/cli/php` and `php-fpm` builds fail.
- **Root cause / 根因**: Anolis OS 8.10 / RHEL8 toolchain (gcc 8.5.0, binutils 2.30) requires position-independent executable flags (`-fPIE`/`-pie`) for proper linking of IFUNC symbols in PHP 8.3. Additionally, the `-z*-page-size=2097152` linker flag must be removed.
- **Fix plan / 修复方案**: 
  1. Bake these flags into Anolis/RHEL8 PHP build path in `install.sh`:
     - Add `EXTRA_CFLAGS=-fPIE`
     - Add `EXTRA_LDFLAGS_PROGRAM=-pie`
     - Remove `-zcommon-page-size=2097152` / `-zmax-page-size=2097152` linker flags
  2. Script should auto-detect Anolis/RHEL8 and apply these flags automatically
- **Workaround / 临时方案** (verified):
  ```bash
  export EXTRA_CFLAGS="-fPIE"
  export EXTRA_LDFLAGS_PROGRAM="-pie"
  # Also remove -z*-page-size=2097152 from linker flags
  ```
  Result: PHP 8.3.33 linked successfully
- **Evidence / 证据**: 
  - Original link error: `STT_GNU_IFUNC symbol 'mb_utf16be_to_wchar'`
  - Install command: `install.sh --nginx_option 1 --php_option 13 --db_option 1 --phpcache_option 1 --md5sum`
  - **R1 PASS** after applying workaround flags on 47.236.16.29
  - Final state: Nginx/PHP-FPM/MySQL all active, site HTTP 200
  - Classification: Class D
- **Code changed? / 是否已改代码**: no (workaround manual, script fix pending)
- **Related issues**: See IB-001 for MySQL mirror truncate observation on same machine

---

### IB-008: Tomcat Native hard-depends on /usr/local/openssl

- **Date / 日期**: 2026-09-20
- **Status / 状态**: open
- **Component / 组件**: Tomcat Native / OpenSSL
- **OS / 环境**: Ubuntu 22.04
- **Machine / 机器**: 47.84.16.208 (Oneinstack测试 R3)
- **Install command**: `./install.sh --tomcat_option 1 --jdk_option 3` (Tomcat 11 + JDK 17)
- **Symptom / 现象**: JDK installs successfully, but Tomcat Native build/link requires `/usr/local/openssl`. However, `Install_openSSL` only runs on old PHP paths — pure Tomcat scenario is missing that directory → script FAIL.
- **Root cause / 根因**: Tomcat Native configure hardcodes `--with-ssl=/usr/local/openssl` on non-ARM, but OpenSSL is not installed to that path in Tomcat-only installs. The `Install_openSSL` function is only triggered by PHP-related install paths.
- **Fix plan / 修复方案**: 
  1. On non-ARM, do not hardcode `/usr/local/openssl` for Tomcat Native
  2. Fall back to system OpenSSL (`--with-ssl=/usr`), or
  3. Force OpenSSL install on Tomcat path when Tomcat Native is selected
- **Evidence / 证据**: 
  - Logs: `/root/r3-logs/` on test host
  - Report: `/workspace/oneinstack-r3-report.md` (tester local)
  - Classification: Class D script defect
- **Workaround / 临时方案**: Use `--with-ssl=/usr` manually → `:8080` up (OpenJDK 17.0.20 / Tomcat 11.0.15)
- **Code changed? / 是否已改代码**: no
- **Related issues**: N/A

---

### IB-009: Install_* | tee causes EXIT=1 after successful install

- **Date / 日期**: 2026-09-20
- **Status / 状态**: open
- **Component / 组件**: install.sh pipeline / exit codes
- **OS / 环境**: Ubuntu 22.04 (also seen with OpenResty/Tengine success paths)
- **Machine / 机器**: 47.84.16.208 (Oneinstack测试 R3)
- **Symptom / 现象**: Features install successfully and `curl` returns 200, but script exits with EXIT=1. This occurs because pipeline using `| tee` does not check `PIPESTATUS` — the tee exit code masks the actual install function exit code.
- **Root cause / 根因**: Shell pipelines return the exit code of the last command by default. When `Install_*` functions are piped through `tee` for logging, the real exit code from the install function is lost. Script reports failure even when installation succeeded.
- **Fix plan / 修复方案**: 
  1. Check `${PIPESTATUS[0]}` after piped commands to capture the actual install function exit code
  2. Or: avoid masking real exit via pipe (use process substitution or temp file)
- **Evidence / 证据**: 
  - Install succeeds, curl 200, but EXIT=1
  - Pattern observed across multiple components
  - Classification: Class D/E script defect
- **Code changed? / 是否已改代码**: no
- **Related issues**: IB-006 success EXIT=1 note — same general pattern
