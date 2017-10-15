#!/bin/bash

cat > /etc/yum.repos.d/base.repo << EOT
[base]
baseurl=http://172.25.254.254/content/rhel6.5/x86_64/dvd/
gpgcheck=0
EOT
yum clean all &> /dev/null
yum repolist &> /dev/null


umount /mnt/usb/ &> /dev/null
yum -y install expect &> /dev/null
read -p "输入你的磁盘设备名(例如/dev/sda):" cp
dd if=/dev/zero of=$cp bs=500 count=1

expect <<EOF &> /dev/null
spawn fdisk $cp
expect "help):"
send "n\n"
expect "(1-4)"
send "p\n"
expect "(1-4):"
send "1\n"
expect "default 1):"
send "1\n"
expect "):"
send "+4G\n"
expect "help):"
send "a\n"
expect "(1-4):"
send "1\n"
expect "help):"
send "w\n"
expect eof
EOF
partx -a $cp &> /dev/null
mkfs.ext4 ${cp}1 &> /dev/null


mkdir /mnt/usb
mount ${cp}1  /mnt/usb/

yum -y install filesystem --installroot=/mnt/usb/ &> /dev/null && echo "文件系统安装成功"
yum -y install bash coreutils findutils grep vim-enhanced rpm yum passwd net-tools util-linux lvm2 openssh-clients bind-utils --installroot=/mnt/usb/ &> /dev/null && echo "基本包安装成功"

cp -a /boot/vmlinuz-2.6.32-431.el6.x86_64 /mnt/usb/boot/
cp -a /boot/initramfs-2.6.32-431.el6.x86_64.img /mnt/usb/boot/
cp -arv /lib/modules/2.6.32-431.el6.x86_64/ /mnt/usb/lib/modules/

rpm -ivh http://172.25.254.254/content/rhel6.5/x86_64/dvd/Packages/grub-0.97-83.el6.x86_64.rpm --root=/mnt/usb/ --nodeps --force  &> /dev/null && echo "grub安装成功"

grub-install  --root-directory=/mnt/usb/ /dev/sda --recheck

cp /boot/grub/grub.conf  /mnt/usb/boot/grub/

sd=$(blkid ${cp}1 | awk -F\" '{print $2}')

cat > /mnt/usb/boot/grub/ << EOT
default=0
timeout=5
splashimage=/boot/grub/splash.xpm.gz
hiddenmenu
title My system from xxx
        root (hd0,0)
        kernel /boot/vmlinuz-2.6.32-431.el6.x86_64 ro root=UUID=$sd selinux=0 
        initrd /boot/initramfs-2.6.32-431.el6.x86_64.img
EOT



cp /boot/grub/splash.xpm.gz /mnt/usb/boot/grub/

cp /etc/skel/.bash* /mnt/usb/root/

cat > /mnt/usb/etc/sysconfig/network << EOT
NETWORKING=yes
HOSTNAME=my.system.org
EOT

cp /etc/sysconfig/network-scripts/ifcfg-eth0 /mnt/usb/etc/sysconfig/network-scripts/

cat > /mnt/usb/etc/sysconfig/network-scripts/ifcfg-eth0 << EOT
DEVICE="eth0"
BOOTPROTO="static"
ONBOOT="yes"
IPADDR=192.168.0.56
NETMASK=255.255.255.0
GATEWAY=192.168.0.254
DNS1=8.8.8.8
EOT

cat > /mnt/usb/etc/fstab <<EOT
UUID="$sd" /  ext4 defaults 0 0
proc                    /proc                   proc    defaults        0 0
sysfs                   /sys                    sysfs   defaults        0 0
tmpfs                   /dev/shm                tmpfs   defaults        0 0
devpts                  /dev/pts                devpts  gid=5,mode=620  0 0
EOT




#expect <<EOF &> /a.txt
#spawn grub-md5-crypt
#expect "word:"
#send "1\n"
#expect "word:"
#send "1\n"
#expect eof
#EOF

#jm=$(tail -1 a.txt)
#sed
#rm -rf /a.txt
#sed -i "s/^root.*/root:$1$nHDjV/$QhVSroG8VNTw8nQpzeB6z1:15937:0:99999:7:::/" /mnt/usb/etc/shadow
\cp -a /etc/shadow /mnt/usb/etc/shadow






