
# Run commands completely detached from current terminal by append '\&"
alias -g "\&"="&>/dev/null&|"

if [[ "$(uname)" == "Darwin" ]]; then
    alias ls='ls --color=auto -D"%F %R"'
else
    alias ls='ls --color=auto --time-style="+%F %R"'
fi

alias ll='ls -lh'
alias la='ls -lhA'

alias grep='grep --color=auto'
alias prep='pcre2grep'

# Development conveniences
alias sshudo='eval `ssh-agent`; ssh-add; '
alias gk='gitk --all --date-order &>/dev/null&|'
alias gc='git cola &>/dev/null&|'
alias kd='kdevelop &>/dev/null&|'
alias as='assistant &>/dev/null&|'
alias ds='designer &>/dev/null&|'

function kt()
{
    kate $@ &>/dev/null&|
}

alias git-root='cd "$(git rev-parse --show-toplevel)"'

# Make and change directory
function mcd()
{
    mkdir -p $1 && cd $1
}
