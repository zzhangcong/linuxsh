#!/bin/bash
iptables -F
setenforce 0
#推送密钥对
cd ~
yum -y install expect
yum -y install lftp
cat > /ssh_key.sh << EOT
#!/bin/bash
passwd=uplooking
keydir=\$HOME/.ssh
###放钥匙的目录
skey=\$keydir/id_rsa
##公钥
pkey=\$keydir/id_rsa.pub
##私钥
   [ -f \$skey -a -f \$pkey ] || \$(ssh-keygen -q -f \$skey -N "")
   for i in {11..12}
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

#关闭防火墙和selinux
for i in {11..12};do ssh root@172.25.7.$i "iptables -F; setenforce 0"; done

#下载文件
lftp << EOF
open 172.25.254.250
cd /notes/project/UP200/UP200_cacti-master
mirror pkg
bye
EOF

#配置
cd pkg/
yum -y install httpd php php-mysql mariadb-server mariadb
yum -y localinstall cacti-0.8.8b-7.el7.noarch.rpm php-snmp-5.4.16-23.el7_0.3.x86_64.rpm
yum -y install net-snmp

#数据库授权，并修改对应配置文件
service mariadb start
mysql -e "create database cacti;grant all on cacti.* to cactidb@'localhost' identified by '1';flush privileges;"

sed -i "s#\$database_username.*#\$database_username = \"cactidb\";#" /etc/cacti/db.php
sed -i "s#\$database_password.*#\$database_password = \"1\";#" /etc/cacti/db.php

sed -i "s#com2sec notConfigUser  default       public#com2sec notConfigUser  default       publicurl#" /etc/snmp/snmpd.conf

sed -i "54a#view    systemview    included   .1" /etc/snmp/snmpd.conf
sed -i "55s/\#//" /etc/snmp/snmpd.conf

#上传数据库表结构
mysql -ucactidb -p1 cacti < /usr/share/doc/cacti-0.8.8b/cacti.sql

sed -i "s#Require host localhost#Require all granted#g" /etc/httpd/conf.d/cacti.conf

#修改时区
timedatectl set-timezone Asia/Shanghai
sed -i "s#;date.timezone.*#date.timezone = \'Asia/Shanghai\'#" /etc/php.ini

#变更计划任务，五分钟轮询一次图
sed -i "1s/\#//" /etc/cron.d/cacti

service httpd restart
service snmpd restart

for i in {11..12};do ssh root@172.25.7.$i "yum -y install net-snmp; timedatectl set-timezone Asia/Shanghai"; done
for i in {11..12};do rsync -avzR /etc/snmp/snmpd.conf 172.25.7.$i:/; done
for i in {11..12};do ssh root@172.25.7.$i "service snmpd restart"; done


