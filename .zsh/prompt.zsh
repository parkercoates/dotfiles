function preexec()
{
    pr[lastCmdStart]=$SECONDS
}

function expandStrip()
{
    local expanded="${(%):-$1}"
    echo $expanded | perl -pe 's/\e\[?.*?[\@-~]//g'
}

function expandStripLength()
{
    local stripped="$(expandStrip $1)"
    echo ${#stripped}
}

function compressPath()
{
    integer newLength;
    newLength=$2
    if (( $newLength <= 0 )); then
        echo ""
        return
    fi

    # Replace $HOME by ~.
    local newPath="${1/$HOME/~}"

    integer charsToRemove=0
    (( charsToRemove = $(expandStripLength $newPath) - $newLength ))

    if (( $charsToRemove > 0 )); then

        # Split the path into an array.
        local -a segments
        segments=(${(s:/:)newPath})

        for (( i = 1; i < ${#segments}; i++ )); do
            if (( $charsToRemove <= 0 )); then
                break
            fi

            # If there are escape codes at the end of the segment, strip them off
            # and hold on to them so we can stick them back on later.
            local stripped=$(expandStrip "$segments[$i]")
            local escapes=${segments[$i]##$stripped}

            # If the segment starts with a dot, strip it off and hold on to it,
            # so we can stick it back on later.
            local compressible=${stripped##.}
            local dot=${stripped%%$compressible}

            if (( ${#compressible} > 1 )); then
                integer charsToKeep
                (( charsToKeep = ${#compressible} - $charsToRemove - 1 ))
                if (( $charsToKeep < 1 )); then
                    charsToKeep=1
                fi
                (( charsToRemove = $charsToRemove - ( ${#compressible} - ($charsToKeep + 1) ) ))
                segments[$i]="$dot$compressible[0,$charsToKeep]…$escapes"
            fi
        done

        # Rejoin the segments and stick the root slash back on if necessary.
        newPath=${(j:/:)segments}
        if [[ ! $newPath =~ "^~" ]]; then
            newPath=/$newPath
        fi

        # If we're still not short enough...
        if (( $charsToRemove >  0 )); then
            # Chop of the start
            newPath="${newPath[-$newLength,-1]}"

            # If the resulting path contains an elipsis, drop everything before
            # it, otherwise replace the first character with an elipsis.
            integer firstElipsis=${newPath[(i)…]}
            if (( $firstElipsis <= ${#newPath} )); then
                newPath[1,$firstElipsis]="…"
            else
                newPath[1]="…"
            fi
        fi
    fi

    echo "$newPath"
}

function elapsedTimeFormat()
{
    integer seconds=$1
    if (( $seconds >= 60 )); then
        local minutes
        (( minutes = $seconds / 60 ))
        (( seconds = $seconds % 60 ))
        minutes="${minutes}m"
        if (( $seconds < 10 )); then
            minutes="${minutes}0"
        fi
    fi
    echo "$minutes${seconds}s"
}

function +vi-git-clear-misc()
{
    hook_com[misc]=''
}

function +vi-git-stash()
{
    local stashCount=$(git stash list 2>/dev/null | wc -l)
    if (( $stashCount > 0 )); then
        if (( $stashCount == 1 )); then
            stashCount=''
        fi
        hook_com[misc]+="$pr[lineColor]│$pr[magenta]$stashCount$pr[stashSymbol]"
    fi
}

function +vi-git-conflicts()
{
    local conflictCount=$(git ls-files --unmerged 2>/dev/null | cut -f2 | uniq | wc -l)
    if (( $conflictCount > 0 )); then
        hook_com[misc]+="$pr[lineColor]│$pr[red]%B$conflictCount$pr[conflictSymbol]%b"
    fi
}

function +vi-git-ahead-behind()
{
    hook_com[misc]+=$(git-ahead-behind "@{upstream}")
}

function +vi-git-svn-ahead-behind()
{
    local svnBranch=$(git log -1 --first-parent --grep="^git-svn-id: "\
                      | perl -ne 'm/git-svn-id:.*\/(\w+)@\d+/; print $1')
    hook_com[misc]+=$(git-ahead-behind "remotes/$svnBranch")
}

function git-ahead-behind()
{
    local remote=$1

    if git rev-parse $remote &>/dev/null; then
        integer ahead=$(git rev-list $remote..HEAD 2>/dev/null | wc -l)
        integer behind=$(git rev-list HEAD..$remote 2>/dev/null | wc -l)

        if (( $ahead > 0 )); then
            echo -n "$pr[lineColor]│$pr[yellow]$pr[aheadSymbol]$ahead"
        fi

        if (( $behind > 0 )); then
            echo -n "$pr[lineColor]│$pr[yellow]$pr[behindSymbol]$behind"
        fi
    fi
}

function precmd()
{
    integer cmdSeconds
    (( cmdSeconds = $SECONDS - ${pr[lastCmdStart]:=$SECONDS} ))
    pr[lastCmdStart]=""
    pr[cmdRunTime]=""
    if (( $cmdSeconds > 7 && $TTYIDLE > 7 )); then
        pr[cmdRunTime]="$pr[timeSymbol] $(elapsedTimeFormat $cmdSeconds)
"
    fi

    vcs_info

    integer maxPathLength
    (( maxPathLength = $COLUMNS - $(expandStripLength "╭──┤├─$vcs_info_msg_0_──╮_") ))

    pr[pwd]="${(%):-${vcs_info_msg_1_%%.}}"
    pr[pwd]=$(compressPath "$pr[pwd]" $maxPathLength)

    integer fillerLength
    (( fillerLength = $maxPathLength - $(expandStripLength "$pr[pwd]") ))
    pr[fillBar]="${(e):-${(l.$fillerLength..─.)}}"

    if [[ "${(%):-%n@%m}" != "$pr[defaultUser]" ]] || [[ -n "$SSH_TTY" ]]; then
        pr[userOrTime]="$pr[green]%n$pr[cyan]@%m"
    else
        pr[userOrTime]="$pr[green]%D{%H:%M}"
    fi
}

function setprompt()
{
    setopt PROMPT_SUBST
    autoload -U colors && colors

    # Store all prompt components in an associative array.
    typeset -Ag pr

    pr[reset]="%{$reset_color%}"
    for color in red green yellow blue magenta cyan white; do
        pr[$color]="%{$fg[$color]%}"
    done
    pr[lineColor]=$pr[blue]

    # Assume that xterms and 256 color terminals support Unicode.
    # Not realistic, but good enough for the machines I use.
    if [[ "$TERM" == xterm* || "$TERM" == *256* ]]; then
        pr[leftCorner]='╭'
        pr[rightCorner]='╮'
        pr[promptSymbol]='❱'
        pr[modifiedSymbol]='±'
        pr[stagedSymbol]='∓'
        pr[timeSymbol]='⌛'
        pr[returnSymbol]='↳'
        pr[aheadSymbol]='↥'
        pr[behindSymbol]='↧'
        pr[stashSymbol]='↶'
        pr[conflictSymbol]='✖'
    else
        pr[leftCorner]='┌'
        pr[rightCorner]='┐'
        pr[promptSymbol]='>'
        pr[modifiedSymbol]='±'
        pr[stagedSymbol]='±'
        pr[timeSymbol]='Runtime:'
        pr[returnSymbol]='Returned:'
        pr[aheadSymbol]='>'
        pr[behindSymbol]='<'
        pr[stashSymbol]='$'
        pr[conflictSymbol]='!'
    fi

    autoload -Uz vcs_info
    local vcsBranchFormat="%u%c$pr[green]%b%m"
    local vcsPathFormat="%R$pr[yellow]/%S"

    zstyle ':vcs_info:*' enable git svn
    zstyle ':vcs_info:*' check-for-changes true
    zstyle ':vcs_info:git+set-message:*' hooks git-clear-misc git-conflicts git-ahead-behind git-stash
    zstyle ':vcs_info:git-svn+set-message:*' hooks git-svn-ahead-behind git-stash
    zstyle ':vcs_info:*' unstagedstr   "$pr[red]%B$pr[modifiedSymbol]%b"
    zstyle ':vcs_info:*' stagedstr     "$pr[yellow]%B$pr[stagedSymbol]%b"
    zstyle ':vcs_info:svn*' branchformat  "%b$pr[yellow]@%r"
    zstyle ':vcs_info:*' actionformats "┤$pr[cyan]%B%a%%b$pr[lineColor]│$vcsBranchFormat$pr[lineColor]├" "$vcsPathFormat"
    zstyle ':vcs_info:*' formats       "┤$vcsBranchFormat$pr[lineColor]├" "$vcsPathFormat"
    zstyle ':vcs_info:*' nvcsformats   "" "%d"

    PROMPT="       %(?..$pr[red]%B\$pr[returnSymbol] \$? %b)$pr[yellow]\${pr[cmdRunTime]:-%(?..
)}
$pr[lineColor]$pr[leftCorner]──┤$pr[white]%B\$pr[pwd]%b$pr[lineColor]├─\$pr[fillBar]\$vcs_info_msg_0_$pr[lineColor]──$pr[rightCorner]
│\$pr[userOrTime] $pr[yellow]%B$pr[promptSymbol]%b$pr[reset] "

    RPROMPT="$pr[lineColor]│$pr[reset]"

    PROMPT2="$pr[lineColor]│$pr[green]%_ $pr[yellow]%B$pr[promptSymbol]%b$pr[reset] "

    RPROMPT2=$RPROMPT
}

setprompt
unfunction setprompt
