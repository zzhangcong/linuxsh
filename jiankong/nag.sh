#!/bin/bash
iptables -F
setenforce 0

cd ~
yum -y install expect
yum -y install lftp
cat > /ssh_key.sh << EOT
!/bin/bash
passwd=uplooking
keydir=\$HOME/.ssh
#放钥匙的目录
skey=\$keydir/id_rsa
#公钥
pkey=\$keydir/id_rsa.pub
#私钥
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


cd ~
#下载文件
lftp << EOF
open 172.25.254.250
cd /notes/project/UP200/UP200_nagios-master
mirror pkg
cd /notes/project/software/nagios
get nrpe-2.12.tar.gz
bye
EOF

cd pkg
htpasswd -cmb /etc/nagios/passwd nagiosadmin 1

sed -i "s#        alias                   localhost#        alias                   nagios监控器#" cat /etc/nagios/objects/localhost.cfg


systemctl restart httpd
systemctl restart nagios
