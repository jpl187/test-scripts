#!/usr/bin/env python3

import os
import yaml
import subprocess
from collections import defaultdict
import time

# Paths to scan
PATHS_TO_SCAN = ["/etc", "/opt"]

# Files for cache and log
CACHE_FILE = "cache.yaml"
LOG_FILE = "log.yaml"

def load_yaml(file_path):
    if os.path.exists(file_path):
        with open(file_path, "r") as file:
            data = yaml.safe_load(file)
            if data is None:
                return {}
            return data
    return {}

def save_yaml(data, file_path):
    with open(file_path, "w") as file:
        yaml.safe_dump(data, file)

def get_directory_size(path):
    total_size = 0
    for dirpath, dirnames, filenames in os.walk(path):
        for f in filenames:
            fp = os.path.join(dirpath, f)
            if os.path.exists(fp):
                total_size += os.path.getsize(fp)
    return total_size

def scan_directory(path):
    result = subprocess.run(["gdav", f"scan={path}"], capture_output=True, text=True)
    return result.stdout

def log_entry(log, path, message):
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime())
    if path not in log:
        log[path] = []
    log[path].append({"timestamp": timestamp, "message": message})

def get_next_path_to_scan(path, depth):
    parts = path.rstrip('/').split('/')
    if depth < len(parts):
        next_path = '/'.join(parts[:depth+1]) + '/*'
    else:
        next_path = path + '/*'
    return next_path

def main():
    # Load existing cache and log
    cache = load_yaml(CACHE_FILE)
    log = load_yaml(LOG_FILE)

    # Initialize depth dictionary
    depth_dict = defaultdict(int)

    for path in PATHS_TO_SCAN:
        # Get the depth for the current path
        depth = depth_dict[path]

        # Get the current path to scan based on depth
        current_path = get_next_path_to_scan(path, depth)

        # Get current size of the directory
        current_size = get_directory_size(path)

        # Compare with cached size
        if path in cache and cache[path]["size"] == current_size:
            message = f"No size change detected for {path}."
            log_entry(log, path, message)
        else:
            # Update cache and perform scan
            cache[path] = {"size": current_size, "last_scanned": time.time()}
            scan_output = scan_directory(current_path)
            message = f"Scanned {current_path}. Output:\n{scan_output}"
            log_entry(log, path, message)

            # Increase the depth for the next scan
            depth_dict[path] += 1

    # Save updated cache and log
    save_yaml(cache, CACHE_FILE)
    save_yaml(log, LOG_FILE)

if __name__ == "__main__":
    main()
