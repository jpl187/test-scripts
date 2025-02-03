import os
import time
import psutil
from datetime import datetime, timedelta

# Configuration
CPU_THRESHOLD = 20  
DURATION = 2 * 60 * 60  
SCAN_COMMAND = "clamscan -r /"
LAST_RUN_FILE = "/var/log/clamscan_last_run.log"

def get_last_run_time():
    if os.path.exists(LAST_RUN_FILE):
        with open(LAST_RUN_FILE, "r") as f:
            last_run_str = f.read().strip()
            return datetime.strptime(last_run_str, "%Y-%m-%d %H:%M:%S")
    return None

def update_last_run_time():
    now = datetime.now()
    timestamp = now.strftime("%Y-%m-%d %H:%M:%S")  
    with open(LAST_RUN_FILE, "w") as f:
        f.write(f"last run at {timestamp}\n")

def is_cpu_low():
    return psutil.cpu_percent(interval=60) < CPU_THRESHOLD

def main():
    last_run = get_last_run_time()
    if last_run and (datetime.now() - last_run) < timedelta(days=1):
        print("already ran today. Skipping.")
        return

    low_cpu_duration = 0
    while low_cpu_duration < DURATION:
        if is_cpu_low():
            low_cpu_duration += 60
        else:
            low_cpu_duration = 0
        time.sleep(60)

    print("Running clamscan...")
    os.system(SCAN_COMMAND)
    update_last_run_time()

if __name__ == "__main__":
    main()
