#!/bin/bash
DEBUG=/var/log/VA-debug.log
touch /var/log/VA-debug.log
exec > >(tee -a "$DEBUG") 2>&1
POSTFIX_DIR_INC="/var/spool/postfix/incoming"
CACHE="/var/log/Email-scan.log"
echo "--------------$date----------------------"
if [ ! -f "$LAST_RUN_FILE" ]; then
    date '+%Y-%m-%d %H:%M:%S' > "$CACHE"
fi
NEW_FILES=$(find "$POSTFIX_DIR_INC" -type f -newermt "$(cat $CACHE)")
date '+%Y-%m-%d %H:%M:%S' > "$CACHE"
for FILE in $NEW_FILES; do
    clamscan "$FILE"
done
echo "-------------END--$date---------------------"
exit 0
