#!/bin/bash
DEBUG=/var/log/VA-debug.log
touch /var/log/VA-debug.log
exec > >(tee -a "$DEBUG") 2>&1
POSTFIX_DIR_INC="/var/spool/postfix/incoming"
CACHE="/var/log/Email-scan.log"
echo "----------------------$date-------------------------------"
if [ ! -f "$CACHE" ]; then
    echo "---" > "$CACHE"
fi

find "$POSTFIX_DIR_INC" -type f | while read -r FILE; do
    FILE_SIZE=$(stat -c%s "$FILE")
    FILE_NAME=$(basename "$FILE")

    EXISTING_LOG_ENTRY=$(grep -A2 "file: \"$FILE_NAME\"" "$SCAN_LOG")

    if [ -z "$EXISTING_LOG_ENTRY" ]; then
        echo "Scanning new file: $FILE"
        clamscan "$FILE"

        echo "- file: \"$FILE_NAME\"" >> "$CACHE"
        echo "  size: $FILE_SIZE" >> "$CACHE"
        echo "  last_scan: $(date '+%Y-%m-%d %H:%M:%S')" >> "$CACHE"
    else
        LOGGED_SIZE=$(echo "$EXISTING_LOG_ENTRY" | grep "size:" | awk '{print $2}')
        
        if [ "$FILE_SIZE" -ne "$LOGGED_SIZE" ]; then
            echo "File changed, scanning again: $FILE"
            clamscan "$FILE"

            sed -i "/- file: \"$FILE_NAME\"/,+2 s/size: .*/size: $FILE_SIZE/" "$CACHE"
            sed -i "/- file: \"$FILE_NAME\"/,+2 s/last_scan: .*/last_scan: $(date '+%Y-%m-%d %H:%M:%S')/" "$CACHE"
        fi
    fi
done
echo "-----------------------END-------$date--------------------"
exit 0 
