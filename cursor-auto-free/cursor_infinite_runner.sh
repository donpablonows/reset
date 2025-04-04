#!/bin/bash

# Get the directory of the script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Navigate to the script directory
cd "$SCRIPT_DIR"

# Create a log directory if it doesn't exist
mkdir -p logs

# Function to run the cursor script
run_cursor_script() {
    echo "$(date) - Starting cursor keep alive script" >> logs/cursor_infinite.log
    python3 cursor_pro_keep_alive.py >> logs/cursor_output.log 2>&1
    echo "$(date) - Cursor script completed" >> logs/cursor_infinite.log
}

echo "Starting infinite runner for Cursor Keep Alive at $(date)" >> logs/cursor_infinite.log
echo "This script will run cursor_pro_keep_alive.py every hour indefinitely" >> logs/cursor_infinite.log

# Run in an infinite loop
while true; do
    run_cursor_script
    
    # Display next scheduled run time
    next_run=$(date -d "+1 hour" "+%Y-%m-%d %H:%M:%S")
    echo "Next run scheduled at: $next_run" >> logs/cursor_infinite.log
    
    # Wait for 1 hour (3600 seconds)
    sleep 3600
done 