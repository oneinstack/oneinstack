#!/bin/bash
# Author:  tekintian <tekintian@gmail.com>
# desc: multi php version name change shell
#  https://github.com/tekintian/oneinstack_mphp

case "${php_option}" in
  1)
    sed -i 's@^php_install_dir=*@php_install_dir=/usr/local/php53@' ${oneinstack_dir}/options.conf
    sed -i 's@^php_vn=*@php_vn=53@' ${oneinstack_dir}/options.conf
    ;;
  2)
    sed -i 's@^php_install_dir=*@php_install_dir=/usr/local/php54@' ${oneinstack_dir}/options.conf
    sed -i 's@^php_vn=*@php_vn=54@' ${oneinstack_dir}/options.conf
    ;;
  3)
    sed -i 's@^php_install_dir=*@php_install_dir=/usr/local/php55@' ${oneinstack_dir}/options.conf
    sed -i 's@^php_vn=*@php_vn=55@' ${oneinstack_dir}/options.conf
    ;;
  4)
    sed -i 's@^php_install_dir=*@php_install_dir=/usr/local/php56@' ${oneinstack_dir}/options.conf
   sed -i 's@^php_vn=*@php_vn=56@' ${oneinstack_dir}/options.conf
    ;;
  5)
    sed -i 's@^php_install_dir=*@php_install_dir=/usr/local/php70@' ${oneinstack_dir}/options.conf
    sed -i 's@^php_vn=*@php_vn=70@' ${oneinstack_dir}/options.conf
    ;;
  6)
    sed -i 's@^php_install_dir=*@php_install_dir=/usr/local/php71@' ${oneinstack_dir}/options.conf
   sed -i 's@^php_vn=*@php_vn=71@' ${oneinstack_dir}/options.conf
    ;;
  7)
    sed -i 's@^php_install_dir=*@php_install_dir=/usr/local/php72@' ${oneinstack_dir}/options.conf
    sed -i 's@^php_vn=*@php_vn=72@' ${oneinstack_dir}/options.conf
    ;;
esac