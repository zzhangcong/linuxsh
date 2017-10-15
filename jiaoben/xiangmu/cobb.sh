#!/bin/bash
#1.更改主机名，关闭selinux，设置网关
hostnamectl set-hostname cobbler
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config 
setenforce 0
iptables -F

sed -i 's/ONBOOT=yes/ONBOOT=no/' /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i '$a GATEWAY=192.168.0.10' /etc/sysconfig/network-scripts/ifcfg-eth1
service restart network

#2.下载软件，并安装
wget -r ftp://172.25.254.250/notes/project/software/cobbler_rhel7/
mv 172.25.254.250/notes/project/software/cobbler_rhel7/ cobbler
cd cobbler/
rpm -ivh python2-simplejson-3.10.0-1.el7.x86_64.rpm
rpm -ivh python-django-1.6.11.6-1.el7.noarch.rpm python-django-bash-completion-1.6.11.6-1.el7.noarch.rpm
yum -y localinstall cobbler-2.8.1-2.el7.x86_64.rpm cobbler-web-2.8.1-2.el7.noarch.rpm


#3.启动服务
systemctl restart cobblerd
systemctl restart httpd
systemctl restart xinetd
systemctl enable xinetd
systemctl enable httpd
systemctl enable cobblerd


#4.解决cobbler check里面的环境问题
sed -i 's/^server.*/server:\ 192.168.0.11/' /etc/cobbler/settings
sed -i 's/^next_server.*/next_server:\ 192.168.0.11/' /etc/cobbler/settings

#激活tftp服务
sed -i 's/disable.*/disable\ =\ no/' /etc/xinetd.d/tftp

#关闭selinux

#网络引导文件
yum -y install syslinux
systemctl restart rsyncd
systemctl enable rsyncd
netstat -tnlp |grep :873

yum -y install pykickstart

#设置模板的（root用户）密码变量
i=$(openssl passwd -1 -salt 'random-phrase-here' 'redhat')
sed -i "s/^default_password_crypted.*/default_password_crypted: \"${i}\"/" /etc/cobbler/settings

#安装fence设备
yum -y install fence-agents


#5.导入镜像
mkdir /yum
mount -t nfs 172.25.254.250:/content /mnt/
mount -o loop /mnt/rhel7.2/x86_64/isos/rhel-server-7.2-x86_64-dvd.iso /yum/
cobbler import --path=/yum --name=rhel-server-7.2-base --arch=x86_64

#6.修改dhcp，让cobbler来管理dhcp，并进行cobbler配置同步
yum -y install dhcp
sed 's/192.168.1/192.168.0/g' /etc/cobbler/dhcp.template

#cat > /etc/cobbler/dhcp.template << EOT
#subnet 192.168.0.0 netmask 255.255.255.0 {
#     option routers             192.168.0.10;
#     option domain-name-servers 172.25.254.254;
#     option subnet-mask         255.255.255.0;
#     range dynamic-bootp        192.168.0.100 192.168.0.200;
#     default-lease-time         21600;
#     max-lease-time             43200;
#     next-server                $next_server;
#     class "pxeclients" {
#          match if substring (option vendor-class-identifier, 0, 9) = "PXEClient";
#          if option pxe-system-type = 00:02 {
#                  filename "ia64/elilo.efi";
#          } else if option pxe-system-type = 00:06 {
#                  filename "grub/grub-x86.efi";
#          } else if option pxe-system-type = 00:07 {
#                  filename "grub/grub-x86_64.efi";
#          } else {
#                  filename "pxelinux.0";
#          }
#     }
#
#}
#
#EOT

sed -i 's/manage_dhcp:.*/manage_dhcp:\ 1/' /etc/cobbler/settings

systemctl restart cobblerd

cobbler sync

systemctl restart xinetd
