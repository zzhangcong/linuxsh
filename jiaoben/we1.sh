#!/bin/bash
#1.关闭防火墙和selinux
#2.配置yum源（本地|内网）
#3.软件三部曲（查看软件是否安装|安装（确定是否成功安装|查看软件列表））
#4.了解配置文件man 5 xxx.conf
#5.根据需求通过修改配置文件来完成服务的搭建
#6.启动服务|开机子启动
#7.测试验证
#-z为空，-n为非空

conf=/etc/httpd/conf/httpd.conf
fun_web(){
input=""
output=$1
while [ -z $input ]
   do
	read -p "$output" input
   done
echo $input

}

#获取用户所输入的ip，hostname，root_dir并赋值给变量
ip=$(fun_web "请输入你的IP地址(10.1.1.1):")
hostname=$(fun_web "请输入你的主机名(www.test.cc):") 
root_dir=$(fun_web "请输入你的数据根目录(/var/www/html):")


#修改hosts文件将域名和ip对应起来
cat >> /etc/hosts<<end
$ip $hostname
end

#判断数据根目录是否存在并创建首页文件及修改权限
[ ! -d $root_dir ] && mkdir -p $root_dir
echo "this is test page" >$root_dir/index.html

#根据需求修改配置文件
cat >> $conf<<END

















