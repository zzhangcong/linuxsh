#!/bin/bash

	read -p "请输入IP（例：172.25.14.10）:" ip


	read -p "请输入域名（例：www.baidu.com）:" yu
	
read -p "请输入根目录(例：/test):" gm

rpm -e httpd &> /dev/null
rm -rf /etc/httpd/conf/httpd.conf.rpmsave
rm -rf $gm


rpm -q httpd &> /dev/null
[ $? -eq 0 ] && echo "httpd已经安装" || yum -y install httpd  &> /dev/null && echo "httpd安装成功"

iptables -F
setenforce 0

sed -i '/Listen 80/c#Listen 80' /etc/httpd/conf/httpd.conf
cat >> /etc/httpd/conf/httpd.conf   <<END
Listen $ip:80
<VirtualHost $ip:80>
	DocumentRoot "$gm"
	ServerAdmin root.example.com
	ServerName $yu
</VirtualHost>
<Directory "$gm">	
	AllowOverride None
	Require all granted
</Directory>
END

mkdir -p  $gm
chmod 777 -R $gm
echo "this is test page" > $gm/index.html

systemctl restart httpd

