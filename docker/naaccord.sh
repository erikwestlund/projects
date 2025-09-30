#!/bin/zsh

# Wrapper script that delegates to the consolidated naaccord-docker.sh script
exec "$HOME/code/naaccord/scripts/naaccord-docker.sh" "$@"