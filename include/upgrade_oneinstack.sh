#!/bin/bash
# OneinStack self-upgrade entry point. The standalone bootstrap is also used by
# V2.5/V2.6 installations to migrate away from their obsolete hard-coded mirror.

Upgrade_OneinStack() {
  local original_dir="$PWD"
  local bootstrap="${oneinstack_dir}/tools/upgrade_oneinstack_bootstrap.sh"
  local old_md5="${oneinstack_md5}"
  local status=0

  if [ ! -f "${bootstrap}" ]; then
    echo "OneinStack upgrade helper is missing: ${bootstrap}" >&2
    return 1
  fi

  # The bootstrap swaps the installation directory, so run it from the parent.
  cd "$(dirname "${oneinstack_dir}")" || return 1
  bash "${bootstrap}" --install-dir "${oneinstack_dir}" || status=$?
  cd "${oneinstack_dir}" 2>/dev/null || cd "${original_dir}" || return 1

  if [ "${status}" -eq 0 ] && [ -f "${oneinstack_dir}/options.conf" ]; then
    local config_line
    while IFS= read -r config_line || [ -n "${config_line}" ]; do
      case "${config_line}" in
        mirror_link=*) mirror_link=${config_line#*=} ;;
        oneinstack_md5=*) oneinstack_md5=${config_line#*=} ;;
      esac
    done < "${oneinstack_dir}/options.conf"
  fi

  # Retain the existing post-upgrade compatibility adjustments when the
  # installed package actually changed.
  if [ "${status}" -eq 0 ] && [ "${oneinstack_md5}" != "${old_md5}" ]; then
    if [ -e "${php_install_dir}/sbin/php-fpm" ]; then
      local php_ini
      for php_ini in "${php_install_dir}/etc/php.ini" \
        /usr/local/php53/etc/php.ini /usr/local/php54/etc/php.ini \
        /usr/local/php55/etc/php.ini /usr/local/php56/etc/php.ini \
        /usr/local/php70/etc/php.ini /usr/local/php71/etc/php.ini \
        /usr/local/php72/etc/php.ini /usr/local/php73/etc/php.ini \
        /usr/local/php74/etc/php.ini /usr/local/php80/etc/php.ini \
        /usr/local/php81/etc/php.ini /usr/local/php82/etc/php.ini \
        /usr/local/php83/etc/php.ini /usr/local/php84/etc/php.ini \
        /usr/local/php85/etc/php.ini /usr/local/php86/etc/php.ini; do
        [ -f "${php_ini}" ] && grep -q '^cgi.fix_pathinfo=0' "${php_ini}" && \
          sed -i 's@^cgi.fix_pathinfo=0@;cgi.fix_pathinfo=0@' "${php_ini}"
      done
    fi
    if [ -e "/lib/systemd/system/php-fpm.service" ]; then
      sed -i 's@^PrivateTmp.*@#&@g' /lib/systemd/system/php-fpm.service
      systemctl daemon-reload
    fi
  fi

  return "${status}"
}
