#!/bin/bash
iptables -F
setenforce 0
#关闭防火墙和selinux
systemctl stop firewalld && systemctl disable firewalld &> /dev/null

#配置文件永久selinux
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config


