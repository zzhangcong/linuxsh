#!/bin/bash
rm -rf /root/phone.txt
count=0
while true
do
	n1=`echo $[$RANDOM%10]`
	n2=`echo $[$RANDOM%10]`
	n3=`echo $[$RANDOM%10]`
	n4=`echo $[$RANDOM%10]`
	n5=`echo $[$RANDOM%10]`
	n6=`echo $[$RANDOM%10]`
	n7=`echo $[$RANDOM%10]`
	n8=`echo $[$RANDOM%10]`
	echo "139$n1$n2$n3$n4$n5n$n6$n7$n8" >> phone.txt && let count++
	[ $count -eq 1000 ] && break
done
