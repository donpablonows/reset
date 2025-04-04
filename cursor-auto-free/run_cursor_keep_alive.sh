#!/bin/bash

# Get the directory of the script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Navigate to the script directory
cd "$SCRIPT_DIR"

# Create a log directory if it doesn't exist
mkdir -p logs

# Function to run the cursor script
run_cursor_script() {
    echo "$(date) - Starting cursor keep alive script" >> logs/cursor_scheduler.log
    python3 cursor_pro_keep_alive.py >> logs/cursor_output.log 2>&1
    echo "$(date) - Cursor script completed" >> logs/cursor_scheduler.log
}

# Make the script run at startup by adding it to crontab
setup_cron() {
    # Check if already in crontab
    if ! crontab -l | grep -q "run_cursor_keep_alive.sh"; then
        (crontab -l 2>/dev/null; echo "0 * * * * $SCRIPT_DIR/run_cursor_keep_alive.sh") | crontab -
        echo "Added hourly cron job"
    fi
}

# Set up cron job for hourly execution
setup_cron

# Run immediately for the first time
run_cursor_script

# If you want to also run in an infinite loop as a backup to cron
# Uncomment the following lines:
# while true; do
#     # Wait for 1 hour (3600 seconds)
#     sleep 3600
#     run_cursor_script
# done

exit 0 