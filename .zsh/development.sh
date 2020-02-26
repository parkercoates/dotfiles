#! /bin/sh

export CMAKE_GENERATOR=Ninja

export NINJA_STATUS='[%f/%t %r×] '

export MAKEFLAGS="-j$(nproc)"

export GCC_COLORS='error=01;31:warning=01;33:note=01;36:caret=01;32:locus=01:quote=36'

export QT_MESSAGE_PATTERN="$(echo -e '[\e[32m%{time process} %{if-debug}\e[36m%{endif}%{if-warning}\e[33m%{endif}%{if-critical}\e[31m%{endif}%{function}\e[0m] %{message}')"
export QML_IMPORT_TRACE='1'

function qtc() {
    workdir=$(pwd | grep -P -o '[\w-]+-worktree')
    if [[ -n "$workdir" ]]; then
        echo $workdir
        qtcreator "$workdir" &>/dev/null&|
    else
        qtcreator &>/dev/null&|
    fi
}


function findroot()
{
    git rev-parse --show-toplevel
}

function findbuild()
{
    echo "$(findroot)/build"
}

function cdroot()
{
    root=$(findroot) || return $?
    cd "$root"
    return $?
}

function mcb()
{
    buildDir=$(findbuild)
    mkdir -p "$buildDir" && cd "$buildDir"
}

function cb()
{
    [[ "$PWD" =~ "/build\b" ]] && return 0

    root="$(findroot)" || return $?
    relDir="$(echo $PWD | sed -e "s:$root::")"
    cd "$root/build$relDir"
    return $?
}

function cs()
{
    [[ "$PWD" =~ "/build\b" ]] || return 0

    root="$(findroot)" || return $?
    relDir="$(echo $PWD | sed -e "s:$root/build::")"
    cd "$root/$relDir"
    return $?
}

function cmg()
{
    cmake-gui "$(findbuild)"  &>/dev/null&|
}

function istarget()
{
    ninja -C "$(findbuild)" -t targets all | grep "^$1:" > /dev/null;
}

function bld()
{
    flags=''
    targets=''
    while [ $# -gt 0 ]; do
        case "$1" in
        -*)
            flags="$flags $1"
            ;;
        *)
            targets="$targets $1"
            ;;
        esac
        shift
    done

    if [ -z "$targets" ]; then
        rootDir="$(findroot)"
        relDir="$(echo $PWD | sed -e "s:$rootDir::")"
        folderTarget="folder$(echo $relDir | sed -e "s:/:-:g")"
        nameTarget=$(basename $PWD)
        if istarget "$folderTarget"; then
            targets="$folderTarget"
        elif istarget "$nameTarget"; then
            targets="$nameTarget"
        else
            targets="all"
        fi
        echo "Automatically chose target: $targets"
    fi

    eval "ninja -C \"$(findbuild)\" $flags $targets"
}

function cln()
{
    cb && find . -type f \( -name '*.o' -o -name '*.ghc' -o -name 'ui_*.h' -o -name 'moc_*.cpp' -o -name '*.moc' \) -delete -print
    cs
}

function findapp()
{
    app="$1"
    [ -n "$app" ] || app="$(basename "$PWD")"
    binPath="$(findroot)/build/bin/$app"
    if [ ! -x "$binPath" ]; then
        echo "$binPath is not a valid executable." 1>&2
        return 1
    fi
    echo $binPath
}

function run()
{
    binPath=$(findapp $1) || return $?
    shift
    $binPath $@
}

function bldrun()
{
    bld "$1" && run "$@"
}
