passwd=uplooking
keydir=$HOME/.ssh
###放钥匙的目录
skey=$keydir/id_rsa
##公钥
pkey=$keydir/id_rsa.pub
##私钥
##server_ip=/shells/serverip.txt
        [ -f $skey -a -f $pkey ] || $(ssh-keygen -q -f $skey -N "")
#while read serverip
#        do
#        for i in $serverip
#                do
#                   expect <<EOF
#                        spawn ssh-copy-id root@$i
#                                expect {
#                                        "*(yes/no)*" { send  "yes\r";exp_continue}
#                                        "*password:" { send "$passwd\r";exp_continue}
#                                eof{exit}
#                                        }
#
#EOF
#        done
#done<$server_ip                                    
        for i in {10..13}
                do
                   expect <<EOF
                        spawn ssh-copy-id root@172.25.7.$i
                                expect {
                                        "*(yes/no)*" { send  "yes\r";exp_continue}
                                        "*password:" { send "$passwd\r";exp_continue}
                                eof{exit}
                                        }

EOF
        done
ssh-add
