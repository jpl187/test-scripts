#!/bin/bash

# Pfad zu den Postfix-Dateien
POSTFIX_PATH="/pfad/zu/postfix/dateien"

# Datei, die das letzte Überwachungsdatum speichert
LAST_RUN_FILE="/var/tmp/last_clamav_scan"

# Falls die Datei nicht existiert, erstelle sie und setze das aktuelle Datum
if [ ! -f "$LAST_RUN_FILE" ]; then
    date '+%Y-%m-%d %H:%M:%S' > "$LAST_RUN_FILE"
fi

# Finde alle Dateien, die nach dem letzten Lauf erstellt wurden
NEW_FILES=$(find "$POSTFIX_PATH" -type f -newermt "$(cat $LAST_RUN_FILE)")

# Aktualisiere das Datum des letzten Laufs
date '+%Y-%m-%d %H:%M:%S' > "$LAST_RUN_FILE"

# Scanne die neuen Dateien mit ClamAV
for FILE in $NEW_FILES; do
    clamscan "$FILE"
done

