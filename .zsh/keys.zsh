
# Use Emacs mode, not Vi.
bindkey -e

# Home, end, delete
bindkey "^[[H" beginning-of-line
bindkey "^[[F" end-of-line
bindkey "^[[3~" delete-char

# Control left and right
bindkey '^[[1;5D' emacs-backward-word
bindkey '^[[1;5C' emacs-forward-word

# Shift tab
bindkey '^[[Z' reverse-menu-complete

bindkey '^U' undo

bindkey '^P' push-line-or-edit

kill-line-right-then-left ()
{
    if [[ -n $RBUFFER ]]; then
        zle kill-line
    else
        zle kill-whole-line
    fi
}
zle -N kill-line-right-then-left
bindkey '^K' kill-line-right-then-left

foreground-last-background ()
{
    fg
}
zle -N foreground-last-background
bindkey '^Z' foreground-last-background

