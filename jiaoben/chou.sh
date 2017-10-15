#!/bin/bash
file=/root/phone.txt
i=1
while true
do
	line=`cat phone.txt | wc -l`
	luckline=`echo $[$RANDOM%$line+1]`
	luckphone=`head -$luckline  $file|tail -l`
	echo "幸运观众是：139****${luckphone:7:4}"
	sed -i "/$luckphone/d" $file
	let i++
	[ $i -gt 5 ] && break	
done
