
# Run commands completely detached from current terminal by append '\&"
alias -g "\&"="&>/dev/null&|"

alias ls='ls --color=auto'
alias ll='ls -l'
alias la='ls -lA'

alias grep='grep --color=auto --perl-regexp'

# Development conveniences
alias sshudo='eval `ssh-agent`; ssh-add; '
alias gk='gitk --all &>/dev/null&|'
alias gc='git cola &>/dev/null&|'
alias kd='kdevelop &>/dev/null&|'
alias as='assistant &>/dev/null&|'
alias ds='designer &>/dev/null&|'

alias git-root='cd "$(git rev-parse --show-toplevel)"'

# Make and change directory
function mcd()
{
    mkdir -p $1 && cd $1
}
