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

export PATH=~/bin:$PATH

source $ZSH/development.sh

source $ZSH/aliases.zsh

source $ZSH/cdup.zsh

source $ZSH/completion.zsh

if type fasd >/dev/null 2>&1; then
    source $ZSH/fasd.zsh
fi

source $ZSH/history.zsh

source $ZSH/keys.zsh

source $ZSH/prompt.zsh
pr[defaultUser]=coates

source $ZSH/expand-multiple-dots.zsh

source $ZSH/tab-on-empty-line-shows-files.zsh

source $ZSH/tmux.zsh

source $ZSH/zsh-history-substring-search.zsh
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

if type fzf >/dev/null 2>&1; then
    source $ZSH/fzf.zsh
fi


# Sourcing this too early causes it to stop working. Not sure why.
source $ZSH/edit-command-line.zsh
