#!/bin/bash
iptables -F
setenforce 0
timedatectl set-timezone Asia/Shanghai
ntpdate -u 172.25.254.254
#推送密钥对
cd ~
yum -y install lftp

cat > /ssh_key.sh << EOT
#!/bin/bash

yum -y install expect
passwd=uplooking
keydir=\$HOME/.ssh
###放钥匙的目录
skey=\$keydir/id_rsa
##公钥
pkey=\$keydir/id_rsa.pub
##私钥
   [ -f \$skey -a -f \$pkey ] || \$(ssh-keygen -q -f \$skey -N "")
   for i in {11..14}
   do
      expect <<EOF
             spawn ssh-copy-id root@172.25.7.\$i
                  expect {
                           "*(yes/no)*" { send  "yes\r";exp_continue}
                           "*password:" { send "\$passwd\r";exp_continue}
                             eof{exit}
                         }

EOF
        done
ssh-add
EOT
chmod +x /ssh_key.sh
sh /ssh_key.sh

scp /ssh_key.sh 172.25.7.11:/
ssh root@172.25.7.11 "sh /ssh_key.sh"

#关闭防火墙和selinux并同步(时区)服务器时间
for i in {11..14};do ssh root@172.25.7.$i "iptables -F; setenforce 0; timedatectl set-timezone Asia/Shanghai; ntpdate -u 172.25.254.254"; done


#下载文件
lftp << EOF
open 172.25.254.250
cd /notes/project/software/zabbix
mirror zabbix3.2/
bye
EOF

for i in {11..14};do rsync -azR /root/zabbix3.2 root@172.25.7.$i:/; done

cat > /serb.sh << EOT
#!/bin/bash
cd /root/zabbix3.2/
tar xf zabbix-3.2.7.tar.gz -C /usr/local/src/
yum -y install gcc gcc-c++ mariadb-devel libxml2-devel net-snmp-devel libcurl-devel

cd /usr/local/src/zabbix-3.2.7/
./configure --prefix=/usr/local/zabbix --enable-server --with-mysql --with-net-snmp --with-libcurl --with-libxml2 --enable-agent --enable-ipv6
make
make install
useradd zabbix
cd /usr/local/zabbix/etc/
sed -i "s/DBHost=.*/DBHost=172.25.7.13/" zabbix_server.conf
sed -i "s/#DBPassword=.*/DBpassword=1/" zabbix_server.conf
cd /usr/local/src/zabbix-3.2.7/database/mysql/
scp -r * 172.25.7.13:/root/
/usr/local/zabbix/sbin/zabbix_server
netstat -tnlp |grep zabbix
EOT
chmod +x /serb.sh
rsync -apzR /serb.sh 172.25.7.11:/
ssh root@172.25.7.11 "sh /serb.sh"

cat > /serd.sh <<EOT
#!/bin/bash
yum -y install mariadb mariadb-server
systemctl start mariadb
mysql -e "create database zabbix;"
mysql zabbix < /root/schema.sql
mysql zabbix < /root/images.sql
mysql zabbix < /root/data.sql
mysql -e "grant all on zabbix.* to zabbix@'%' identified by '1';"
mysql -e "flush privileges;"
mysqldump zabbix > /tmp/zabbix.sql
sed -i 's/latinl/utf8/' /tmp/zabbix.sql
mysqladmin drop zabbix
mysql -e "create database zabbix default charset utf8;"
mysql zabbix < /tmp/zabbix.sql

EOT
chmod +x /serd.sh
rsync -apzR /serd.sh 172.25.7.13:/
ssh root@172.25.7.13 "sh /serd.sh"


cat > /serc.sh <<EOT
#!/bin/bash
cd /root/zabbix3.2/
yum -y install httpd php php-mysql
yum -y localinstall php-mbstring-5.4.16-23.el7_0.3.x86_64.rpm php-bcmath-5.4.16-23.el7_0.3.x86_64.rpm
yum -y localinstall zabbix-web-3.2.7-1.el7.noarch.rpm zabbix-web-mysql-3.2.7-1.el7.noarch.rpm

sed -i "s/        # php_value date.timezone Europe\/Riga\/        php_value date.timezone Asia\/Shangha\//" /etc/httpd/conf.d/zabbix.conf

cd /root/
yum -y install wqy-microhei-fonts
wget ftp://172.25.254.250/notes/project/software/zabbix/simkai.ttf
cp /root/simkai.ttf /usr/share/zabbix/fonts/
sed -i "s/graphfont/simkai/g" /usr/share/zabbix/include/defines.inc.php
systemctl restart httpd
EOT

chmod +x /serc.sh
rsync -apzR /serc.sh 172.25.7.12:/
ssh root@172.25.7.12 "sh /serc.sh"



cd /root/zabbix3.2/
rpm -ivh zabbix-agent-3.2.7-1.el7.x86_64.rpm
yum -y install net-snmp net-snmp-utils
sed -i "s/127.0.0.1/172.25.7.11/g" /etc/zabbix/zabbix_agentd.conf 
sed -i "s/^Hostname=.*/Hostname=servera.pod7.example.com/" /etc/zabbix/zabbix_agentd.conf

rpm -ivh  ftp://172.25.254.250/notes/project/UP200/UP200_nginx-master/pkg/nginx-1.8.1-1.el7.ngx.x86_64.rpm
rpm -ivh ftp://172.25.254.250/notes/project/UP200/UP200_nginx-master/pkg/nginx-1.8.1-1.el7.ngx.x86_64.rpm

cat > /etc/nginx/conf.d/default.conf <<EOT
server {
    listen       80;
    server_name  localhost;

    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }

    location /nginx_status {
        stub_status on;
    }

    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }

}

EOT


systemctl restart nginx
rsync -avzR /etc/nginx/conf.d/default.conf root@172.25.7.14:/
ssh root@172.25.7.14 "systemctl restart nginx"
mkdir /etc/zabbix/scripts -p
cd /etc/zabbix/scripts/
wget ftp://172.25.254.250/notes/project/software/zabbix/zabbix_nginx_check.sh
chmod +x zabbix_nginx_check.sh
sed -i "s#^\# UserParameter=.*#UserParameter=custom.nginx.status[*],\/etc/zabbix\/scripts\/zabbix_nginx_check.sh \$1#" /etc/zabbix/zabbix_agentd.conf

systemctl restart zabbix-agent
rsync -avzR /etc/zabbix/scripts/ /etc/zabbix/zabbix_agentd.conf root@172.25.7.14:/

ssh root@172.25.7.14 "systemctl restart zabbix-agent"

