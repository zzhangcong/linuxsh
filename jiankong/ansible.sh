#!/bin/bash
iptables -F
setenforce 0

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

#ansible安装
cd /root/
yum -y install lftp
lftp << EOF
open 172.25.254.250
cd /notes/project/UP200/UP200_Ansible-master
mirror pkg
cd /notes/project/software/lnmp_soft
get mysql-5.6.26.tar.gz
get nginx-1.8.0.tar.gz
cd /notes/weekend/UP200/UP200_tomcat-master/pkg
get apache-tomcat-8.0.24.tar.gz
bye
EOF

cd pkg/
yum -y  localinstall *.rpm

cd /etc/ansible
sed -i '76aprivate_key_file = \/root\/.ssh\/id_rsa' ansible.cfg
cat >> hosts <<EOT
[lx]
node1
node2
EOT

cat >> /etc/hosts << EOT
172.25.7.11 node1
172.25.7.12 node2
EOT


mkdir -p /ansible/roles/{nginx,mysql,tomcat,db}/{defaults,files,handlers,meta,tasks,templates,vars}

mv /root/mysql-5.6.26.tar.gz /ansible/roles/mysql/files/
mv /root/nginx-1.8.0.tar.gz /ansible/roles/nginx/files/
mv /root/apache-tomcat-8.0.24.tar.gz /ansible/roles/tomcat/files/

cat > /ansible/web.yml <<EOT
- hosts: lx
  remote_user: root
  roles:
    - nginx
    - mysql
    - tomcat
    - db
EOT

cat > /ansible/roles/db/tasks/main.yml <<EOT
- name: create db
  mysql_db: name=student state=present login_password=1 login_user=root login_unix_socket=/data/mysql/data/mysql.sock
- name: copy sql file
  copy: src=stu.sql dest=/tmp
- name: import sql
  mysql_db: name=student state=import target=/tmp/stu.sql login_password=1 login_user=root login_unix_socket=/data/mysql/data/mysql.sock
EOT

cat > /ansible/roles/db/files/stu.sql <<EOT
create table profile(name varchar(20),age tinyint);
insert into profile(name,age) values('teddy',12);
EOT


cat > /ansible/roles/nginx/tasks/main.yml <<EOT
- name: copy nginx_tar_gz to client
  copy: src=nginx-1.8.0.tar.gz dest=/tmp/nginx-1.8.0.tar.gz
- name: copy install_shell to client
  copy: src=install_nginx.sh dest=/tmp/install_nginx.sh
- name: install nginx
  shell: /bin/bash /tmp/install_nginx.sh
EOT

cat > /ansible/roles/mysql/tasks/main.yml <<EOT
- name: copy mysql_tar_gz to client
  copy: src=mysql-5.6.26.tar.gz dest=/tmp/mysql-5.6.26.tar.gz
- name: copy install_script to client
  copy: src=mysql_install.sh dest=/tmp/mysql_install.sh owner=root group=root mode=755
- name: install mysql
  shell: /bin/bash /tmp/mysql_install.sh
EOT

cat > /ansible/roles/tomcat/tasks/main.yml <<EOT
- name: install java
  yum: name=java-1.7.0-openjdk state=present
- name: group
  group: name=tomcat
- name: user
  user: name=tomcat group=tomcat home=/usr/tomcat
  sudo: True
- name: copy tomcat_tar_gz
  copy: src=apache-tomcat-8.0.24.tar.gz dest=/tmp/apache-tomcat-8.0.24.tar.gz
- name: Extract archive
  command: /bin/tar xf /tmp/apache-tomcat-8.0.24.tar.gz -C /opt/
- name: Symlink install directory
  file: src=/opt/apache-tomcat-8.0.24/ dest=/usr/share/tomcat state=link
- name: Change ownership of Tomcat installation
  file: path=/usr/share/tomcat/ owner=tomcat group=tomcat state=directory recurse=yes
- name: Configure Tomcat users
  template: src=tomcat-users.xml dest=/usr/share/tomcat/conf/
  notify: restart tomcat
- name: Install Tomcat init script
  copy: src=tomcat-initscript.sh dest=/etc/init.d/tomcat mode=0755
- name: Start Tomcat
  service: name=tomcat state=started enabled=yes
EOT

cat > /ansible/roles/tomcat/handlers/main.yml <<EOT
- name: restart tomcat 
  service: name=tomcat state=restarted
EOT

cat > /ansible/roles/nginx/files/install_nginx.sh <<EOT
#!/bin/bash
yum -y install gcc gcc-c++ cmake make  zlib zlib-devel openssl openssl-devel pcre-devel
groupadd -r nginx
useradd -s /sbin/nologin -g nginx -r nginx
cd /tmp
tar xf nginx-1.8.0.tar.gz;cd nginx-1.8.0
mkdir /var/run/nginx/;chown nginx.nginx /var/run/nginx/
./configure \
--prefix=/usr \
--sbin-path=/usr/sbin/nginx \
--conf-path=/etc/nginx/nginx.conf \
--error-log-path=/var/log/nginx/error.log \
--pid-path=/var/run/nginx/nginx.pid \
--user=nginx \
--group=nginx \
--with-http_ssl_module
make && make install
sed  "/^\s*index / i proxy_pass http:\/\/localhost:8080;" /etc/nginx/nginx.conf
/usr/sbin/nginx 
EOT

cat > /ansible/roles/mysql/files/mysql_install.sh <<EOT
#!/bin/bash
DBDIR='/data/mysql/data'
PASSWD='1'
[ -d \$DBDIR ] || mkdir \$DBDIR -p
yum install cmake make gcc-c++ gcc bison-devel ncurses-devel -y
id mysql &> /dev/null
if [ \$? -ne 0 ];then
 useradd mysql -s /sbin/nologin -M
fi
chown -R mysql.mysql \$DBDIR
cd /tmp/
tar xf mysql-5.6.26.tar.gz
cd mysql-5.6.26
cmake . -DCMAKE_INSTALL_PREFIX=/usr/local/mysql \
-DMYSQL_DATADIR=\$DBDIR \
-DMYSQL_UNIX_ADDR=\$DBDIR/mysql.sock \
-DDEFAULT_CHARSET=utf8 \
-DEXTRA_CHARSETS=all \
-DENABLED_LOCAL_INFILE=1 \
-DWITH_READLINE=1 \
-DDEFAULT_COLLATION=utf8_general_ci \
-DWITH_EMBEDDED_SERVER=1
if [ \$? != 0 ];then
 echo "cmake error!"
 exit 1
fi
make && make install
if [ \$? -ne 0 ];then
 echo "install mysql is failed!" && /bin/false
fi
sleep 2
ln -s /usr/local/mysql/bin/* /usr/bin/
cp -f /usr/local/mysql/support-files/my-default.cnf /etc/my.cnf
cp -f /usr/local/mysql/support-files/mysql.server /etc/init.d/mysqld
chmod 700 /etc/init.d/mysqld
/usr/local/mysql/scripts/mysql_install_db  --basedir=/usr/local/mysql --datadir=\$DBDIR --user=mysql
if [ \$? -ne 0 ];then
 echo "install mysql is failed!" && /bin/false
fi
/etc/init.d/mysqld start
if [ \$? -ne 0 ];then
 echo "install mysql is failed!" && /bin/false
fi
chkconfig --add mysqld
chkconfig mysqld on
/usr/local/mysql/bin/mysql -e "update mysql.user set password=password('\$PASSWD') where host='localhost' and user='root';"
/usr/local/mysql/bin/mysql -e "update mysql.user set password=password('\$PASSWD') where host='127.0.0.1' and user='root';"
/usr/local/mysql/bin/mysql -e "delete from mysql.user where password='';"
/usr/local/mysql/bin/mysql -e "flush privileges;"
if [ \$? -eq 0 ];then
 echo "ins_done"
fi

EOT


cd /ansible
ansible-playbook web.yml --syntax-check
ansible-playbook web.yml

