#!/bin/bash
# PHP 8.5 uses the same dependency, Apache/FPM, service, and tuning path as PHP 8.4.
# PHP 8.5 与 PHP 8.4 共用依赖、Apache/FPM、服务及调优链路。

. "${oneinstack_dir}/include/php-8.4.sh"

Check_PHP85_System_Iconv() {
  local iconv_test_dir iconv_test_src iconv_test_bin iconv_cc
  iconv_test_dir=$(mktemp -d /tmp/oneinstack-iconv.XXXXXX) || return 1
  iconv_test_src="${iconv_test_dir}/iconv-check.c"
  iconv_test_bin="${iconv_test_dir}/iconv-check"
  iconv_cc="${CC:-cc}"

  cat > "${iconv_test_src}" <<'EOF'
#include <iconv.h>

int main(void) {
  iconv_t cd = iconv_open("UTF-8", "UTF-8");
  if (cd == (iconv_t) -1) {
    return 1;
  }
  return iconv_close(cd);
}
EOF

  if ! "${iconv_cc}" "${iconv_test_src}" -o "${iconv_test_bin}" >/dev/null 2>&1 || ! "${iconv_test_bin}"; then
    echo "${CWARNING}System iconv development files are missing; installing them now...${CEND}"
    case "${PM}" in
      yum)
        yum -y install glibc-devel
        ;;
      apt-get)
        apt-get -y install libc6-dev
        ;;
    esac
    rm -f "${iconv_test_bin}"
  fi

  if ! "${iconv_cc}" "${iconv_test_src}" -o "${iconv_test_bin}" >/dev/null 2>&1 || ! "${iconv_test_bin}"; then
    echo "${CWARNING}System iconv remains unavailable after package installation.${CEND}"
    rm -f "${iconv_test_src}" "${iconv_test_bin}"
    rmdir "${iconv_test_dir}" 2>/dev/null
    return 1
  fi

  rm -f "${iconv_test_src}" "${iconv_test_bin}"
  rmdir "${iconv_test_dir}" 2>/dev/null
  echo "${CSUCCESS}System iconv compile and runtime check passed.${CEND}"
}

Install_PHP85() {
  if [ "${Family}" == 'rhel' ] && [ "${RHEL_ver:-0}" -lt 8 ]; then
    echo "${CFAILURE}PHP 8.5 requires RHEL 8 or newer on RHEL-family systems. ${CEND}"
    return 1
  fi

  local PHP_MODERN_FORCE_GNU_ICONV='n'
  if ! Check_PHP85_System_Iconv; then
    PHP_MODERN_FORCE_GNU_ICONV='y'
    echo "${CWARNING}Falling back to GNU libiconv under /usr/local.${CEND}"
  fi

  local PHP_MODERN_VERSION="${php85_ver}"
  local PHP_MODERN_WITH_SSL="${php85_with_ssl}"
  local PHP_MODERN_WITH_CURL="${php85_with_curl}"
  local PHP_MODERN_WITH_OPENSSL="${php85_with_openssl}"
  Install_PHP84
}
