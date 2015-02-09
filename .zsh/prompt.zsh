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

    # Remove trailing . that vcs_info adds when in the root of a repository.
    newPath="${newPath/%\/\.//}"

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
                segments[$i]="$dot$compressible[0,$charsToKeep]$pr[elideSymbol]$escapes"
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
            integer firstElipsis=${newPath[(i)$pr[elideSymbol]]}
            if (( $firstElipsis <= ${#newPath} )); then
                newPath[1,$firstElipsis]="$pr[elideSymbol]"
            else
                newPath[1]="$pr[elideSymbol]"
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

function +vi-git-misc()
{
    # Clear %m before sticking my own stuff in there.
    hook_com[misc]=''


    # Add rebase progress to %a when rebasing.
    if [[ -n "$hook_com[action]" ]]; then
        local gitRebaseDir="$(git rev-parse --git-dir)/rebase-merge"
        local numFile="$gitRebaseDir/msgnum"
        local endFile="$gitRebaseDir/end"
        if [[ -f "$endFile" && -f "$numFile" ]]; then
            hook_com[action]+="%b$pr[cyan] $(cat $numFile)/$(cat $endFile)"
        fi
    fi

    # Add conflicted file count.
    local conflictCount=$(git ls-files --unmerged 2>/dev/null | cut -f2 | uniq | wc -l)
    if (( $conflictCount > 0 )); then
        hook_com[misc]+="$pr[lineColor]│$pr[red]%B$conflictCount$pr[conflictSymbol]%b"
    fi

    # Add upstream ahead and behind counts.
    hook_com[misc]+=$(git-ahead-behind "@{upstream}")

    # Add the stash count.
    local stashCount=$(git stash list 2>/dev/null | wc -l)
    if (( $stashCount > 0 )); then
        if (( $stashCount == 1 )); then
            stashCount=''
        fi
        hook_com[misc]+="$pr[lineColor]│$pr[magenta]$stashCount$pr[stashSymbol]"
    fi
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
            echo -n "$pr[lineColor]│$pr[yellow]$ahead$pr[aheadSymbol]"
        fi

        if (( $behind > 0 )); then
            echo -n "$pr[lineColor]│$pr[yellow]$behind$pr[behindSymbol]"
        fi
    fi
}


function TRAPWINCH()
{
    # Regenerating the prompt in TRAPWINCH causes lines of history to be
    # eaten. I still haven't figured out a workaround.

#     precmd
#     zle && zle reset-prompt
}


function TRAPUSR1()
{
    pr[infoLine]="$(< $pr[tempFile])"
    pr[asyncPid]=0
    zle && zle reset-prompt
    rm "$pr[tempFile]"
}


function precmd()
{
    function asyncPromptInfo()
    {
        # Update VSC data
        vcs_info

        integer maxPathLength
        (( maxPathLength = $COLUMNS - $(expandStripLength "╭──┤├─$vcs_info_msg_0_──╮_") ))
        pr[pwd]=$(compressPath "${vcs_info_msg_1_}" $maxPathLength)

        integer fillerLength
        (( fillerLength = $maxPathLength - $(expandStripLength "$pr[pwd]") ))
        pr[fillBar]="${(e):-${(l.$fillerLength..─.)}}"

        echo "$pr[lineColor]$pr[leftCorner]──┤$pr[white]%B$pr[pwd]%b$pr[lineColor]├─$pr[fillBar]$vcs_info_msg_0_──$pr[rightCorner]" >! "$pr[tempFile]"

        # Signal parent
        kill -s USR1 $$
    }

    # Kill previous subshell if it's still running
    if [[ "$pr[asyncPid]" != 0 ]]; then
        kill -s HUP $pr[asyncPid] >/dev/null 2>&1 || :
    fi

    # Launch subshell asynchronously and capture PID
    asyncPromptInfo &!
    pr[asyncPid]=$!

    pr[infoLine]="$pr[lineColor]$(expandStrip "$pr[infoLine]")"

    integer cmdSeconds
    (( cmdSeconds = $SECONDS - ${pr[lastCmdStart]:=$SECONDS} ))
    pr[lastCmdStart]=""
    pr[cmdRunTime]=""
    if (( $cmdSeconds > 7 && $TTYIDLE > 7 )); then
        pr[cmdRunTime]="$pr[timeSymbol] $(elapsedTimeFormat $cmdSeconds)
"
    fi

    if [[ "${(%):-%n@%m}" != "$pr[defaultUser]" ]] || [[ -n "$SSH_TTY" ]]; then
        pr[userOrTime]="$pr[green]%n$pr[cyan]@%m"
    else
        pr[userOrTime]="$pr[green]%D{%H:%M}"
    fi
}


function toggleUnicode()
{
    if [[ $pr[unicode] -ne 0 ]]; then
        pr[unicode]=0

        pr[leftCorner]='┌'
        pr[rightCorner]='┐'
        pr[promptSymbol]='>'
        pr[modifiedSymbol]='±'
        pr[stagedSymbol]='±'
        pr[timeSymbol]='Runtime:'
        pr[returnSymbol]='Returned:'
        pr[aheadSymbol]='^'
        pr[behindSymbol]='v'
        pr[stashSymbol]='@'
        pr[conflictSymbol]='!'
        pr[elideSymbol]='_'
    else
        pr[unicode]=1

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
        pr[elideSymbol]='…'
    fi

    precmd
}

zle -N toggleUnicode
bindkey '^u' toggleUnicode


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

    # The temporary file where the first line of the prompt will be stored
    pr[tempFile]="$ZSH/prompt-info.tmp"

    autoload -Uz vcs_info
    local vcsBranchFormat="%u%c$pr[green]%b%m"
    local vcsPathFormat="%R$pr[yellow]/%S"

    zstyle ':vcs_info:*' enable git svn
    zstyle ':vcs_info:*' check-for-changes true
    zstyle ':vcs_info:git+set-message:*' hooks git-misc
    zstyle ':vcs_info:git-svn+set-message:*' hooks git-svn-ahead-behind git-stash
    zstyle ':vcs_info:*' unstagedstr   "$pr[red]%B$pr[modifiedSymbol]%b"
    zstyle ':vcs_info:*' stagedstr     "$pr[yellow]%B$pr[stagedSymbol]%b"
    zstyle ':vcs_info:svn*' branchformat  "%b$pr[yellow]@%r"
    zstyle ':vcs_info:*' actionformats "┤$pr[cyan]%B%a%%b$pr[lineColor]│$vcsBranchFormat$pr[lineColor]├" "$vcsPathFormat"
    zstyle ':vcs_info:*' formats       "┤$vcsBranchFormat$pr[lineColor]├" "$vcsPathFormat"
    zstyle ':vcs_info:*' nvcsformats   "" "%d"

    # Assume that xterms and 256 color terminals support Unicode.
    # Not realistic, but good enough for the machines I use.
    if [[ "$TERM" == xterm* || "$TERM" == *256* ]]; then
        pr[unicode]=0
    fi
    toggleUnicode

    PROMPT="       %(?..$pr[red]%B\$pr[returnSymbol] \$? %b)$pr[yellow]\${pr[cmdRunTime]:-%(?..
)}
\$pr[infoLine]
│\$pr[userOrTime] $pr[yellow]%B\$pr[promptSymbol]%b$pr[reset] "

    RPROMPT="$pr[lineColor]│$pr[reset]"

    PROMPT2="$pr[lineColor]│$pr[green]%_ $pr[yellow]%B\$pr[promptSymbol]%b$pr[reset] "

    RPROMPT2=$RPROMPT

    # Set a placeholder info line until the first async subshell completes
    integer fillerLength
    (( fillerLength = $COLUMNS - 8 ))
    pr[infoLine]="$pr[lineColor]$pr[leftCorner]──┤$pr[white]%B$pr[elideSymbol]%b$pr[lineColor]├${(e):-${(l.$fillerLength..─.)}}$pr[rightCorner]"
}

setprompt
unfunction setprompt
