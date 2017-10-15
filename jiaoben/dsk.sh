#!/bin/bash

cps=$(df -h |awk 'NR==2{print $5}' | sed  "s/.//3")
mails=root@localhost.com


for i in $cps
do
	if [ "$i" -ge 90 ]
	then
	echo "磁盘已超出90%" | mail $mails 
	else
	exit;
	fi
done
