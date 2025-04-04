# PowerShell script to run the cursor keep alive script

# Get the script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Navigate to the script directory
Set-Location $scriptDir

# Create logs directory if it doesn't exist
if (-not (Test-Path "logs")) {
    New-Item -ItemType Directory -Path "logs" | Out-Null
}

# Function to run the cursor script
function Run-CursorScript {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path "logs\cursor_scheduler.log" -Value "$timestamp - Starting cursor keep alive script"
    
    try {
        # Run the Python script and redirect output to log file
        python cursor_pro_keep_alive.py 2>&1 | Out-File -Append -FilePath "logs\cursor_output.log"
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -Path "logs\cursor_scheduler.log" -Value "$timestamp - Cursor script completed successfully"
    }
    catch {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -Path "logs\cursor_scheduler.log" -Value "$timestamp - Error running cursor script: $_"
    }
}

# Set up scheduled task for hourly execution
function Register-ScheduledTask {
    $taskName = "CursorKeepAliveHourly"
    $taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

    if (-not $taskExists) {
        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File `"$scriptDir\run_cursor_keep_alive.ps1`""
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1)
        $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description "Runs Cursor Keep Alive script hourly"
        
        Add-Content -Path "logs\cursor_scheduler.log" -Value "Registered hourly scheduled task: $taskName"
    }
    else {
        Add-Content -Path "logs\cursor_scheduler.log" -Value "Scheduled task already exists: $taskName"
    }
}

# Create the scheduled task
Register-ScheduledTask

# Run the script immediately for the first time
Run-CursorScript 