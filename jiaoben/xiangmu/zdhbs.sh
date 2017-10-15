#!/bin/bash
#servera上配置路由
#expect <<EOF &> /dev/null
#spawn ssh root@172.25.7.10
#expect "password:"
#send "uplooking\n"
#EOF
#
#iptables -F
#setenforce 0
#
#cat >> /etc/sysctl.conf << EOT
#net.ipv4.ip_forward = 1
#EOT
#sysctl -p
#
#iptables -t nat -A POSTROUTING -s 192.168.0.0/24 -j SNAT --to-source 172.25.7.10
#
#expect << EOF &> /dev/null
#spawn ssh root@192.168.0.16
#expect "no)?"
#send "yes\n"
#send "uplooking\n"
#EOF
#
#iptables -F
#setenforce 0
##关闭桥接网路
#sed -i 's/^ONBOOT=yes/ONBOOT=no' /etc/sysconfig/network-scripts/ifcfg-eth0
#sed -i '$a GATEWAY=192.168.0.10' /etc/sysconfig/network-scripts/ifcfg-eth1
#systemctl restart network
#route -n | head -3 | tail -1
#关闭selinux
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
echo "/sbin/setenforce 0" >> /etc/rc.local
chmod +x /etc/rc.local
source  /etc/rc.local
iptables -F
ping -c 3 172.25.254.254 &> /dev/null && echo "网络连接正常" || echo "请检查网路"

#挂载
#网路挂载
mount -t nfs 172.25.254.250:/content /mnt/
mkdir -p /rhel7s1
mkdir -p /rhel6s5
cat >> /etc/fstab << EOF
172.25.254.250:/content  /mnt  nfs  ro  0 0
/mnt/rhel7.1/x86_64/isos/rhel-server-7.1-x86_64-dvd.iso  /rhel7s1  iso9660   ro  0 0

/mnt/rhel6.5/x86_64/isos/rhel-server-6.5-x86_64-dvd.iso  /rhel6s5 iso9660 ro 0 0
EOF
find /etc/yum.repos.d/ -regex '.*\repo$' -exec mv {} {}.back \;
cat > /etc/yum.repos.d/local.repo << EOT
[local]
baseurl=file:///rhel7s1
gpgcheck=0
EOT

mount -a

yum clean all &> /dev/null
yum repolist &> /dev/null


#本地源
#find /etc/yum.repos.d/ -regex '.*\repo$' -exec mv {} {}.back \;
#cat > /etc/yum.repos.d/base.repo << EOT
#[base]
#baseurl=file:///rhel7s1
#gpgpcheck=0
#EOT
#
#mount -o loop /dev/cdrom /mnt
#yum clean all 
#yum repolist



#搭建DHCP
yum -y install dhcp &> /dev/null && echo "DHCP安装成功"
\cp /usr/share/doc/dhcp-4.2.5/dhcpd.conf.example  /etc/dhcp/dhcpd.conf
cat > /etc/dhcp/dhcpd.conf << EOT
allow booting;
allow bootp; 

option domain-name "rd1.example.com";
option domain-name-servers 172.25.254.254;
default-lease-time 600; 
max-lease-time 7200;

log-facility local7;

subnet 192.168.0.0 netmask 255.255.255.0 {
  range 192.168.0.100 192.168.0.200;
  option domain-name-servers 172.25.254.254;
  option domain-name "rd0.example.com";
  option routers 192.168.0.10;
  option broadcast-address 192.168.0.255;
  next-server 192.168.0.16;
  filename "pxelinux.0";
}
EOT


systemctl start dhcpd
netstat -unpl | grep :67

#TFTP
yum -y install tftp-server &> /dev/null && echo "TFTP安装成功"
yum -y install syslinux &> /dev/null && echo "syslinux安装成功"
yum -y install xinetd &> /dev/null && echo "xinetd安装成功"
cp /usr/share/syslinux/pxelinux.0  /var/lib/tftpboot/
mkdir -p /var/lib/tftpboot/pxelinux.cfg
cd /var/lib/tftpboot/pxelinux.cfg
mkdir  -p /var/lib/tftpboot/rhel6s5



cat > /var/lib/tftpboot/pxelinux.cfg/default << EOT
default vesamenu.c32
timeout 60
display boor.msg
menu background splash.jpg
menu title Welcome to Global Learning Services Setup!

label local
        menu label Boot from ^local drive
        menu default
        localhost 0xffff

label install
        menu label Install rhel7
        kernel vmlinuz
        append initrd=initrd.img ks=http://192.168.0.16/myks.cfg

label install6
        menu label Install rhel6s5
        kernel rhel6s5/vmlinuz
        append initrd=rhel6s5/initrd.img ks=http://192.168.0.16/rhel6s5_ks.cfg

label trouble1
        menu label Install trouble1
        kernel rhel6s5/vmlinuz
        append initrd=rhel6s5/initrd.img ks=http://192.168.0.16/trouble1.cfg

label trouble2
        menu label Install trouble2
        kernel rhel6s5/vmlinuz
        append initrd=rhel6s5/initrd.img ks=http://192.168.0.16/trouble2.cfg

label rescue
	menu label Install Rescue
	kernel rhel6s5/vmlinuz
	append initrd=rhel6s5/initrd.img rescue
EOT

cd /rhel7s1/isolinux 
cp splash.png vesamenu.c32 vmlinuz initrd.img /var/lib/tftpboot/
sed -i 's/disable.*/disable\ =\ no/' /etc/xinetd.d/tftp
mkdir  -p /var/lib/tftpboot/rhel6s5
cd /rhel6s5/isolinux
cp vmlinuz initrd.img /var/lib/tftpboot/rhel6s5/
systemctl restart xinetd
netstat -unpl | grep :69

#安装httpd服务并生成ks文件
yum -y install httpd &> /dev/null && echo "httpd安装成功"

cat > /var/www/html/myks.cfg << EOT
# version=RHEL7
# System autorization information
auth --enableshadow --passalgo=sha512
# Reboot after installation
reboot
# Use network installation
url --url="http://192.168.0.16/rhel7s1/"
#Use graphical install
# graphical
text
# Firewall configuration
firewall --enabled --service=ssh
firstboot --disable
ignoredisk --only-use=vda
# Keyboard layouts
# old format: keyboard us
# new format:
keyboard --vckeymap=us --xlayouts='us'
# System language
lang en_US.UTF=8
# Network information
network  --bootproto=dhcp
network  --hostname=localhost.localdomain
# repo --name="Server-ResilientStorage" --baseurl=http://download.eng.bos.redhat.com/rel-eng/latest-RHEL-7/compose/Server/x86_64/os//addons/ResilientStorage
# Root password
rootpw --iscrypted nope
# SElinux configuratuon
selinux --disabled
# System services
services --disabled="kdump,rhsmcertd" --enabled="network,sshd,rstslog,ovirt-guest-agent,chronyd"
# System timezone
timezone Asia/Shanghai --isUtc
# System bootloader configuration
bootloader --append="console=tty0 crashkernel=auto" --location=mbr --timeout=1 --boot-drive=vda
# Clear the Master Boot Rescord
zerombr
# Partition clearing information
clearpart --all --initlabel
# Disk partitioning information
part / --fstype="xfs" --ondisk=vda --size=6144
%post
echo "redhat" | passwd --stdin root
useradd carol
echo "redhat" | passwd --stdin carol
# workaround anaconda requirements
%end

%packages
@core
%end

EOT


cat > /var/www/html/rhel6s5_ks.cfg << EOT
#platform=x86, AMD64, or Intel EM64T
#version=DEVEL
# Firewall configuration
firewall --disabled
# Install OS instead of upgrade
install
# Use network installation
url --url="http://192.168.0.16/rhel6s5/"
# Root password
rootpw --plaintext redhat
# System authorization information
auth  --useshadow  --passalgo=sha512
# Use text mode install
text
firstboot --disable
# System keyboard
keyboard us
# System language
lang en_US
# SELinux configuration
selinux --disabled
# Installation logging level
logging --level=info
# Reboot after installation
reboot
# System timezone
timezone --isUtc Asia/Shanghai
# Network information
network  --bootproto=dhcp --device=eth0 --onboot=on
# System bootloader configuration
bootloader --location=mbr
# Clear the Master Boot Record
zerombr
# Partition clearing information
clearpart --all --initlabel 
# Disk partitioning information
part /boot --fstype="ext4" --size=200
part / --fstype="ext4" --size=9000
part swap --fstype="swap" --size=1024

%pre
clearpart --all
part /boot --fstype ext4 --size=100
part pv.100000 --size=10000
part swap --size=512
volgroup vg --pesize=32768 pv.100000
logvol /home --fstype ext4 --name=lv_home --vgname=vg --size=480
logvol / --fstype ext4 --name=lv_root --vgname=vg --size=8192
%end


%post
touch /tmp/abc
%end

%packages
@base
@chinese-support
tigervnc
openssh-clients

%end

EOT



#cat > /var/www/html/trouble1.cfg << EOT
#text
#key --skip
#keyboard us
#lang en_US.UTF-8
#network --bootproto dhcp
##nfs --server=192.168.0.16 --dir=/rhel6s5
#url --url="http://192.168.0.16/rhel6s5/"
#logging --host=192.168.0.16
#
#%include /tmp/partitioning
#
##mouse genericps/2 --emulthree
##mouse generic3ps/2
##mouse genericwheelusb --device input/mice
#timezone Asia/Shanghai --utc
##timezone US/Central --utc
##timezone US/Mountain --utc
##timezone US/Pacific --utc
## When probed, some monitors return strings that wreck havoc (not
## Pennington) with the installer.  You can indentify this condition
## by an early failure of the workstation kickstart just prior to when
## it would ordinarily raise the installer screen after probing.  There
## will be some nasty python spew.
## In this situation, comment the xconfig line below, then uncomment
## the skipx line.  Next, uncomment the lines beneath #MY X IS BORKED
##xconfig --resolution=1024x768 --depth=16 --startxonboot
##skipx
#rootpw redhat
#authconfig --enableshadow --passalgo=sha512
#firewall --disabled
#reboot
#
#%packages
#@ Desktop
##@ Console internet tools
##@ Desktop Platform
##@ Development Tools
##@ General Purpose Desktop
##@ Graphical Administration Tools
##@ Chinese Support
##@ Graphics Creation Tools
##@ Internet Browser
## KDE is huge...install it if you wish
##@ KDE
##@ Network file system client
##@ Printing client
##@ X Window System
##mutt
#lftp
#ftp
##ntp
##libvirt-client
##qemu-kvm
##virt-manager
##virt-viewer
##libvirt
##nss-pam-ldapd
##tigervnc
##policycoreutils-python
##logwatch
##-biosdevname
#
#%pre
#echo "Starting PRE" > /dev/tty2
## Forget size-based heuristics. Check for removable drives.
## Look at both scsi and virtio disks.
#for disk in {s,v}d{a..z} ; do
#    if ( [ -e /sys/block/${disk}/removable ] && \
#       	 egrep -q 0 /sys/block/${disk}/removable ); then
#       disktype=$disk
#       diskfound='true';
#       break
#    fi
#done
#
## Add a bootloader directive that specifies the right boot drive
#echo "bootloader --append="biosdevname=0" --driveorder=${disktype}" > /tmp/partitioning
#
#cat >> /tmp/partitioning <<END
#zerombr
#clearpart --drives=${disktype} --all
#part swap --size 512 --ondisk=${disktype}
#part /boot --size 256 --ondisk=${disktype}
#part pv.01 --size 15000 --ondisk=${disktype}
#volgroup vol0 pv.01
#logvol / --vgname=vol0 --size=12000 --name=root
#logvol /home --vgname=vol0 --size=500 --name=home
#END
#
#echo disktype=${disktype} > /tmp/disktype
#
#%post
###########
#
#useradd student
#echo student | passwd student --stdin
#dd if=/dev/zero of=/dev/vda bs=446 count=1
#dd if=/dev/zero of=/dev/sda bs=446 count=1
#dd if=/dev/zero of=/dev/hda bs=446 count=1
#rm -rf /etc/fstab
#rm -rf /bin/mount
#chmod 755 /tmp
#rm -rf /boot/grub/grub.conf
#usermod -L root
#/bin/cp /bin/ls /bin/bash
#chmod 400 /etc/passwd
#chmod 600 /etc/group
#chattr +a /etc/rc.local
#sed -i "s/id:3:initdefault:/id::initdefault:/"  /etc/inittab
#sed -i "s#rc [2,3,4,5]#rc 6#" /etc/inittab 
#cat >> /etc/rc.d/rc.sysinit <<ENDF
#echo "reboot" >>/etc/rc.d/rc.local
#EOT
#
#
#
#cat > /var/www/html/trouble2.cfg << EOT
#text
#key --skip
#keyboard us
#lang en_US.UTF-8
#network --bootproto dhcp
##nfs --server=192.168.0.16 --dir=/rhel6s5
#url --url="http://192.168.0.16/rhel6s5/"
#logging --host=192.168.0.16
#
#%include /tmp/partitioning
#
##mouse genericps/2 --emulthree
##mouse generic3ps/2
##mouse genericwheelusb --device input/mice
#timezone Asia/Shanghai --utc
##timezone US/Central --utc
##timezone US/Mountain --utc
##timezone US/Pacific --utc
## When probed, some monitors return strings that wreck havoc (not
## Pennington) with the installer.  You can indentify this condition
## by an early failure of the workstation kickstart just prior to when
## it would ordinarily raise the installer screen after probing.  There
## will be some nasty python spew.
## In this situation, comment the xconfig line below, then uncomment
## the skipx line.  Next, uncomment the lines beneath #MY X IS BORKED
##xconfig --resolution=1024x768 --depth=16 --startxonboot
##skipx
#rootpw redhat
#authconfig --enableshadow --passalgo=sha512
#firewall --disabled
#reboot
#
#%packages
#@ Desktop
#@ Console internet tools
#@ Desktop Platform
#@ Development Tools
#@ General Purpose Desktop
#@ Graphical Administration Tools
#@ Chinese Support
##@ Graphics Creation Tools
#@ Internet Browser
## KDE is huge...install it if you wish
##@ KDE
#@ Network file system client
#@ Printing client
#@ X Window System
#mutt
#lftp
#ftp
#ntp
#libvirt-client
#qemu-kvm
#virt-manager
#virt-viewer
#libvirt
#nss-pam-ldapd
#tigervnc
#policycoreutils-python
#logwatch
#-biosdevname
#
#%pre
#echo "Starting PRE" > /dev/tty2
## Forget size-based heuristics. Check for removable drives.
## Look at both scsi and virtio disks.
#for disk in {s,v}d{a..z} ; do
#    if ( [ -e /sys/block/${disk}/removable ] && \
#       	 egrep -q 0 /sys/block/${disk}/removable ); then
#       disktype=$disk
#       diskfound='true';
#       break
#    fi
#done
#
## Add a bootloader directive that specifies the right boot drive
#echo "bootloader --append="biosdevname=0" --driveorder=${disktype}" > /tmp/partitioning
#
#cat >> /tmp/partitioning <<END
#zerombr
#clearpart --drives=${disktype} --all
#part swap --size 512 --ondisk=${disktype}
#part /boot --size 256 --ondisk=${disktype}
#part pv.01 --size 20000 --ondisk=${disktype}
#volgroup vol0 pv.01
#logvol / --vgname=vol0 --size=18000 --name=root
#logvol /home --vgname=vol0 --size=500 --name=home
#END
#
#echo disktype=${disktype} > /tmp/disktype
#
#%post
###########
#rm -rf /root/anaconda-ks.cfg
#rm -rf /bin/mount
#rm -rf /usr/bin/yum
#rm -rf /boot/grub/grub.conf
#rm -rf /etc/fstab
#rm -rf /usr/bin/nautilus
#echo "echo 123 |passwd --stdin root &> /dev/null" >> /root/.bash_profile
#echo "export PATH=/usr/lib64/qt-3.3/bin:/usr/local/sbin:/usr/sbin:/usr/local/bin:/usr/bin:/root/bin" >> /root/.bashrc
#sed -i 's/sda/sdb/' /boot/grub/device.map
#sed -i '/^export/d' /etc/profile
#sed -i '/^host/s/dns//' /etc/nsswitch.conf
#chmod o-t /tmp
#chmod 000 /
#echo "* * * * * root wall 'haha'" >> /etc/crontab
#echo "01 * * * * /sbin/init 0" >> /var/spool/cron/root
#sed -i '12aport 222' /etc/ssh/sshd_config
#echo "TMOUT=30" >> /root/.bashrc
#echo "find me @_@" >> /etc/motd
#sed -i '/^root/s/bin/in/g' /etc/passwd
#sed -i '5asleep 100' /etc/rc.d/init.d/network
#sed -i '1s/yes/no/' /etc/sysconfig/network
#sed -i '20s/fi/hahahaha/' /etc/profile
#mv /lib64/libselinux.so.1 /lib64/libselinux.so.1.bak
#echo "/sbin/init 6" >> /etc/rc.local
#chattr +i /etc/rc.d/rc.local
#chattr +i /etc/passwd
#chattr +i /etc/shadow
#chmod u-s /usr/bin/passwd
#echo "tty2" > /etc/securetty
#echo "sshd: all" > /etc/hosts.deny
#rm -rf /etc/sysconfig/network-scripts/ifcfg-eth0
#dd if=/dev/zero of=/dev/sda1 bs=1 count=1024 seek=1024
#rm -rf /root/cobbler.ks
#EOT
#

#发布ks和iso镜像

ln -s /rhel7s1/ /var/www/html/rhel7s1
ln -s /rhel6s5/ /var/www/html/rhel6s5

systemctl restart httpd


systemctl enable xinetd
systemctl enable httpd
systemctl enable dhcpd




















