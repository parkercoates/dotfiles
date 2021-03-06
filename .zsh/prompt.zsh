function preexec()
{
    pr[lastCmdStart]=$SECONDS
}

function escapeless()
{
    local zero='%([BSUbfksu]|([FB]|){*})'
    echo "${(S%%)1//$~zero/}"
}

function escapelessLength()
{
    echo "${#:-$(escapeless $1)}"
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

    integer charsToRemove=$(( $(escapelessLength $newPath) - $newLength ))

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
            local stripped=$(escapeless "$segments[$i]")
            local escapes=${segments[$i]##$stripped}

            # If the segment starts with a dot, strip it off and hold on to it,
            # so we can stick it back on later.
            local compressible=${stripped##.}
            local dot=${stripped%%$compressible}

            if (( ${#compressible} > 1 )); then
                integer charsToKeep=$(( ${#compressible} - $charsToRemove - 1 ))
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
        hook_com[misc]+="$pr[lineColor]$pr[vertLine]$pr[red]%B$conflictCount$pr[conflictSymbol]%b"
    fi

    # Add upstream ahead and behind counts.
    hook_com[misc]+=$(git-ahead-behind "@{upstream}")

    # Add the stash count.
    local stashCount=$(git stash list 2>/dev/null | wc -l)
    if (( $stashCount > 0 )); then
        if (( $stashCount == 1 )); then
            stashCount=''
        fi
        hook_com[misc]+="$pr[lineColor]$pr[vertLine]$pr[magenta]$stashCount$pr[stashSymbol]"
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
            echo -n "$pr[lineColor]$pr[vertLine]$pr[yellow]$ahead$pr[aheadSymbol]"
        fi

        if (( $behind > 0 )); then
            echo -n "$pr[lineColor]$pr[vertLine]$pr[yellow]$behind$pr[behindSymbol]"
        fi
    fi
}


function updatePromptInfo()
{
    function asyncPromptInfo()
    {
        # Update VSC data
        vcs_info

        local vcsStatus="${vcs_info_msg_0_/.../$pr[elideSymbol]}"
        local vcsSubdir="$vcs_info_msg_1_"

        local dir="$PWD"
        if [[ $dir == */$vcsSubdir ]]; then
            dir="${dir%%/$vcsSubdir}$pr[yellow]/$vcsSubdir"
        elif [[ -n "$vcsSubdir" ]]; then
            dir="$dir$pr[yellow]/"
        fi

        integer maxPathLength=$(( $COLUMNS - $(escapelessLength "╭──┤├─$vcsStatus──╮_") ))
        local compressedPath="$pr[white]%B$(compressPath "$dir" $maxPathLength)%b"

        integer fillerLength=$(( $maxPathLength - $(escapelessLength "$compressedPath") ))
        local fillBar="\${(l.$fillerLength..$pr[horzLine].)}"

        echo -e "$compressedPath\n$fillBar\n$vcsStatus" >! "$pr[tempFile]"

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
}

zle -N updatePromptInfo
bindkey '^G^G' updatePromptInfo

function TRAPUSR1()
{
    integer fd
    exec {fd}< "$pr[tempFile]"
    read <&$fd 'pr[pwd]'
    read <&$fd 'pr[fillBar]'
    read <&$fd 'pr[vcsInfo]'
    exec {fd}<& -

    pr[asyncPid]=0
    pr[waitIndicator]=''
    zle && zle reset-prompt
    rm "$pr[tempFile]"
}


function precmd()
{
    updatePromptInfo

    # Show an indicator while waiting for the prompt to update.
    pr[waitIndicator]="$pr[leftCap]$pr[yellow]$pr[waitSymbol]$pr[lineColor]$pr[rightCap]"

    # Show the current path without formatting while waiting.
    integer maxPathLength=$(( $COLUMNS - $(escapelessLength "╭──┤├─$pr[waitIndicator]$pr[vcsInfo]──╮_") ))
    pr[pwd]="$pr[reset]$(compressPath "$PWD" $maxPathLength)"

    integer fillerLength=$(( $maxPathLength - $(escapelessLength "$pr[pwd]") ))
    pr[fillBar]="\${(l.$fillerLength..$pr[horzLine].)}"

    integer cmdSeconds
    (( cmdSeconds = $SECONDS - ${pr[lastCmdStart]:=$SECONDS} ))
    pr[lastCmdStart]=""
    pr[cmdRunTime]=""
    if (( $cmdSeconds >= $pr[minRuntimeForDisplay] && $TTYIDLE >= $pr[minRuntimeForDisplay] )); then
        pr[cmdRunTime]="$pr[runtimeSymbol] $(elapsedTimeFormat $cmdSeconds)
"
    fi

    if [[ "$USER" != "$pr[defaultUser]" ]] || [[ -n "$SSH_TTY" ]]; then
        pr[userOrTime]="$pr[green]%n$pr[cyan]@%m"
    else
        pr[userOrTime]="$pr[green]%D{%H:%M}"
    fi
}


function switchCharSet()
{
    if [[ "$1" -eq 0 ]]; then
        # Full Unicode
        pr[promptSymbol]='❱'
        pr[modifiedSymbol]='±'
        pr[stagedSymbol]='∓'
        pr[runtimeSymbol]='⌛'
        pr[returnSymbol]='↳'
        pr[aheadSymbol]='↥'
        pr[behindSymbol]='↧'
        pr[stashSymbol]='↶'
        pr[conflictSymbol]='✖'
        pr[elideSymbol]='…'
        pr[waitSymbol]='⌛'
        pr[nestedSymbol]='◲×'

        pr[leftCorner]='╭'
        pr[rightCorner]='╮'
        pr[vertLine]='│'
        pr[horzLine]='─'
        pr[leftCap]='┤'
        pr[rightCap]='├'

    elif [[ "$1" -eq 1 ]]; then
        # Code Page 437 only
        pr[promptSymbol]='>'
        pr[modifiedSymbol]='±'
        pr[stagedSymbol]='±'
        pr[runtimeSymbol]=''
        pr[returnSymbol]='→'
        pr[aheadSymbol]='↑'
        pr[behindSymbol]='↓'
        pr[stashSymbol]='←'
        pr[conflictSymbol]='!'
        pr[elideSymbol]='»'
        pr[waitSymbol]='≈'
        pr[nestedSymbol]='≡'

        pr[leftCorner]='┌'
        pr[rightCorner]='┐'
        pr[vertLine]='│'
        pr[horzLine]='─'
        pr[leftCap]='┤'
        pr[rightCap]='├'
    else
        # ASCII only
        pr[promptSymbol]='>'
        pr[modifiedSymbol]='*'
        pr[stagedSymbol]='*'
        pr[runtimeSymbol]=''
        pr[returnSymbol]='\'
        pr[aheadSymbol]='A'
        pr[behindSymbol]='B'
        pr[stashSymbol]='#'
        pr[conflictSymbol]='!'
        pr[elideSymbol]='_'
        pr[waitSymbol]='%%'
        pr[nestedSymbol]=''

        pr[leftCorner]='|'
        pr[rightCorner]='|'
        pr[vertLine]='|'
        pr[horzLine]='='
        pr[leftCap]='['
        pr[rightCap]=']'
    fi
}

function cycleCharSetAndUpdate()
{
    if [[ $pr[charset] -eq 0 ]]; then
        pr[charset]=1
    elif [[ $pr[charset] -eq 1 ]]; then
        pr[charset]=2
    else
        pr[charset]=0
    fi

    switchCharSet $pr[charset]
    updatePromptInfo
}

zle -N cycleCharSetAndUpdate
bindkey '^u' cycleCharSetAndUpdate


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
    pr[tempFile]="/tmp/zsh-prompt-info.$$.tmp"

    # Assume that xterms and 256 color terminals support Unicode.
    # Not realistic, but good enough for the machines I use.
    if [[ "$TERM" == xterm* || "$TERM" == *256* ]]; then
        pr[charset]=0
    else
        pr[charset]=1
    fi
    switchCharSet $pr[charset]

    pr[minRuntimeForDisplay]=5

    export ZSH_DEPTH
    if [[ $ZSH_DEPTH -gt 0 ]]; then
        pr[depth]="$pr[yellow]\$pr[nestedSymbol]$ZSH_DEPTH$pr[reset]"
    fi
    ((ZSH_DEPTH+=1))

    autoload -Uz vcs_info
    local vcsBranchFormat="%u%c$pr[green]%b%m"
    local vcsPathFormat="%S"

    zstyle ':vcs_info:*' enable git svn
    zstyle ':vcs_info:*' check-for-changes true
    zstyle ':vcs_info:git+set-message:*' hooks git-misc
    zstyle ':vcs_info:git-svn+set-message:*' hooks git-svn-ahead-behind git-stash
    zstyle ':vcs_info:*' unstagedstr   "$pr[red]%B\$pr[modifiedSymbol]%b"
    zstyle ':vcs_info:*' stagedstr     "$pr[yellow]%B\$pr[stagedSymbol]%b"
    zstyle ':vcs_info:svn*' branchformat  "%b$pr[yellow]@%r"
    zstyle ':vcs_info:*' actionformats "\$pr[leftCap]$pr[cyan]%B%a%%b$pr[lineColor]\$pr[vertLine]$vcsBranchFormat$pr[lineColor]\$pr[rightCap]" "$vcsPathFormat"
    zstyle ':vcs_info:*' formats       "\$pr[leftCap]$vcsBranchFormat$pr[lineColor]\$pr[rightCap]" "$vcsPathFormat"
    zstyle ':vcs_info:*' nvcsformats   "" ""


    PROMPT="       %(?..$pr[red]%B\$pr[returnSymbol] \$? %b)$pr[yellow]\${pr[cmdRunTime]:-%(?..
)}
$pr[lineColor]\$pr[leftCorner]\$pr[horzLine]\$pr[horzLine]\$pr[leftCap]\$pr[pwd]$pr[lineColor]\$pr[rightCap]\$pr[horzLine]\${(e)pr[fillBar]}\$pr[waitIndicator]\${(e)pr[vcsInfo]}\$pr[horzLine]\$pr[horzLine]\$pr[rightCorner]
\$pr[vertLine]\$pr[userOrTime] $pr[yellow]%B\$pr[promptSymbol]%b$pr[reset] "

    RPROMPT=" $pr[depth]$pr[lineColor]\$pr[vertLine]$pr[reset]"

    PROMPT2="$pr[lineColor]\$pr[vertLine]$pr[green]%_ $pr[yellow]%B\$pr[promptSymbol]%b$pr[reset] "

    RPROMPT2=$RPROMPT
}

setprompt
unfunction setprompt


# Update the prompt every minute on the minute.
zmodload zsh/datetime
TMOUT=$(( 60 - ($EPOCHSECONDS % 60) ))
function TRAPALRM()
{
    TMOUT=$(( 60 - ($EPOCHSECONDS % 60) ))
    updatePromptInfo
}


# Update the prompt when the console size changes.
#
# Note that this still eats scrollback when making the window narrower via
# dragging, but I've decided I can live with that because I only ever resize
# consoles in descrete steps. (Maximize, half-screen, split, etc.)
function TRAPWINCH()
{
    updatePromptInfo
}
