#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://blog.linuxeye.com
#
# Version: 1.0-Alpha Jun 15,2015 lj2007331 AT gmail.com
# Notes: OneinStack for CentOS/RadHat 5+ Debian 6+ and Ubuntu 12+
#
# Project home page:
#       http://oneinstack.com

# Check if user is root
[ $(id -u) != "0" ] && { echo -e "\033[31mError: You must be root to run this script\033[0m"; exit 1; } 
export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
clear
printf "
#######################################################################
#       OneinStack for CentOS/RadHat 5+ Debian 6+ and Ubuntu 12+      #
#       For more information please visit http://oneinstack.com       #
#######################################################################
"
. ./options.conf

Choose_env()
{
if [ -e "$php_install_dir" -a -e "$tomcat_install_dir" -a -e "/usr/bin/hhvm" ];then
	Number=111
        while :
        do
                echo
                echo 'Please choose to use environment:'
                echo -e "\t\033[32m1\033[0m. Use php"
                echo -e "\t\033[32m2\033[0m. Use java"
                echo -e "\t\033[32m3\033[0m. Use hhvm"
                read -p "Please input a number:(Default 1 press Enter) " Choose_number
                [ -z "$Choose_number" ] && Choose_number=1
                if [ $Choose_number != 1 -a $Choose_number != 2 -a $Choose_number != 3 ];then
                        echo -e "\033[31minput error! Please only input number 1,2,3\033[0m"
                else
                        break
                fi
        done
	[ "$Choose_number" == '1' ] && NGX_FLAG=php
	[ "$Choose_number" == '2' ] && NGX_FLAG=java
	[ "$Choose_number" == '3' ] && NGX_FLAG=hhvm
elif [ -e "$php_install_dir" -a -e "$tomcat_install_dir" -a ! -e "/usr/bin/hhvm" ];then
	Number=110
        while :
        do
                echo
                echo 'Please choose to use environment:'
                echo -e "\t\033[32m1\033[0m. Use php"
                echo -e "\t\033[32m2\033[0m. Use java"
                read -p "Please input a number:(Default 1 press Enter) " Choose_number
                [ -z "$Choose_number" ] && Choose_number=1
                if [ $Choose_number != 1 -a $Choose_number != 2 ];then
                        echo -e "\033[31minput error! Please only input number 1,2\033[0m"
                else
                        break
                fi
        done
	[ "$Choose_number" == '1' ] && NGX_FLAG=php
	[ "$Choose_number" == '2' ] && NGX_FLAG=java
elif [ -e "$php_install_dir" -a ! -e "$tomcat_install_dir" -a ! -e "/usr/bin/hhvm" ];then
	Number=100
	NGX_FLAG=php
	echo -e "\t\033[32m1\033[0m. Use php"
elif [ -e "$php_install_dir" -a ! -e "$tomcat_install_dir" -a -e "/usr/bin/hhvm" ];then
	Number=101
	while :
        do
                echo
                echo 'Please choose to use environment:'
                echo -e "\t\033[32m1\033[0m. Use php"
                echo -e "\t\033[32m2\033[0m. Use hhvm"
                read -p "Please input a number:(Default 1 press Enter) " Choose_number
                [ -z "$Choose_number" ] && Choose_number=1
                if [ $Choose_number != 1 -a $Choose_number != 2 ];then
                        echo -e "\033[31minput error! Please only input number 1,2\033[0m"
                else
                        break
                fi
        done
	[ "$Choose_number" == '1' ] && NGX_FLAG=php
	[ "$Choose_number" == '2' ] && NGX_FLAG=hhvm
elif [ ! -e "$php_install_dir" -a -e "$tomcat_install_dir" -a -e "/usr/bin/hhvm" ];then
	Number=011
        while :
        do
                echo
                echo 'Please choose to use environment:'
                echo -e "\t\033[32m1\033[0m. Use java"
                echo -e "\t\033[32m2\033[0m. Use hhvm"
                read -p "Please input a number:(Default 1 press Enter) " Choose_number
                [ -z "$Choose_number" ] && Choose_number=1
                if [ $Choose_number != 1 -a $Choose_number != 2 ];then
                        echo -e "\033[31minput error! Please only input number 1,2\033[0m"
                else
                        break
                fi
        done
	[ "$Choose_number" == '1' ] && NGX_FLAG=java
	[ "$Choose_number" == '2' ] && NGX_FLAG=hhvm
elif [ ! -e "$php_install_dir" -a -e "$tomcat_install_dir" -a ! -e "/usr/bin/hhvm" ];then
	Number=010
	NGX_FLAG=java
elif [ ! -e "$php_install_dir" -a ! -e "$tomcat_install_dir" -a -e "/usr/bin/hhvm" ];then
	Number=001
	NGX_FLAG=hhvm
else
	Number=000
	exit
fi

if [ "$NGX_FLAG" == 'php' ];then
	NGX_CONF="location ~ .*\.(php|php5)?$ {\n\t#fastcgi_pass remote_php_ip:9000;\n\tfastcgi_pass unix:/dev/shm/php-cgi.sock;\n\tfastcgi_index index.php;\n\tinclude fastcgi.conf;\n\t}"
elif [ "$NGX_FLAG" == 'java' ];then
	NGX_CONF="location ~ {\n\tproxy_set_header Host \$host;\n\tproxy_set_header X-Real-IP \$remote_addr;\n\tproxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;\n\tproxy_pass http://127.0.0.1:8080;\n\t}"
elif [ "$NGX_FLAG" == 'hhvm' ];then
	NGX_CONF="location ~ .*\.(php|php5)?$ {\n\tfastcgi_pass unix:/var/log/hhvm/sock;\n\tfastcgi_index index.php;\n\tfastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;\n\tinclude fastcgi_params;\n\t}"
fi
}

Input_domain()
{
while :
do
	echo
	read -p "Please input domain(example: www.linuxeye.com): " domain
	if [ -z "`echo $domain | grep '.*\..*'`" ]; then
		echo -e "\033[31minput error! \033[0m"
	else
		break
	fi
done

if [ -e "$web_install_dir/conf/vhost/$domain.conf" -o -e "$apache_install_dir/conf/vhost/$domain.conf" ]; then
	[ -e "$web_install_dir/conf/vhost/$domain.conf" ] && echo -e "$domain in the Nginx/Tengine already exist! \nYou can delete \033[32m$web_install_dir/conf/vhost/$domain.conf\033[0m and re-create"
	[ -e "$apache_install_dir/conf/vhost/$domain.conf" ] && echo -e "$domain in the Apache already exist! \nYou can delete \033[32m$apache_install_dir/conf/vhost/$domain.conf\033[0m and re-create"
	exit
else
	echo "domain=$domain"
fi

while :
do
	echo ''
        read -p "Do you want to add more domain name? [y/n]: " moredomainame_yn 
        if [ "$moredomainame_yn" != 'y' ] && [ "$moredomainame_yn" != 'n' ];then
                echo -e "\033[31minput error! Please only input 'y' or 'n'\033[0m"
        else
                break 
        fi
done

if [ "$moredomainame_yn" == 'y' ]; then
        while :
        do
                echo
                read -p "Type domainname,example(linuxeye.com www.example.com): " moredomain
                if [ -z "`echo $moredomain | grep '.*\..*'`" ]; then
                        echo -e "\033[31minput error\033[0m"
                else
			[ "$moredomain" == "$domain" ] && echo -e "\033[31mDomain name already exists! \033[0m" && continue
                        echo domain list="$moredomain"
                        moredomainame=" $moredomain"
                        break
                fi
        done
        Domain_alias=ServerAlias$moredomainame
fi

echo
echo "Please input the directory for the domain:$domain :"
read -p "(Default directory: $home_dir/$domain): " vhostdir
if [ -z "$vhostdir" ]; then
        vhostdir="$home_dir/$domain"
        echo -e "Virtual Host Directory=\033[32m$vhostdir\033[0m"
fi
echo
echo "Create Virtul Host directory......"
mkdir -p $vhostdir
echo "set permissions of Virtual Host directory......"
chown -R ${run_user}.$run_user $vhostdir
}

Nginx_anti_hotlinking()
{
while :
do
	echo ''
        read -p "Do you want to add hotlink protection? [y/n]: " anti_hotlinking_yn 
        if [ "$anti_hotlinking_yn" != 'y' ] && [ "$anti_hotlinking_yn" != 'n' ];then
                echo -e "\033[31minput error! Please only input 'y' or 'n'\033[0m"
        else
                break
        fi
done

if [ -n "`echo $domain | grep '.*\..*\..*'`" ];then
        domain_allow="*.${domain#*.} $domain"
else
        domain_allow="*.$domain $domain"
fi

if [ "$anti_hotlinking_yn" == 'y' ];then 
	if [ "$moredomainame_yn" == 'y' ]; then
		domain_allow_all=$domain_allow$moredomainame
	else
		domain_allow_all=$domain_allow
	fi
	anti_hotlinking=$(echo -e "location ~ .*\.(wma|wmv|asf|mp3|mmf|zip|rar|jpg|gif|png|swf|flv)$ {\n\tvalid_referers none blocked $domain_allow_all;\n\tif (\$invalid_referer) {\n\t\t#rewrite ^/ http://www.linuxeye.com/403.html;\n\t\treturn 403;\n\t\t}\n\t}")
else
	anti_hotlinking=
fi
}

Nginx_rewrite()
{
while :
do
	echo ''
        read -p "Allow Rewrite rule? [y/n]: " rewrite_yn
        if [ "$rewrite_yn" != 'y' ] && [ "$rewrite_yn" != 'n' ];then
                echo -e "\033[31minput error! Please only input 'y' or 'n'\033[0m"
        else
                break 
        fi
done
if [ "$rewrite_yn" == 'n' ];then
	rewrite="none"
	touch "$web_install_dir/conf/$rewrite.conf"
else
	echo ''
	echo "Please input the rewrite of programme :"
	echo -e "\033[32mwordpress\033[0m,\033[32mdiscuz\033[0m,\033[32mphpwind\033[0m,\033[32mtypecho\033[0m,\033[32mecshop\033[0m,\033[32mdrupal\033[0m,\033[32mjoomla\033[0m rewrite was exist."
	read -p "(Default rewrite: other):" rewrite
	if [ "$rewrite" == "" ]; then
		rewrite="other"
	fi
	echo -e "You choose rewrite=\033[32m$rewrite\033[0m" 
	if [ -s "conf/$rewrite.conf" ];then
		/bin/cp conf/$rewrite.conf $web_install_dir/conf/$rewrite.conf
	else
		touch "$web_install_dir/conf/$rewrite.conf"
	fi
fi
}

Nginx_log()
{
while :
do
	echo ''
        read -p "Allow Nginx/Tengine access_log? [y/n]: " access_yn 
        if [ "$access_yn" != 'y' ] && [ "$access_yn" != 'n' ];then
                echo -e "\033[31minput error! Please only input 'y' or 'n'\033[0m"
        else
                break 
        fi
done
if [ "$access_yn" == 'n' ]; then
	N_log="access_log off;"
else
	N_log="access_log $wwwlogs_dir/${domain}_nginx.log combined;"
	echo -e "You access log file=\033[32m$wwwlogs_dir/${domain}_nginx.log\033[0m"
fi
}

Create_nginx_tomcat_conf()
{
[ -n "`grep $vhostdir $tomcat_install_dir/conf/server.xml`" ] && { echo -e "\n$vhostdir in the tomcat already exist! \nYou must manually modify the file=\033[32m$tomcat_install_dir/conf/server.xml\033[0m"; exit; }

[ ! -d $web_install_dir/conf/vhost ] && mkdir $web_install_dir/conf/vhost
cat > $web_install_dir/conf/vhost/$domain.conf << EOF
server {
listen 80;
server_name $domain$moredomainame;
$N_log
index index.html index.htm index.jsp index.php;
root $vhostdir;
#error_page 404 /404.html;
#if ( \$query_string ~* ".*[\;'\<\>].*" ){
#        return 404;
#        }
$anti_hotlinking
location ~ .*\.(gif|jpg|jpeg|png|bmp|swf|flv|ico)$ {
        expires 30d;
        }

location ~ .*\.(js|css)?$ {
        expires 7d;
        }

`echo -e $NGX_CONF`
}
EOF

sed -i "s@autoDeploy=\"true\">@autoDeploy=\"true\">\n\t<Context path=\"\" docBase=\"$vhostdir\" debug=\"0\" reloadable=\"true\" crossContext=\"true\"/>@" $tomcat_install_dir/conf/server.xml

echo
$web_install_dir/sbin/nginx -t
if [ $? == 0 ];then
        echo "Restart Nginx......"
        $web_install_dir/sbin/nginx -s reload
else
        rm -rf $web_install_dir/conf/vhost/$domain.conf
        echo -e "Create virtualhost ... \033[31m[FAILED]\033[0m"
        exit 1
fi

printf "
#######################################################################
#       OneinStack for CentOS/RadHat 5+ Debian 6+ and Ubuntu 12+      #
#       For more information please visit http://oneinstack.com       #
#######################################################################
"
echo -e "`printf "%-32s" "Your domain:"`\033[32m$domain\033[0m"
echo -e "`printf "%-32s" "Virtualhost conf:"`\033[32m$web_install_dir/conf/vhost/$domain.conf\033[0m"
echo -e "`printf "%-32s" "Directory of:"`\033[32m$vhostdir\033[0m"

}

Create_nginx_php-fpm_conf()
{
[ ! -d $web_install_dir/conf/vhost ] && mkdir $web_install_dir/conf/vhost
cat > $web_install_dir/conf/vhost/$domain.conf << EOF
server {
listen 80;
server_name $domain$moredomainame;
$N_log
index index.html index.htm index.jsp index.php;
include $rewrite.conf;
root $vhostdir;
#error_page 404 /404.html;
if ( \$query_string ~* ".*[\;'\<\>].*" ){
	return 404;
	}
$anti_hotlinking
`echo -e $NGX_CONF`

location ~ .*\.(gif|jpg|jpeg|png|bmp|swf|flv|ico)$ {
	expires 30d;
	}

location ~ .*\.(js|css)?$ {
	expires 7d;
	}
}
EOF

echo
$web_install_dir/sbin/nginx -t
if [ $? == 0 ];then
	echo "Restart Nginx......"
	$web_install_dir/sbin/nginx -s reload
else
	rm -rf $web_install_dir/conf/vhost/$domain.conf
	echo -e "Create virtualhost ... \033[31m[FAILED]\033[0m"
	exit 1
fi

printf "
#######################################################################
#       OneinStack for CentOS/RadHat 5+ Debian 6+ and Ubuntu 12+      #
#       For more information please visit http://oneinstack.com       #
#######################################################################
"
echo -e "`printf "%-32s" "Your domain:"`\033[32m$domain\033[0m"
echo -e "`printf "%-32s" "Virtualhost conf:"`\033[32m$web_install_dir/conf/vhost/$domain.conf\033[0m"
echo -e "`printf "%-32s" "Directory of:"`\033[32m$vhostdir\033[0m"
[ "$rewrite_yn" == 'y' ] && echo -e "`printf "%-32s" "Rewrite rule:"`\033[32m$rewrite\033[0m" 
}

Apache_log()
{
while :
do
        echo ''
        read -p "Allow Apache access_log? [y/n]: " access_yn
        if [ "$access_yn" != 'y' ] && [ "$access_yn" != 'n' ];then
                echo -e "\033[31minput error! Please only input 'y' or 'n'\033[0m"
        else
                break
        fi
done

if [ "$access_yn" == 'n' ]; then
        A_log='CustomLog "/dev/null" common'
else
        A_log="CustomLog \"/home/wwwlogs/${domain}_apache.log\" common"
        echo "You access log file=/home/wwwlogs/${domain}_apache.log"
fi
}

Create_apache_conf()
{
[ "`$apache_install_dir/bin/apachectl -v | awk -F'.' /version/'{print $2}'`" == '4' ] && R_TMP='Require all granted' || R_TMP=
[ ! -d $apache_install_dir/conf/vhost ] && mkdir $apache_install_dir/conf/vhost
cat > $apache_install_dir/conf/vhost/$domain.conf << EOF
<VirtualHost *:80>
    ServerAdmin admin@linuxeye.com 
    DocumentRoot "$vhostdir"
    ServerName $domain
    $Domain_alias
    ErrorLog "/home/wwwlogs/${domain}_error_apache.log"
    $A_log
<Directory "$vhostdir">
    SetOutputFilter DEFLATE
    Options FollowSymLinks
    $R_TMP
    AllowOverride All
    Order allow,deny
    Allow from all
    DirectoryIndex index.html index.php
</Directory>
</VirtualHost>
EOF

echo
$apache_install_dir/bin/apachectl -t
if [ $? == 0 ];then
	echo "Restart Apache......"
	/etc/init.d/httpd restart
else
	rm -rf $apache_install_dir/conf/vhost/$domain.conf
	echo -e "Create virtualhost ... \033[31m[FAILED]\033[0m"
	exit 1
fi

printf "
#######################################################################
#       OneinStack for CentOS/RadHat 5+ Debian 6+ and Ubuntu 12+      #
#       For more information please visit http://oneinstack.com       #
#######################################################################
"
echo -e "`printf "%-32s" "Your domain:"`\033[32m$domain\033[0m"
echo -e "`printf "%-32s" "Virtualhost conf:"`\033[32m$apache_install_dir/conf/vhost/$domain.conf\033[0m"
echo -e "`printf "%-32s" "Directory of $domain:"`\033[32m$vhostdir\033[0m"
}

Create_nginx_apache_mod-php_conf()
{
# Nginx/Tengine
[ ! -d $web_install_dir/conf/vhost ] && mkdir $web_install_dir/conf/vhost
cat > $web_install_dir/conf/vhost/$domain.conf << EOF
server {
listen 80;
server_name $domain$moredomainame;
$N_log
index index.html index.htm index.jsp index.php;
root $vhostdir;
#error_page 404 /404.html;
if ( \$query_string ~* ".*[\;'\<\>].*" ){
        return 404;
        }
$anti_hotlinking
location / {
        try_files \$uri @apache;
        }

location @apache {
        internal;
        proxy_pass http://127.0.0.1:9090;
	}

location ~ .*\.(php|php5)?$ {
        proxy_pass http://127.0.0.1:9090;
        }
location ~ .*\.(gif|jpg|jpeg|png|bmp|swf|flv|ico)$ {
        expires 30d;
        }

location ~ .*\.(js|css)?$ {
        expires 7d;
        }
}
EOF

echo
$web_install_dir/sbin/nginx -t
if [ $? == 0 ];then
        echo "Restart Nginx......"
        $web_install_dir/sbin/nginx -s reload
else
        rm -rf $web_install_dir/conf/vhost/$domain.conf
	echo -e "Create virtualhost ... \033[31m[FAILED]\033[0m"
fi

# Apache
[ "`$apache_install_dir/bin/apachectl -v | awk -F'.' /version/'{print $2}'`" == '4' ] && R_TMP='Require all granted' || R_TMP=
[ ! -d $apache_install_dir/conf/vhost ] && mkdir $apache_install_dir/conf/vhost
cat > $apache_install_dir/conf/vhost/$domain.conf << EOF
<VirtualHost *:9090>
    ServerAdmin admin@linuxeye.com
    DocumentRoot "$vhostdir"
    ServerName $domain
    $Domain_alias
    ErrorLog "/home/wwwlogs/${domain}_error_apache.log"
    $A_log
<Directory "$vhostdir">
    SetOutputFilter DEFLATE
    Options FollowSymLinks
    $R_TMP
    AllowOverride All
    Order allow,deny
    Allow from all
    DirectoryIndex index.html index.php
</Directory>
</VirtualHost>
EOF

echo
$apache_install_dir/bin/apachectl -t
if [ $? == 0 ];then
        echo "Restart Apache......"
        /etc/init.d/httpd restart
else
        rm -rf $apache_install_dir/conf/vhost/$domain.conf
	exit 1
fi

printf "
#######################################################################
#       OneinStack for CentOS/RadHat 5+ Debian 6+ and Ubuntu 12+      #
#       For more information please visit http://oneinstack.com       #
#######################################################################
"
echo -e "`printf "%-32s" "Your domain:"`\033[32m$domain\033[0m"
echo -e "`printf "%-32s" "Nginx Virtualhost conf:"`\033[32m$web_install_dir/conf/vhost/$domain.conf\033[0m"
echo -e "`printf "%-32s" "Apache Virtualhost conf:"`\033[32m$apache_install_dir/conf/vhost/$domain.conf\033[0m"
echo -e "`printf "%-32s" "Directory of:"`\033[32m$vhostdir\033[0m"
[ "$rewrite_yn" == 'y' ] && echo -e "`printf "%-32s" "Rewrite rule:"`\033[32m$rewrite\033[0m" 
}

if [ -d "$web_install_dir" -a ! -d "$apache_install_dir" -a "$web_install_dir" != "$apache_install_dir" ];then
	Choose_env
	Input_domain
	Nginx_anti_hotlinking
	if [ "$Number" == '111' -o "$Number" == '110' -o "$Number" == '011' -o "$Number" == '010' ];then
		Nginx_log
		Create_nginx_tomcat_conf
	else
		Nginx_rewrite
		Nginx_log
		Create_nginx_php-fpm_conf
	fi
elif [ -d "$web_install_dir" -a -d "$apache_install_dir" -a "$web_install_dir" == "$apache_install_dir" ];then
	Choose_env
	Input_domain
	Apache_log
	Create_apache_conf
elif [ -d "$web_install_dir" -a -d "$apache_install_dir" -a "$web_install_dir" != "$apache_install_dir" ];then
	Choose_env
	Input_domain
	Nginx_anti_hotlinking
	if [ "$Number" == '111' -o "$Number" == '110' -o "$Number" == '011' -o "$Number" == '010' ];then
		Nginx_log
		Create_nginx_tomcat_conf
	else
		#Nginx_rewrite
		Nginx_log
		Apache_log
		Create_nginx_apache_mod-php_conf
	fi
fi 
