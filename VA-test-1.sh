#!/bin/bash

POSTFIX_DIR_INC="/var/spool/postfix/incoming"
CACHE="/var/log/Email-scan.log"
if [ ! -f "$LAST_RUN_FILE" ]; then
    date '+%Y-%m-%d %H:%M:%S' > "$CACHE"
fi
NEW_FILES=$(find "$POSTFIX_DIR_INC" -type f -newermt "$(cat $CACHE)")
date '+%Y-%m-%d %H:%M:%S' > "$CACHE"
for FILE in $NEW_FILES; do
    clamscan "$FILE"
done

