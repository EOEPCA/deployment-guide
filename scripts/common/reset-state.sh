#!/bin/bash

STATE_FILE="$HOME/.eoepca/state"

if [ -f "$STATE_FILE" ]; then
    echo "Processing the state file..."
    rm "$STATE_FILE"

else
    echo "State file does not exist."
fi
