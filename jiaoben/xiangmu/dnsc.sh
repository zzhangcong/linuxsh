#!/bin/bash
setenforce 0
iptables -F


yum -y remove bind &> /dev/null
rm -rf /etc/named.conf.rpmsave
rm -rf dns_config.tar.gz 

yum -y install bind bind-chroot &> /dev/null && echo "bind安装成功"
yum -y install expect &> /dev/null

cat > /etc/named.conf << EOT
include "/etc/dx.cfg";
include "/etc/wt.cfg";

options {
	listen-on port 53 { 127.0.0.1; any; };
	directory 	"/var/named";
	dump-file 	"/var/named/data/cache_dump.db";
	statistics-file "/var/named/data/named_stats.txt";
	memstatistics-file "/var/named/data/named_mem_stats.txt";
	allow-query     { localhost; any; };
	recursion no;
	dnssec-enable no;
	dnssec-validation no;
	dnssec-lookaside auto;
	bindkeys-file "/etc/named.iscdlv.key";
	managed-keys-directory "/var/named/dynamic";
	pid-file "/run/named/named.pid";
	session-keyfile "/run/named/session.key";
};
logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

view  dx {
        match-clients { dx; 172.25.7.14; !192.168.0.14; 192.168.1.14; };
        zone "." IN {
                type hint;
                file "named.ca";
        };

        zone "linux.com" IN {
                type master;
                file "linux.com.dx.zone";
        };
        include "/etc/named.rfc1912.zones";
};

view  wt {
        match-clients { wt; !172.25.7.14; 192.168.0.14; !192.168.1.14; };
        zone "." IN {
                type hint;
                file "named.ca";
        };

        zone "linux.com" IN {
                type master;
                file "linux.com.wt.zone";
        };
        include "/etc/named.rfc1912.zones";
};


view  other {
        match-clients { any; !172.25.7.14; !192.168.0.14; 192.168.1.14; };
        zone "." IN {
                type hint;
                file "named.ca";
        };

        zone "linux.com" IN {
                type master;
                file "linux.com.other.zone";
        };
        include "/etc/named.rfc1912.zones";
};

include "/etc/named.root.key";

EOT

cd /var/named/
cp -a named.localhost  linux.com.dx.zone
cat > linux.com.dx.zone << EOT
\$TTL 1D
@	IN SOA	ns1.linux.com. rname.invalid. (
					10	; serial
					1D	; refresh
					1H	; retry
					1W	; expire
					3H )	; minimum
@	NS	ns1.linux.com.
ns1     A       172.25.7.10
www	A	192.168.11.1

EOT

cp -a linux.com.dx.zone linux.com.wt.zone
cat > linux.com.wt.zone << EOT
\$TTL 1D
@	IN SOA	ns1.linux.com. rname.invalid. (
					10	; serial
					1D	; refresh
					1H	; retry
					1W	; expire
					3H )	; minimum
@	NS	ns1.linux.com.
ns1     A       172.25.7.10
www	A	22.21.1.1

EOT

cp -a linux.com.wt.zone linux.com.other.zone
cat > linux.com.other.zone << EOT
\$TTL 1D
@       IN SOA  ns1.linux.com. rname.invalid. (
                                        10      ; serial
                                        1D      ; refresh
                                        1H      ; retry
                                        1W      ; expire
                                        3H )    ; minimum
@       NS      ns1.linux.com.
ns1     A       172.25.7.10
www     A       1.1.1.1
EOT

cat > /etc/dx.cfg << EOT
acl "dx" {
	172.25.7.11;
};
EOT

cat > /etc/wt.cfg << EOT
acl "wt" {
	172.25.7.12;
};
EOT


named-checkconf && echo "named语法正确"
named-checkzone  linux.com /var/named/linux.com.dx.zone
named-checkzone  linux.com /var/named/linux.com.wt.zone
named-checkzone  linux.com /var/named/linux.com.other.zone

systemctl restart named
systemctl enable named &> /dev/null


tar czvf /dns_config.tar.gz /etc/dx.cfg /etc/wt.cfg /dns2.sh

sed -i '/^'$1'/d' /root/.ssh/known_hosts
expect <<EOF
spawn ssh root@172.25.7.14
expect "no)?"
send "yes\r"
expect "password:"
send "uplooking\r"
expect "#"
send "rsync -av 172.25.7.10:/dns_config.tar.gz /\n"
expect "password:"
send "uplooking\r"
expect "#"
send "tar xf /dns_config.tar.gz -C /\n"
expect "#"
send "bash -x /dns2.sh\n"
expect "#"
send "exit"
expect eof
EOF




