typeset ENV_FILE
ENV_FILE="$HOME/.ssh/environment-$HOST"

function start_ssh_agent() {
    ssh-agent -s | sed 's/^echo/#echo/' >! $ENV_FILE
    chmod 600 $ENV_FILE
    source $ENV_FILE > /dev/null
}


if [[ -f "$ENV_FILE" ]]; then
    source $ENV_FILE > /dev/null
    ps x | grep ssh-agent | grep -q $SSH_AGENT_PID || {
        start_ssh_agent
    }
else
    start_ssh_agent
fi

unset ENV_FILE
unfunction start_ssh_agent
