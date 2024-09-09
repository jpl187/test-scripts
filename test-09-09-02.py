#!/usr/bin/env python3

import asyncio
import os
import hashlib
import shutil
import json
from vaas import Vaas, ResourceOwnerPasswordGrantAuthenticator

# Configuration
INCOMING_DIR = "/var/spool/postfix/incoming/"
QUARANTINE_DIR = "/var/quarantine/"
PROCESSED_FILES_LOG = "/var/log/processed_files.json"

# VaaS Configuration (Username and Password)
USERNAME = "your_vaas_username"
PASSWORD = "your_vaas_password"
TOKEN_URL = "https://account.gdata.de/realms/vaas-production/protocol/openid-connect/token"
VAAS_URL = "wss://gateway.production.vaas.gdatasecurity.de"

async def scan_file_with_vaas(file_path):
    """Scan a file using GDATA VaaS service and return the verdict."""
    try:
        # Authenticate using the ResourceOwnerPasswordGrantAuthenticator
        authenticator = ResourceOwnerPasswordGrantAuthenticator(
            "vaas-customer",
            USERNAME,
            PASSWORD,
            token_endpoint=TOKEN_URL
        )

        # Open the VaaS connection and scan the file
        async with Vaas(url=VAAS_URL) as vaas:
            await vaas.connect(await authenticator.get_token())
            with open(file_path, "rb") as file:
                verdict = await vaas.for_file(file)
            return verdict['Verdict']
    except Exception as e:
        print(f"Error scanning file {file_path}: {e}")
        return None

def hash_file(file_path):
    """Generate SHA256 hash for the file."""
    sha256_hash = hashlib.sha256()
    with open(file_path, "rb") as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()

def load_processed_files():
    """Loads a dictionary of already processed file hashes from a log file."""
    if os.path.exists(PROCESSED_FILES_LOG):
        with open(PROCESSED_FILES_LOG, "r") as f:
            return json.load(f)
    return {}

def save_processed_file(file_path, file_hash):
    """Save the hash of a processed file to avoid rescanning it."""
    processed_files = load_processed_files()
    processed_files[file_hash] = file_path
    with open(PROCESSED_FILES_LOG, "w") as f:
        json.dump(processed_files, f)

def move_to_quarantine(file_path):
    """Move malicious file to quarantine."""
    if not os.path.exists(QUARANTINE_DIR):
        os.makedirs(QUARANTINE_DIR)
    shutil.move(file_path, os.path.join(QUARANTINE_DIR, os.path.basename(file_path)))

async def process_file(file_path):
    """Check if a file has been scanned before, scan it if not, and move malicious files to quarantine."""
    file_hash = hash_file(file_path)
    
    # Load the previously processed files
    processed_files = load_processed_files()

    if file_hash in processed_files:
        print(f"Skipping already processed file: {file_path}")
        return

    print(f"Scanning file: {file_path}")
    verdict = await scan_file_with_vaas(file_path)

    if verdict:
        if verdict.lower() == "malicious":
            print(f"File {file_path} is MALICIOUS, moving to quarantine.")
            move_to_quarantine(file_path)
        else:
            print(f"File {file_path} is CLEAN.")
        save_processed_file(file_path, file_hash)
    else:
        print(f"Failed to get verdict for file: {file_path}")

async def main():
    """Main function to scan all files in the incoming directory."""
    for file_name in os.listdir(INCOMING_DIR):
        file_path = os.path.join(INCOMING_DIR, file_name)
        if os.path.isfile(file_path):
            await process_file(file_path)

if __name__ == "__main__":
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    loop.run_until_complete(main())

