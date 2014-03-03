function preexec()
{
    PR_LASTCMDSTART=$SECONDS
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
    # Replace $HOME by ~.
    local newPath="${1/$HOME/~}"

    local integer charsToRemove
    (( charsToRemove = $(expandStripLength $newPath) - $2 ))

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
                local integer charsToKeep
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
            newPath="${newPath[-$2,-1]}"

            # If the resulting path contains an elipsis, drop everything before
            # it, otherwise replace the first character with an elipsis.
            local integer firstElipsis=${newPath[(i)…]}
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
    integer -Z2 seconds=$1
    if (( $seconds >= 60 )); then
        integer minutes
        (( minutes = $seconds / 60 ))
        (( seconds = $seconds % 60 ))
    fi
    echo "${minutes}m${seconds}s"
}

function +vi-git-stash()
{
    local stashCount=$(git stash list 2>/dev/null | wc -l)
    if (( $stashCount > 0 )); then
        if (( $stashCount == 1 )); then
            stashCount=''
        fi
        hook_com[misc]+="$PR_BLUE│$PR_MAGENTA$stashCount$PR_STASH"
    fi
}

function +vi-git-ahead-behind()
{
    git-ahead-behind "$hook_com[branch]@{upstream}"
}

function +vi-git-svn-ahead-behind()
{
    local svnBranch=$(git log -1 --first-parent --grep="^git-svn-id: "\
                      | perl -ne 'm/git-svn-id:.*\/(\w+)@\d+/; print $1')
    git-ahead-behind "remotes/$svnBranch"
}

function git-ahead-behind()
{
    local remote=$1

    if git rev-parse $remote &>/dev/null; then
        integer ahead=$(git rev-list $remote..HEAD 2>/dev/null | wc -l)
        integer behind=$(git rev-list HEAD..$remote 2>/dev/null | wc -l)

        if (( $ahead > 0 )); then
            hook_com[misc]+="$PR_BLUE│$PR_YELLOW$PR_BRANCHAHEAD$ahead"
        fi

        if (( $behind > 0 )); then
            hook_com[misc]+="$PR_BLUE│$PR_YELLOW$PR_BRANCHBEHIND$behind"
        fi
    fi
}

function precmd()
{
    integer cmd_seconds
    (( cmd_seconds = $SECONDS - ${PR_LASTCMDSTART:=$SECONDS} ))
    PR_LASTCMDSTART=""
    PR_CMDRUNTIME=""
    if (( $cmd_seconds > 7 && $TTYIDLE > 7 )); then
        PR_CMDRUNTIME="$PR_TIMEINDICATOR $(elapsedTimeFormat $cmd_seconds)
"
    fi

    vcs_info

    integer maxPathLength
    (( maxPathLength = $COLUMNS - $(expandStripLength "╭──┤├─$vcs_info_msg_0_──╮_") ))

    PR_PWD="${(%):-${vcs_info_msg_1_%%.}}"
    PR_PWD=$(compressPath "$PR_PWD" $maxPathLength)

    integer fillerLength
    (( fillerLength = $maxPathLength - $(expandStripLength "$PR_PWD") ))
    PR_FILLER="\${(l.$fillerLength..─.)}"

    if [[ "${(%):-%n@%m}" != "$PR_DEFAULT_USER" ]] || [[ -n "$SSH_TTY" ]]; then
        PR_USERORTIME="$PR_GREEN%n$PR_CYAN@%m"
    else
        PR_USERORTIME="$PR_GREEN%D{%H:%M}"
    fi
}

function setprompt()
{
    setopt PROMPT_SUBST

    autoload colors zsh/terminfo
    if [[ "$terminfo[colors]" -ge 8 ]]; then
        colors
    fi
    for color in RED GREEN YELLOW BLUE MAGENTA CYAN WHITE; do
        eval PR_$color='%{$fg[${(L)color}]%}'
    done
    PR_RESET="%{$terminfo[sgr0]%}"

    # Virtual consoles don't support Unicode fanciness.
    if [[ "$TERM" == xterm* || ("$TERM" = "screen" && (-n "$DISPLAY" || -n "$SSH_TTY")) ]]; then
        local PR_LEFTCORNER='╭'
        local PR_RIGHTCORNER='╮'
        local PR_PROMPTCHAR='❱'
        local PR_MINUSPLUS='∓'
        local PR_TIMEINDICATOR='⌛'
        local PR_RETURNINDICATOR='↳'
        PR_BRANCHAHEAD='↥'
        PR_BRANCHBEHIND='↧'
        PR_STASH='↶'
    else
        local PR_LEFTCORNER='┌'
        local PR_RIGHTCORNER='┐'
        local PR_PROMPTCHAR='>'
        local PR_MINUSPLUS='±'
        local PR_TIMEINDICATOR='Runtime:'
        local PR_RETURNINDICATOR='Returned:'
        PR_BRANCHAHEAD='+'
        PR_BRANCHBEHIND='-'
        PR_STASH='#'
    fi

    autoload -Uz vcs_info
    local PR_BRANCHFORMAT="%u%c$PR_GREEN%b%m"
    local PR_PATHFORMAT="%R$PR_YELLOW/%S"

    zstyle ':vcs_info:*' enable git svn
    zstyle ':vcs_info:*' check-for-changes true
    zstyle ':vcs_info:git+set-message:*' hooks git-ahead-behind git-stash
    zstyle ':vcs_info:git-svn+set-message:*' hooks git-svn-ahead-behind git-stash
    zstyle ':vcs_info:*' unstagedstr   "$PR_RED%B±%b"
    zstyle ':vcs_info:*' stagedstr     "$PR_YELLOW%B$PR_MINUSPLUS%b"
    zstyle ':vcs_info:svn*' branchformat  "%b$PR_YELLOW@%r"
    zstyle ':vcs_info:*' actionformats "┤$PR_CYAN%B%a%%b$PR_BLUE│$PR_BRANCHFORMAT$PR_BLUE├" "$PR_PATHFORMAT"
    zstyle ':vcs_info:*' formats       "┤$PR_BRANCHFORMAT$PR_BLUE├" "$PR_PATHFORMAT"
    zstyle ':vcs_info:*' nvcsformats   "" "%d"

    PROMPT="       %(?..$PR_RED%B\$PR_RETURNINDICATOR $? %b)$PR_YELLOW\${PR_CMDRUNTIME:-%(?..
)}
$PR_BLUE$PR_LEFTCORNER──$PR_USER┤$PR_WHITE%B\$PR_PWD%b$PR_BLUE├─\
\${(e)PR_FILLER}\$vcs_info_msg_0_$PR_BLUE──$PR_RIGHTCORNER
$PR_BLUE│\$PR_USERORTIME $PR_YELLOW%B$PR_PROMPTCHAR%b$PR_RESET "

    RPROMPT="$PR_BLUE│$PR_RESET"

    PROMPT2="$PR_BLUE│$PR_GREEN%_ $PR_YELLOW%B$PR_PROMPTCHAR%b$PR_RESET "

    RPROMPT2=$RPROMPT
}

setprompt
