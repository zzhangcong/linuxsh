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
get nagios-plugins-1.4.14.tar.gz
bye
EOF

cd pkg
yum -y localinstall *.rpm
htpasswd -cmb /etc/nagios/passwd nagiosadmin 1

sed -i "s#        alias                   localhost#        alias                   nagios监控器#" cat /etc/nagios/objects/localhost.cfg


systemctl restart httpd
systemctl restart nagios


cat > /sbc.sh << EOT
#!/bin/bash
cd ~
useradd nagios
echo 1 | passwd --stdin nagios
tar xf nagios-plugins-1.4.14.tar.gz
tar xf nrpe-2.12.tar.gz
cd nagios-plugins-1.4.14/
yum -y install gcc openssl-devel xinetd
./configure
make
make install
chown nagios.nagios /usr/local/nagios
chown -R nagios.nagios /usr/local/nagios/libexec
cd /root/nrpe-2.12/
./configure
make all
make install-plugin
make install-daemon
make install-daemon-config
make install-xinetd

sed -i "s#only_from.*#        only_from       = 127.0.0.1 172.25.7.10#g" /etc/xinetd.d/nrpe

sed -i "28a/nrpe            5666/tcp                # nrpe/" /etc/services

sed -i "s#hda1#vda1#g" /usr/local/nagios/etc/nrpe.cfg
sed -i "203a#command[check_swap]=/usr/local/nagios/libexec/check_swap -w 20% -c 10%#" /usr/local/nagios/etc/nrpe.cfg
systemctl restart xinetd
/usr/local/nagios/libexec/check_nrpe -H localhost


systemctl restart xinetd

EOT
chmod +x /sbc.sh 

for i in {11..12};do rsync -avzR /root/nagios-plugins-1.4.14.tar.gz root@172.25.7.$i:/; done
for i in {11..12};do rsync -avzR /root/nrpe-2.12.tar.gz root@172.25.7.$i:/; done

for i in {11..12};do rsync -avzR /sbc.sh root@172.25.7.$i:/; done
for i in {11..12};do ssh root@172.25.7.$i "sh /sbc.sh"; done

cat >> /etc/nagios/objects/commands.cfg <<EOT
define command{
        command_name check_nrpe
        command_line \$USER1$/check_nrpe -H \$HOSTADDRESS$ -c \$ARG1$
}
EOT

cat > /etc/nagios/objects/serverb.cfg <<EOT
define host{
        use                     linux-server 
        host_name               serverb.pod7.example.com
        alias                   serverb
        address                 172.25.7.11
        }
define hostgroup{
        hostgroup_name  lx-servers 
        alias           lx
        members         serverb.pod7.example.com     
        }

define service{
        use generic-service
        host_name serverb.pod7.example.com
        service_description load
        check_command check_nrpe!check_load
}
define service{
        use generic-service
        host_name serverb.pod7.example.com
        service_description user
        check_command check_nrpe!check_users
}

define service{
        use generic-service
        host_name serverb.pod7.example.com
        service_description root
        check_command check_nrpe!check_vda1
}

define service{
        use generic-service
        host_name serverb.pod7.example.com
        service_description zombie
        check_command check_nrpe!check_zombie_procs
}



define service{
        use generic-service
        host_name serverb.pod7.example.com
        service_description procs
        check_command check_nrpe!check_total_procs
}


define service{
        use generic-service
        host_name serverb.pod7.example.com
        service_description swap
        check_command check_nrpe!check_swap
}
EOT
cp -a /etc/nagios/objects/serverb.cfg /etc/nagios/objects/serverc.cfg
sed -i "s#serverb#serverc#g" /etc/nagios/objects/serverc.cfg
sed -i "s#172.25.7.11#172.25.7.12#g" /etc/nagios/objects/serverc.cfg

sed -i "36a#cfg_file=/etc/nagios/objects/serverb.cfg" /etc/nagios/nagios.cfg
sed -i "37a#cfg_file=/etc/nagios/objects/serverc.cfg" /etc/nagios/nagios.cfg

nagios -v /etc/nagios/nagios.cfg
systemctl restart nagios

/usr/lib64/nagios/plugins/check_nrpe -H 172.25.7.11
/usr/lib64/nagios/plugins/check_nrpe -H 172.25.7.12

/usr/lib64/nagios/plugins/check_nrpe -H 172.25.7.11 -c check_swap
/usr/lib64/nagios/plugins/check_nrpe -H 172.25.7.12 -c check_swap
