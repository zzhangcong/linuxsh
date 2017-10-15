#/bin/bash

yum -y install bind &> /dev/null && echo "bind安装成功"

iptables -F
setenforce 0

cat > /etc/named.conf << EOT
include "/etc/dx.cfg";
include "/etc/wt.cfg";

options {
        listen-on port 53 { 127.0.0.1; any; };
        directory       "/var/named";
        dump-file       "/var/named/data/cache_dump.db";
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
                type slave;
                masters { 172.25.7.10; };
                file "slaves/linux.com.dx.zone";
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
                type slave;
                masters { 192.168.0.10; };
                file "slaves/linux.com.wt.zone";
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
                type slave;
                masters { 192.168.1.10; };
                file "slaves/linux.com.other.zone";
        };
        include "/etc/named.rfc1912.zones";
};

include "/etc/named.root.key";

EOT


systemctl restart named
systemctl enable named

netstat -unpl | grep named
