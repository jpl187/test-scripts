#!/bin/bash

LOG_FILE="/path/to/your/logfile.log"
QUARANTINE_DIR="/var/quarantine/"

mkdir -p "$QUARANTINE_DIR"

# Read the log file
while IFS= read -r line; do
    if [[ "$line" =~ ^scanning\ new\ file:\ (.+)$ ]]; then
        file_path="${BASH_REMATCH[1]}"
        read -r status
        if [[ "$status" == "Malicous" ]]; then
            echo "Moving malicious file: $file_path"
            mv "$file_path" "$QUARANTINE_DIR"
        else
            echo "File is clean: $file_path"
        fi
    fi
done < "$LOG_FILE"
