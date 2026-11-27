#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Install_MPHP() {
  if [ "${apache_mode_option}" == '2' ] || [ -e "${apache_install_dir}/modules/libphp5.so" ] || [ -e "${apache_install_dir}/modules/libphp7.so" ] || [ -e "${apache_install_dir}/modules/libphp.so" ]; then
    echo "${CWARNING}To use the multiple PHP versions, You need to use PHP-FPM! ${CEND}"
  else
    if [ -e "${php_install_dir}${mphp_ver}/bin/phpize" ]; then
      echo "${CWARNING}PHP${mphp_ver} already installed! ${CEND}"
    else
      [ -e "/lib/systemd/system/php-fpm.service" ] && /bin/mv /lib/systemd/system/php-fpm.service{,_bk}
      orig_php_install_dir=${php_install_dir}
      php_install_dir=${php_install_dir}${mphp_ver}
      type Install_PHP_With_Fallback >/dev/null 2>&1 || . "${oneinstack_dir}/include/php_dnf.sh"
      case "${mphp_ver}" in
        53)
          Install_PHP_With_Fallback 53 include/php-5.3.sh Install_PHP53 2>&1 | tee -a ${oneinstack_dir}/install.log
          ;;
        54)
          Install_PHP_With_Fallback 54 include/php-5.4.sh Install_PHP54 2>&1 | tee -a ${oneinstack_dir}/install.log
          ;;
        55)
          Install_PHP_With_Fallback 55 include/php-5.5.sh Install_PHP55 2>&1 | tee -a ${oneinstack_dir}/install.log
          ;;
        56)
          Install_PHP_With_Fallback 56 include/php-5.6.sh Install_PHP56 2>&1 | tee -a ${oneinstack_dir}/install.log
          ;;
        70)
          Install_PHP_With_Fallback 70 include/php-7.0.sh Install_PHP70 2>&1 | tee -a ${oneinstack_dir}/install.log
          ;;
        71)
          Install_PHP_With_Fallback 71 include/php-7.1.sh Install_PHP71 2>&1 | tee -a ${oneinstack_dir}/install.log
          ;;
        72)
          Install_PHP_With_Fallback 72 include/php-7.2.sh Install_PHP72 2>&1 | tee -a ${oneinstack_dir}/install.log
          ;;
        73)
          Install_PHP_With_Fallback 73 include/php-7.3.sh Install_PHP73 2>&1 | tee -a ${oneinstack_dir}/install.log
          ;;
        74)
          Install_PHP_With_Fallback 74 include/php-7.4.sh Install_PHP74 2>&1 | tee -a ${oneinstack_dir}/install.log
          ;;
        80)
          Install_PHP_With_Fallback 80 include/php-8.0.sh Install_PHP80 2>&1 | tee -a ${oneinstack_dir}/install.log
          ;;
        81)
          Install_PHP_With_Fallback 81 include/php-8.1.sh Install_PHP81 2>&1 | tee -a ${oneinstack_dir}/install.log
          ;;
        82)
          Install_PHP_With_Fallback 82 include/php-8.2.sh Install_PHP82 2>&1 | tee -a ${oneinstack_dir}/install.log
          ;;
        83)
          Install_PHP_With_Fallback 83 include/php-8.3.sh Install_PHP83 2>&1 | tee -a ${oneinstack_dir}/install.log
          ;;
        84)
          Install_PHP_With_Fallback 84 include/php-8.4.sh Install_PHP84 2>&1 | tee -a ${oneinstack_dir}/install.log
          ;;
        85)
          Install_PHP_With_Fallback 85 include/php-8.5.sh Install_PHP85 2>&1 | tee -a ${oneinstack_dir}/install.log
          ;;
        86)
          Install_PHP_With_Fallback 86 include/php-8.6.sh Install_PHP86 2>&1 | tee -a ${oneinstack_dir}/install.log
          ;;
      esac
      if [ -e "${php_install_dir}/sbin/php-fpm" ]; then
        systemctl stop php-fpm 2>/dev/null || kill `cat ${php_install_dir}/var/run/php-fpm.pid 2>/dev/null` 2>/dev/null || true
        sed -i "s@/dev/shm/php-cgi.sock@/dev/shm/php${mphp_ver}-cgi.sock@" ${php_install_dir}/etc/php-fpm.conf
        [ -e "/lib/systemd/system/php-fpm.service" ] && /bin/mv /lib/systemd/system/php-fpm.service /lib/systemd/system/php${mphp_ver}-fpm.service
        if [ -e "/lib/systemd/system/php-fpm.service_bk" ]; then
          /bin/mv /lib/systemd/system/php-fpm.service{_bk,}
          systemctl daemon-reload 2>/dev/null || true
          systemctl enable php-fpm 2>/dev/null || true
          systemctl start php-fpm 2>/dev/null || true
        else
          systemctl daemon-reload 2>/dev/null || true
        fi
        systemctl enable php${mphp_ver}-fpm 2>/dev/null || true
        systemctl start php${mphp_ver}-fpm 2>/dev/null || ${php_install_dir}/sbin/php-fpm --fpm-config ${php_install_dir}/etc/php-fpm.conf
        sed -i "s@${php_install_dir}/bin:@@" /etc/profile
      elif [ -e "/lib/systemd/system/php-fpm.service_bk" ]; then
        /bin/mv /lib/systemd/system/php-fpm.service{_bk,}
        systemctl daemon-reload 2>/dev/null || true
      fi
    fi
  fi
}
