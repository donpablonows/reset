$ErrorActionPreference = "Stop"

# Show a loader animation
function Show-Loader {
    param (
        [int]$DurationInSeconds,
        [string]$Message = "Processing..."
    )
    
    $spinner = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    $counter = 0
    $endTime = (Get-Date).AddSeconds($DurationInSeconds)
    
    while ((Get-Date) -lt $endTime) {
        Write-Host "`r$Message $($spinner[$counter % $spinner.Length])" -NoNewline
        Start-Sleep -Milliseconds 100
        $counter++
    }
    Write-Host "`r$Message Complete!" + " " * 10
}

# Function to stop any running Cursor processes
function Stop-CursorProcesses {
    $processesStopped = $false
    $maxAttempts = 5
    $attempt = 1

    while (-not $processesStopped -and $attempt -le $maxAttempts) {
        $cursorProcesses = Get-Process | Where-Object {$_.Name -like "cursor*"}

        if ($cursorProcesses) {
            Write-Host "Attempt ${attempt} to force stop processes..."
            foreach ($process in $cursorProcesses) {
                try {
                    Write-Host "Stopping process: $($process.Name) with ID $($process.Id)"
                    $process | Stop-Process -Force -ErrorAction Stop
                    Start-Sleep -Seconds 1
                }
                catch {
                    Write-Host "Could not stop process $($process.Name) (ID: $($process.Id))."
                }
            }
        }

        $remainingProcesses = Get-Process | Where-Object {$_.Name -like "cursor*"}
        if (-not $remainingProcesses) {
            $processesStopped = $true
            Write-Host "All Cursor processes stopped successfully."
        }
        else {
            Write-Host "Some processes remain. Attempt ${attempt} of ${maxAttempts}."
            $attempt++
            Start-Sleep -Seconds 2
        }
    }

    if (-not $processesStopped) {
        throw "Failed to stop all Cursor processes after ${maxAttempts} attempts."
    }
}

# Function to remove all Cursor-related directories and files
function Remove-CursorDirectories {
    Write-Host "Cleaning up Cursor directories..."
    $paths = @(
        (Join-Path $env:USERPROFILE ".cursor"),
        (Join-Path $env:LOCALAPPDATA "cursor-updater"),
        (Join-Path $env:LOCALAPPDATA "Programs\cursor"),
        (Join-Path $env:APPDATA "Cursor"),
        (Join-Path $env:LOCALAPPDATA "Cursor"),
        (Join-Path $env:PROGRAMFILES "Cursor")
    )

    foreach ($path in $paths) {
        if (Test-Path $path) {
            Write-Host "Removing directory: ${path}"
            Remove-Item -Recurse -Force $path -ErrorAction SilentlyContinue
        }
    }
}

# Function to remove all Cursor-related registry keys
function Remove-CursorRegistry {
    Write-Host "Cleaning up Cursor registry keys..."
    $registryPaths = @(
        "HKCU:\Software\Cursor",
        "HKLM:\Software\Cursor",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Cursor",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Cursor",
        "HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules"
    )

    foreach ($regPath in $registryPaths) {
        if (Test-Path $regPath) {
            Write-Host "Removing registry key: ${regPath}"
            Remove-Item -Recurse -Force $regPath -ErrorAction SilentlyContinue
        }
    }
}

# Function to install the Cursor application
function Install-Cursor {
    Write-Host "Installing Cursor..."
    $installerPath = "./cursor.exe"  # Make sure this is the correct installer path
    
    if (-not (Test-Path $installerPath)) {
        throw "Installer not found at: ${installerPath}"
    }

    try {
        $process = Start-Process -FilePath $installerPath -ArgumentList "/S" -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            throw "Installation failed with exit code: $($process.ExitCode)"
        }
        
        Write-Host "Waiting for installation to complete..."
        Show-Loader -DurationInSeconds 10 -Message "Installing"
        
        $installPath = Join-Path $env:LOCALAPPDATA "Programs\cursor\Cursor.exe"
        if (-not (Test-Path $installPath)) {
            throw "Installation verification failed: Cursor.exe not found"
        }
        
        Write-Host "Cursor installation completed successfully`n"
        return $true
    }
    catch {
        Write-Host "Installation failed: $($_.Exception.Message)"
        throw
    }
}


function Initialize-CursorApp {
    Write-Host "Step 4/5: Initializing Cursor..."
    try {
        # Start the Cursor app in hidden mode
        Start-Process (Join-Path $env:LOCALAPPDATA "Programs\cursor\Cursor.exe") -WindowStyle Hidden
        Write-Host "Waiting for initialization..."

        # Wait until the storage file exists
        $storagePath = Join-Path $env:APPDATA "Cursor\User\globalStorage\storage.json"
        
        $maxWaitTime = 60 # Max wait time in seconds (adjust as needed)
        $waitTime = 0
        $fileExists = $false

        while ($waitTime -lt $maxWaitTime -and -not $fileExists) {
            if (Test-Path $storagePath) {
                $fileExists = $true
            }
            else {
                Write-Host "Storage file not found. Waiting..."
                Start-Sleep -Seconds 5
                $waitTime += 5
            }
        }

        Write-Host "Cursor initialization step completed`n"
    }
    catch {
        throw "Failed to initialize Cursor: $($_.Exception.Message)"
    }
}

# Main execution sequence
try {
    Write-Host "Starting complete Cursor cleanup and reinstallation..."

    # Stop all running processes related to Cursor
    Stop-CursorProcesses

    # Remove all Cursor-related directories
    Remove-CursorDirectories

    # Remove all registry keys related to Cursor
    Remove-CursorRegistry

    # Install the Cursor application again
    Install-Cursor

    # Final initialization step
    Initialize-CursorApp
	
	py .\reset.py
}
catch {
    Write-Host "`nError: $($_.Exception.Message)"
    Write-Host "Process failed - please check the error message above."
    exit 1
}
