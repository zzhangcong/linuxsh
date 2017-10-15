#!/bin/bash
rpm -e MySQL-client-5.6.20-1.el7.x86_64
rpm -e MySQL-server-5.6.20-1.el7.x86_64
rm -rf /root/.mysql_secret
rm -rf /var/lib/mysql/*

rpm -e mariadb-libs --nodeps  &> /dev/null
rpm -ivh MySQL-client-5.6.20-1.el7.x86_64.rpm &> /dev/null
yum -y install perl-Data-Dumper.x86_64 &> /dev/null
rpm -ivh MySQL-server-5.6.20-1.el7.x86_64.rpm &> /dev/null
systemctl restart mysql
netstat -tnpl | grep mysql
i=$(awk 'NR==1{print $NF}' /root/.mysql_secret)

expect <<EOF &> /dev/null
spawn mysql_secure_installation
expect "none)"
send "$i\n"
expect "password?"
send "Y\n"
expect "password:"
send "123\n"
expect "password:"
send "123\n"
expect "users?"
send "Y\n"
expect "remotely?"
send "n\n"
expect "to it?"
send "Y\n"
expect "now?"
send "Y\n"
expect eof
EOF

mysql -p123 -e "show databases;"

