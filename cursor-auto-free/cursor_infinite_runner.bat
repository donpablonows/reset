@echo off
setlocal enabledelayedexpansion

:: Get the script directory
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

:: Create logs directory if it doesn't exist
if not exist logs mkdir logs

echo Starting infinite runner for Cursor Keep Alive at %date% %time% >> logs\cursor_infinite.log
echo This script will run cursor_pro_keep_alive.py every hour indefinitely >> logs\cursor_infinite.log

:loop
    echo %date% %time% - Starting cursor keep alive script >> logs\cursor_infinite.log
    
    :: Run the Python script
    python cursor_pro_keep_alive.py >> logs\cursor_output.log 2>&1
    
    echo %date% %time% - Cursor script completed >> logs\cursor_infinite.log
    
    :: Calculate and display next run time
    for /f "tokens=1-4 delims=/ " %%a in ('date /t') do (
        set "current_date=%%a/%%b/%%c"
    )
    for /f "tokens=1-3 delims=: " %%a in ('time /t') do (
        set "current_time=%%a:%%b %%c"
    )
    echo Next run scheduled at: !current_date! !current_time! >> logs\cursor_infinite.log
    
    :: Wait for 1 hour (3600 seconds)
    :: Using timeout instead of sleep for Windows compatibility
    echo Waiting for 1 hour before next run...
    timeout /t 3600 /nobreak > nul
    
    goto loop 