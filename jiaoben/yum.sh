#!/bin/bash
rm -rf /etc/yum.repos.d/*
cat > /etc/yum.repos.d/base.repo <<END
[base]
name=base yum
baseurl=file:///mnt
gpgcheck=0
enabled=1

END

yum clean all &> /dev/null
yum makecache &> /dev/null

[ $? -ne 0 ] && echo "yum源配置有问题，请检查配置文件..." && exit || echo "yum源配置完成"

mount -o loop /dev/cdrom /mnt
