#!/bin/bash

STATE_FILE="$HOME/.eoepca/state"

if [ -f "$STATE_FILE" ]; then
    echo "Removing the state file..."
    rm "$STATE_FILE"
    echo "State file has been removed"

else
    echo "State file does not exist."
fi
