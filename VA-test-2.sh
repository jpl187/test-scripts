#!/bin/bash

# Pfad zu den Postfix-Dateien
POSTFIX_PATH="/pfad/zu/postfix/dateien"

# Datei, die die Dateigröße und -namen speichert
SCAN_LOG="/var/tmp/clamav_scan_log.yaml"

# Erstelle die Log-Datei, wenn sie nicht existiert
if [ ! -f "$SCAN_LOG" ]; then
    echo "---" > "$SCAN_LOG"
fi

# Finde alle Dateien im Postfix-Pfad
find "$POSTFIX_PATH" -type f | while read -r FILE; do
    # Hole die aktuelle Größe und den Namen der Datei
    FILE_SIZE=$(stat -c%s "$FILE")
    FILE_NAME=$(basename "$FILE")

    # Prüfe, ob die Datei bereits in der Log-Datei erfasst ist
    EXISTING_LOG_ENTRY=$(grep -A2 "file: \"$FILE_NAME\"" "$SCAN_LOG")

    if [ -z "$EXISTING_LOG_ENTRY" ]; then
        # Initialer Scan, da die Datei noch nicht erfasst wurde
        echo "Scanning new file: $FILE"
        clamscan "$FILE"

        # Protokolliere den Scan
        echo "- file: \"$FILE_NAME\"" >> "$SCAN_LOG"
        echo "  size: $FILE_SIZE" >> "$SCAN_LOG"
        echo "  last_scan: $(date '+%Y-%m-%d %H:%M:%S')" >> "$SCAN_LOG"
    else
        # Extrahiere die Größe der Datei aus der Log-Datei
        LOGGED_SIZE=$(echo "$EXISTING_LOG_ENTRY" | grep "size:" | awk '{print $2}')
        
        # Wenn die Größe oder der Name der Datei sich geändert hat, scanne erneut
        if [ "$FILE_SIZE" -ne "$LOGGED_SIZE" ]; then
            echo "File changed, scanning again: $FILE"
            clamscan "$FILE"

            # Aktualisiere die Log-Datei mit der neuen Größe und dem neuen Scan-Datum
            sed -i "/- file: \"$FILE_NAME\"/,+2 s/size: .*/size: $FILE_SIZE/" "$SCAN_LOG"
            sed -i "/- file: \"$FILE_NAME\"/,+2 s/last_scan: .*/last_scan: $(date '+%Y-%m-%d %H:%M:%S')/" "$SCAN_LOG"
        fi
    fi
done

