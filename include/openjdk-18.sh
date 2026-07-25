#!/bin/bash
# OpenJDK 18 is retained temporarily as an end-of-life legacy option.

. "${oneinstack_dir}/include/openjdk-common.sh"

Install_OpenJDK18() {
  echo "${CWARNING}OpenJDK 18 is an end-of-life legacy option retained for compatibility.${CEND}"
  Install_OpenJDK 18
}
