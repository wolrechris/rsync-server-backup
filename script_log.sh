#!/bin/bash
# Run the script and save to log files
./run_sync.sh | tee -a backup.log | tee latest.log
