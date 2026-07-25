#!/bin/bash
# OpenJDK 11 is retained as a legacy compatibility option.

. "${oneinstack_dir}/include/openjdk-common.sh"

Install_OpenJDK11() {
  echo "${CWARNING}OpenJDK 11 is a legacy option retained for compatibility.${CEND}"
  Install_OpenJDK 11
}
