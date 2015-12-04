# Based http://unix.stackexchange.com/a/32426/105025

function list-files()
{
    local oldBuffer="$BUFFER"
    local oldCursor="$CURSOR"
    if [[ -z "$LISTINGFILES" ]]; then
        BUFFER='ls '
        CURSOR=3
        LISTINGFILES=1
    else
        BUFFER='nonexistentcommand'
        CURSOR=1
        unset LISTINGFILES
    fi

    zle list-choices
    BUFFER="$oldBuffer"
    CURSOR="$oldCursor"
}
zle -N list-files
bindkey '^L' list-files

function expand-or-complete-or-list-files()
{
    if [[ -z $BUFFER ]]; then
        zle list-files
    else
        zle expand-or-complete
    fi
}
zle -N expand-or-complete-or-list-files
bindkey '^I' expand-or-complete-or-list-files
