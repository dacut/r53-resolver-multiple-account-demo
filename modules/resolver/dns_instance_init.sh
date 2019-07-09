#!/bin/bash
yum update -y
yum install -y bind util-linux-user zsh
chsh -s /bin/zsh ec2-user
chsh -s /bin/zsh root

cat > /root/.zshrc <<.EOF
autoload -Uz compinit
compinit
alias h='history'
export PROMPT="%B%! %n@%m %3/%#%b ";
export LESS="-XR"
if [[ -x /usr/bin/nano ]]; then
    export VISUAL=/usr/bin/nano
    export EDITOR=/usr/bin/nano
elif [[ -x /bin/nano ]]; then
    export VISUAL=/bin/nano
    export EDITOR=/bin/nano
fi
.EOF

cp /root/.zshrc /home/ec2-user/.zshrc
chown ec2-user:ec2-user /home/ec2-user/.zshrc

# Back up the original /etc/named.conf file
cp /etc/named.conf /etc/named.conf.orig

# Disable recursion, listen on eth0, and enable our custom zone.
cat /etc/named.conf.orig | \
  sed -E -e 's/^(\s*)recursion [a-z]*;$/\1recursion no;/' \
         -e 's/listen-on port 53 .*;/listen-on port 53 { any; };/' \
         -e 's/listen-on-v6 port 53 .*;/listen-on-v6 port 53 { any; };/' | \
  awk '{print $0} END {print "include \"/etc/named/onprem.example.com.zone\";"}' \
  > /etc/named.conf

# onprem.example.com zone configuration file
cat > /etc/named/onprem.example.com.zone <<.EOF
zone "onprem.example.com" IN {
    type master;
    file "named.onprem.example.com";
    allow-query { any; };
    allow-update { none; };
};
.EOF

local_ip=$(curl -s http://169.254.169.254/2018-09-24/meta-data/local-ipv4)

# onprem.example.com zone file
cat > /var/named/named.onprem.example.com <<.EOF
\$ORIGIN onprem.example.com.
\$TTL 60
@ IN SOA onprem.example.com. hostmaster.onprem.example.com. (
        1               ; Serial number
        86400           ; Refresh time -- how often slaves refresh
        180             ; Retry time -- if slave fails, when to retry
        2419200         ; Expiry -- when the slave is no longer authoritative
        60 )            ; NXDOMAIN TTL -- how long to cache NXDOMAIN responses
@ IN NS @
@ IN A $local_ip
@ IN TXT "${tag_prefix}On-premises zone${tag_suffix}"
test IN TXT "${tag_prefix}On-premises zone${tag_suffix}"
.EOF

systemctl enable named
systemctl start named
