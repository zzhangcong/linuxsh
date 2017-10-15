#!/bin/bash
#time1=$(($(date +%s -d '2017-10-01') - $(date +%s -d '2017-08-29 00:00:00')));
#echo $time1
goal=`date -d "2017-10-01" +%s`
while true
do 
	now=`date +%s`
      [ $[$goal-$now] -eq 0 ] && break
	day=$[$[$goal-$now]/86400]
	hour=$[$[$goal-$now]%86400/3600]
	min=$[$[$goal-$now]%3600/60]
	sec=$[$[$goal-$now]%60]	
	echo "距离2017年10月1日（国庆节）还有 $day 天，$hour 时，$min 分，$sec 秒。"
sleep 1
clear
done
echo "国庆节快乐!!!"
