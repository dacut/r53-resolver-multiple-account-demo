#!/bin/bash
yum update -y
yum install -y util-linux-user zsh
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
