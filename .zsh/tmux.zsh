function t()
{
    if [[ -z "$TMUX" ]]; then
        tmux start-server
        if tmux has-session -t $USER; then
            tmux attach-session -t $USER
        else
            tmux new-session -s $USER "$argv[1,-1]"
        fi
    elif [[ "$argv[1]" = "-h" || "$argv[1]" = "-v" ]]; then
        tmux split-window $argv[1] "$argv[2,-1]"
    else
        tmux new-window "$argv[1,-1]"
    fi
}

