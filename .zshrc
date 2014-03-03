ZSH=~/.zsh

unsetopt CORRECT
unsetopt CORRECT_ALL

setopt MULTIOS
unsetopt CLOBBER
setopt INTERACTIVE_COMMENTS

# Directory navigation
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_MINUS
setopt PUSHD_SILENT


# Default editor
export EDITOR='vim'
export VISUAL='vim'

export LESS="-RIM"
eval `dircolors -b`

WORDCHARS='_-'

export PATH=/home/coates/bin:$PATH

if [[ -f /home/coates/qps-devel/qps-dev-env.sh ]]; then
    source /home/coates/qps-devel/qps-dev-env.sh
fi
#source ~/kde-devel/setup/kde-devel-env.sh



source $ZSH/aliases.zsh

source $ZSH/cdup.zsh

source $ZSH/completion.zsh

source $ZSH/edit-command-line.zsh

source $ZSH/fasd.zsh

source $ZSH/history.zsh

source $ZSH/keys.zsh

source $ZSH/prompt.zsh
pr[defaultUser]=coates@halfpounddonair

source $ZSH/tmux.zsh

source $ZSH/history-substring-search/zsh-history-substring-search.zsh
bindkey '^[[A' history-substring-search-up
bindkey '^h' history-substring-search-up
bindkey '^[[B' history-substring-search-down



