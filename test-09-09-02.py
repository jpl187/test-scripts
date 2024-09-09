#!/usr/bin/env python3

import os
import shutil
import hashlib
import json
from vaas.client import Vaas
import urllib.parse

# Configuration
INCOMING_DIR = "/var/spool/postfix/incoming/"
QUARANTINE_DIR = "/var/quarantine/"
PROCESSED_FILES_LOG = "/var/log/processed_files.json"

# Credentials (replace these with your actual username and password)
USERNAME = "your_vaas_username"
PASSWORD = "your_vaas_password_with_special_characters"

# Encode the password to safely handle special characters
encoded_password = urllib.parse.quote(PASSWORD)

# Initialize Vaas client using username and encoded password
client = Vaas(username=USERNAME, password=encoded_password)

def load_processed_files():
    """Loads a list of already processed files based on their hash from a log file."""
    if os.path.exists(PROCESSED_FILES_LOG):
        with open(PROCESSED_FILES_LOG, 'r') as f:
            return json.load(f)
    return {}

def save_processed_file(file_path, file_hash):
    """Save the hash of a processed file to ensure it won't be re-scanned."""
    processed_files = load_processed_files()
    processed_files[file_hash] = file_path
    with open(PROCESSED_FILES_LOG, 'w') as f:
        json.dump(processed_files, f)

def hash_file(file_path):
    """Generate SHA256 hash for the file."""
    sha256_hash = hashlib.sha256()
    with open(file_path, "rb") as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()

def scan_file(file_path):
    """Scan a file using the VaaS service and return the result."""
    try:
        with open(file_path, 'rb') as f:
            scan_result = client.scan(f)
        return scan_result
    except Exception as e:
        print(f"Error scanning file {file_path}: {e}")
        return None

def process_file(file_path):
    """Scan a file and move it to quarantine if malicious or mark it as clean."""
    file_hash = hash_file(file_path)
    
    # Load already processed files
    processed_files = load_processed_files()

    if file_hash in processed_files:
        print(f"Skipping already processed file: {file_path}")
        return

    print(f"Scanning file: {file_path}")
    scan_result = scan_file(file_path)

    if scan_result:
        if scan_result['malicious']:
            print(f"File {file_path} is MALICIOUS, moving to quarantine.")
            shutil.move(file_path, os.path.join(QUARANTINE_DIR, os.path.basename(file_path)))
        else:
            print(f"File {file_path} is CLEAN.")
        save_processed_file(file_path, file_hash)
    else:
        print(f"Failed to scan file: {file_path}")

def main():
    if not os.path.exists(QUARANTINE_DIR):
        os.makedirs(QUARANTINE_DIR)

    for file_name in os.listdir(INCOMING_DIR):
        file_path = os.path.join(INCOMING_DIR, file_name)
        if os.path.isfile(file_path):
            process_file(file_path)

if __name__ == "__main__":
    main()

