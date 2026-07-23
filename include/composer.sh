#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Install_composer() {
  if [ -e "${php_install_dir}/bin/phpize" ]; then
    if [ -e "/usr/local/bin/composer" ]; then
      echo "${CWARNING}PHP Composer already installed! ${CEND}"
    else
      local composer_tmp_dir composer_expected composer_actual
      composer_tmp_dir=$(mktemp -d /tmp/oneinstack-composer.XXXXXX) || return 1

      # Verify the official installer before it is executed. The installer then verifies composer.phar.
      # 执行前校验官方安装器；安装器还会继续校验最终的 composer.phar。
      if wget --https-only -q https://composer.github.io/installer.sig -O "${composer_tmp_dir}/installer.sig" &&
        wget --https-only -q https://getcomposer.org/installer -O "${composer_tmp_dir}/composer-setup.php"; then
        composer_expected=$(tr -d '[:space:]' < "${composer_tmp_dir}/installer.sig")
        composer_actual=$("${php_install_dir}/bin/php" -r "echo hash_file('sha384', '${composer_tmp_dir}/composer-setup.php');")
      fi

      if [[ "${composer_expected}" =~ ^[[:xdigit:]]{96}$ ]] &&
        [ "${composer_actual}" = "${composer_expected}" ] &&
        "${php_install_dir}/bin/php" "${composer_tmp_dir}/composer-setup.php" \
          --install-dir=/usr/local/bin --filename=composer >/dev/null; then
        chmod 0755 /usr/local/bin/composer
      else
        rm -f /usr/local/bin/composer
      fi
      rm -rf "${composer_tmp_dir}"

      if [ -x "/usr/local/bin/composer" ]; then
        echo; echo "${CSUCCESS}PHP Composer installed successfully! ${CEND}"
      else
        echo; echo "${CFAILURE}PHP Composer installer verification or installation failed. ${CEND}"
        return 1
      fi
    fi
  fi
}

Uninstall_composer() {
  if [ -e "/usr/local/bin/composer" ]; then
    rm -f /usr/local/bin/composer
    echo; echo "${CMSG}Composer uninstall completed${CEND}";
  else
    echo; echo "${CWARNING}Composer does not exist! ${CEND}"
  fi
}
