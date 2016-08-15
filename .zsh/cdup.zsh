function cdup()
{
    if [[ -z "$1" ]]; then
        cd ..
    else
        local -a cdpathtemp
        local integer depth=${#PWD//[^\/]/}
        for (( i = 1; i <= depth; i++ )); do
            cdpathtemp+=(${(l:(($i * 3 - 1))::../::..:)})
        done
        cdpath=($cdpathtemp) cd $1
    fi
    return $?


#     if [[ -z "$1" ]]; then
#         cd ..
#     else
#         local -a cdpathtemp
#         local -a segments
#         segments=(${(s:/:)$(pwd | sed --posix 's:[^/][^/]*:..:g')})
#         while (( ${#segments} > 0 )); do
#             cdpathtemp[1,0]=(${(j:/:)segments})
#             shift segments
#         done
#         echo "[$cdpathtemp] ${#cdpathtemp}"
#         cdpath=($cdpathtemp) cd $1
#     fi
#     return $?


#    local ancestor=".."
#    while true; do
#        if [[ -d "$ancestor/$1" ]]; then
#            cd "$ancestor/$1"
#            return $?
#        elif [[ "$(readlink --canonicalize-missing $ancestor)" = "/" ]]; then
#            echo "cdup: Directory '$1' not found above this directory." >&2
#            return 1
#        fi
#        ancestor="$ancestor/.."
#    done
}
