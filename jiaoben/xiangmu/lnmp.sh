#!/bin/bash

iptables -F
setenforce 0

#设置servera上免密登陆其他服务器
yum -y install expect &> /dev/null

passwd=uplooking
keydir=$HOME/.ssh
#放钥匙的目录
skey=$keydir/id_rsa
#公钥
pkey=$keydir/id_rsa.pub
#私钥
[ -f $skey -a -f $pkey ] || $(ssh-keygen -q -f $skey -N "")
for i in {11..13}
do
        expect <<EOF
       spawn ssh-copy-id root@172.25.7.$i
       expect {
                "*(yes/no)*" { send  "yes\r";exp_continue}
                "*password:" { send "$passwd\r";exp_continue}
                eof{exit}
              }
EOF
done
ssh-add

#servera(172.25.7.10)上配置
#1)下载文件
cd ~
lftp << EOF
open 172.25.254.250
cd /notes/weekend/UP200/UP200_nginx-master
mirror pkg
cd /notes/project/software/lnmp
get Discuz_X3.1_SC_UTF8.zip
bye
EOF

cd pkg/
rpm -ivh nginx-1.8.1-1.el7.ngx.x86_64.rpm &> /dev/null && echo "nginx---OK"
rpm -ivh spawn-fcgi-1.6.3-5.el7.x86_64.rpm &> /dev/null && echo "fcgi---OK"
yum -y install php php-mysql mariadb-server &> /dev/null && echo "php---OK"

#2)配置虚拟主机
cd /etc/nginx/conf.d/
cp default.conf www.bbs.com.conf
cat > www.bbs.com.conf << EOT
server {
    listen       80;
    server_name  www.bbs.com;
    root /usr/share/nginx/bbs;
    index index.php index.html index.htm;
    location ~ \.php$ {
        fastcgi_pass php_pools;   
 	    fastcgi_index index.php;
	    fastcgi_param SCRIPT_FILENAME /usr/share/nginx/bbs\$fastcgi_script_name;
	    include fastcgi_params;

}
}
EOT

sed -i "21aupstream php_pools {" /etc/nginx/nginx.conf
sed -i "22a     server 172.25.7.12:9000;" /etc/nginx/nginx.conf
sed -i "23a     server 172.25.7.13:9000;" /etc/nginx/nginx.conf
sed -i "24a}"




mkdir /usr/share/nginx/bbs
systemctl restart nginx.service

#3)配置spawn-fcgi
cat >> /etc/sysconfig/spawn-fcgi << EOT
OPTIONS="-u 996 -g 994 -p 9000 -C 32 -F 1 -P /var/run/spawn-fcgi.pid -- /usr/bin/php-cgi"
EOT
systemctl start spawn-fcgi
chkconfig spawn-fcgi on

cat > /usr/share/nginx/bbs/test.php << EOT
<?php
   phpinfo();
?>
EOT

#4)数据库初始化
systemctl restart mariadb.service
systemctl enable mariadb.service
mysqladmin -u root password "redhat"

#5)创建数据根目录
cp /root/Discuz_X3.2_SC_UTF8.zip /tmp/
cd /tmp/
unzip Discuz_X3.2_SC_UTF8.zip
cp -r upload/* /usr/share/nginx/bbs/
chown nginx. /usr/share/nginx/bbs/ -R


#6)数据库授权
mysql -predhat -e "grant all on bbs.* to runbbs@'%' identified by 'redhat';"
mysql -predhat -e "flush privileges;"

mysqldump --all-databases -uroot -predhat > /tmp/mariadb.all.sql
scp /tmp/mariadb.all.sql 172.25.7.11:/tmp/

for i in $(find /usr/share/nginx/bbs/ -name '*.php');do grep -q "172.25." $i && echo $i;done

#更换数据库的IP地址
sed -i "s/localhost/172\.25\.7\.11/g" /usr/share/nginx/bbs/config/config_global.php
sed -i "s/localhost/172\.25\.7\.11/g" /usr/share/nginx/bbs/config/config_ucenter.php
sed -i "s/localhost/172\.25\.7\.11/g" /usr/share/nginx/bbs/uc_server/data/config.inc.php
sed -i "s/localhost/172\.25\.7\.11/g" /usr/share/nginx/bbs/uc_client/data/cache/apps.php

#迁移数据文件
tar cf /tmp/datafile.tar /usr/share/nginx/bbs/
scp /tmp/datafile.tar 172.25.7.12:/tmp/

systemctl restart nginx.service
systemctl stop spawn-fcgi.service



mount 172.25.0.19:/usr/share/nginx/bbs /usr/share/nginx/bbs



#数据库迁移(迁移到serverb:172.25.7.11)
#1)迁移mariadb-server程序
cat > /qyb.sh << EOF
#!/bin/bash
iptables -F
setenforce 0

yum -y install mariadb-server
systemctl restart mariadb
systemctl enable mariadb

mysql < /tmp/mariadb.all.sql
systemctl restart mariadb

echo "grant all on bbs.* to root@'172.25.7.10' identified by 'redhat';" | mysql -uroot -predhat

echo "grant all on bbs.* to root@'servera.pod7.example.com' identified by 'redhat';" | mysql -uroot -predhat

echo "grant all on bbs.* to root@'172.25.7.12' identified by 'redhat';" | mysql -uroot -predhat

echo "grant all on bbs.* to root@'serverc.pod7.example.com' identified by 'redhat';" | mysql -uroot -predhat

echo "grant all on . to root@'172.25.7.13' identified by 'redhat';" | mysql -uroot -predhat

echo "grant all on . to root@'serverd.pod7.example.com' identified by 'redhat';" | mysql -uroot -predhat

mysqladmin -uroot -predhat flush-privileges

EOF

chmod +x /qyb.sh
rsync -av /qyb.sh 172.25.7.11:/



#PHP迁移(迁移到serverc:172.25.7.12)
#1)安装php php-mysql spawn-fcgi程序
cat > qyc.sh << EOF
#!/bin/bash
iptables -F
setenforce 0


yum -y install php php-mysql &> /dev/null && echo "php与php-mysql安装成功"

rpm -ivh ftp://172.25.254.250/notes/project/UP200/UP200_nginx-master/pkg/spawn-fcgi-1.6.3-5.el7.x86_64.rpm &> /dev/null && echo "fcgi安装成功"

groupadd -g 994 nginx
useradd -u 996 -g 994 nginx
tar xf /tmp/datafile.tar -C / &> /dev/null
chown nginx.nginx -R /usr/share/nginx/bbs/

systemctl restart spawn-fcgi.service


scp /etc/sysconfig/spawn-fcgi 172.25.7.13:/etc/sysconfig/
tar cf /tmp/data.tar /usr/share/nginx/bbs/
scp /tmp/data.tar 172.25.7.13:/tmp/

tar cf /tmp/data1.tar /usr/share/nginx/bbs/
scp /tmp/data1.tar 172.25.7.14:/tmp/

mount 172.25.0.19:/usr/share/nginx/bbs /usr/share/nginx/bbs

EOF


#PHP程序复制(复制到serverd:172.25.7.13)
cat > /qyd.sh <<EOF
#!/bin/bash
iptables -F
setenforce 0

rpm -ivh ftp://172.25.254.250/notes/project/UP200/UP200_nginx-master/pkg/spawn-fcgi-1.6.3-5.el7.x86_64.rpm
yum -y install php php-mysql &> /dev/null && echo "php与php-mysql安装成功"

tar xf /tmp/data.tar -C /
groupadd -g 994 nginx
useradd -u 996 -g nginx nginx
systemctl start spawn-fcgi.service

mount 172.25.0.19:/usr/share/nginx/bbs /usr/share/nginx/bbs

EOF
chmod +x /qyd.sh
rsync -av /qyd.sh 172.25.7.13:/



#共享存储servere(172.25.7.14)
cat > /qyd.sh << EOF
#!/bin/bash
iptables -F
setenforce 0

yum -y install nfs-utils &> /dev/null
yum -y install rpcbind

tar -xf /tmp/data1.tar -C /
groupadd -g 994 nginx
useradd -u 996 -g nginx nginx

cat > /etc/exports << EOT

/usr/share/nginx/bbs 172.25.7.0/255.255.255.0(rw)

EOT

systemctl start rpcbind
systemctl restart nfs-server


EOF
chmod +x /qyd.sh
rsync -av /qyd.sh 172.25.7.14:/ 

