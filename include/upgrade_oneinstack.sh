#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Upgrade_OneinStack() {
  # Replacing a root-run installation tree with an unsigned remote tarball is not safe.
  # 以未签名远程压缩包覆盖 root 执行的安装树不安全，因此禁用旧的在线自更新。
  echo "${CWARNING}Automatic OneinStack self-update is disabled for supply-chain safety.${CEND}"
  echo "The previous updater downloaded an unsigned archive and replaced executable scripts in place."
  echo "Update through a reviewed Git workflow from the official repository instead:"
  echo "  https://github.com/oneinstack/oneinstack"
  echo "Preserve options.conf and review the diff before running updated scripts as root."
  return 1
}
