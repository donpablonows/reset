# Cursor Pro Automation Tool User Guide

README also available in: [中文](./README.md)

## Online Documentation
[cursor-auto-free-doc.vercel.app](https://cursor-auto-free-doc.vercel.app)

## Note
Recently, some users have sold this software on platforms like Xianyu. Please avoid such practices—there's no need to earn money this way.

## Sponsor for More Updates
![image](./screen/afdian-[未认证]阿臻.jpg)

## License
This project is licensed under [CC BY-NC-ND 4.0](https://creativecommons.org/licenses/by-nc-nd/4.0/).  
This means you may:  
- **Share** — Copy and redistribute the material in any medium or format.  
But you must comply with the following conditions:
- **Non-commercial** — You may not use the material for commercial purposes.

## Features
Automated account registration and token refreshing to free your hands.

## Important Notes
1. **Ensure you have Chrome installed. If not, [download here](https://www.google.com/intl/en_pk/chrome/).**  
2. **You must log into your account, regardless of its validity. Logged-in is mandatory.**  
3. **A stable internet connection is required, preferably via an overseas node. Do not enable global proxy.**

## Configuration Instructions
Please refer to our [online documentation](https://cursor-auto-free-doc.vercel.app) for detailed configuration instructions.

## Download
[https://github.com/chengazhen/cursor-auto-free/releases](https://github.com/chengazhen/cursor-auto-free/releases)

## Update Log
- **2025-01-09**: Added logs and auto-build feature.  
- **2025-01-10**: Switched to Cloudflare domain email.  
- **2025-01-11**: Added headless mode and proxy configuration through .env file.
- **2025-01-20**: Added IMAP to replace tempmail.plus.

## Special Thanks
This project has received support and help from many open source projects and community members. We would like to express our special gratitude to:

### Open Source Projects
- [go-cursor-help](https://github.com/yuaotian/go-cursor-help) - An excellent Cursor machine code reset tool with 9.1k Stars. Our machine code reset functionality is implemented using this project, which is one of the most popular Cursor auxiliary tools.

Inspired by [gpt-cursor-auto](https://github.com/hmhm2022/gpt-cursor-auto); optimized verification and email auto-registration logic; solved the issue of not being able to receive email verification codes.

# Cursor Pro Keep Alive

This tool helps keep Cursor Pro active by automatically registering new accounts and resetting machine IDs as needed. This README explains how to set up the tool to run automatically every hour on Linux and Windows systems.

## Setup Instructions

### Prerequisites

- Python 3.6 or higher
- Required Python packages (install using `pip install -r requirements.txt`)
- Internet connection

## Running Automatically Every Hour

### Linux Setup

You have two options for running the script automatically on Linux:

#### Option 1: Cron Job (Recommended)

1. Make the shell script executable:
   ```bash
   chmod +x run_cursor_keep_alive.sh
   ```

2. Run the shell script once to set up the cron job:
   ```bash
   ./run_cursor_keep_alive.sh
   ```

This will:
- Add an entry to your crontab to run the script every hour
- Run the script immediately for the first time
- Create log files in the `logs` directory

To verify the cron job was added:
```bash
crontab -l
```

#### Option 2: Infinite Loop Script

If you prefer to run the script in an infinite loop (useful for servers that stay on):

1. Make the infinite runner script executable:
   ```bash
   chmod +x cursor_infinite_runner.sh
   ```

2. Start the script:
   ```bash
   ./cursor_infinite_runner.sh
   ```

3. To keep it running even after you close the terminal:
   ```bash
   nohup ./cursor_infinite_runner.sh &
   ```

### Windows Setup

You have two options for running the script automatically on Windows:

#### Option 1: Task Scheduler via PowerShell (Recommended)

1. Run PowerShell as Administrator
2. Navigate to the script directory:
   ```powershell
   cd "path\to\script\directory"
   ```
3. Allow execution of the script:
   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass
   ```
4. Run the PowerShell script:
   ```powershell
   .\run_cursor_keep_alive.ps1
   ```

This will:
- Create a scheduled task that runs every hour
- Run the script immediately for the first time
- Create log files in the `logs` directory

#### Option 2: Infinite Loop Batch File

1. Double-click the `cursor_infinite_runner.bat` file

This will:
- Start a command prompt window
- Run the script in an infinite loop, with 1-hour intervals
- Create log files in the `logs` directory

To keep it running in the background:
1. Create a shortcut to `cursor_infinite_runner.bat`
2. Right-click on the shortcut and select Properties
3. In the "Run" dropdown, select "Minimized"
4. Optionally, add this shortcut to your startup folder

## Logging

All scripts create logs in the `logs` directory:
- `cursor_scheduler.log`: Records when the script starts and finishes
- `cursor_output.log`: Contains the actual output from the Python script
- `cursor_infinite.log`: Used by the infinite runner scripts

## Troubleshooting

- If the scripts fail to run, check if Python is in your PATH
- Ensure all required Python packages are installed
- Check the log files for error messages
- On Linux, make sure the shell scripts have execute permissions

## Security Notes

- The scripts save account credentials in logs
- Consider using a dedicated machine or virtual machine for this purpose
- Review the scripts carefully before running them
