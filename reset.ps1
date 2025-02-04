# Cursor Reset and Installation Script
$ErrorActionPreference = "Stop"

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

function Stop-CursorProcesses {
    Write-Host "`nStep 1/6: Stopping Cursor processes..."
    $processesStopped = $false
    $maxAttempts = 3
    $attempt = 1

    while (-not $processesStopped -and $attempt -le $maxAttempts) {
        $cursorProcesses = Get-Process | Where-Object {$_.Name -like "cursor*"}
        
        if ($cursorProcesses) {
            Write-Host "Try ${attempt} to stop processes..."
            foreach ($process in $cursorProcesses) {
                try {
                    $process | Stop-Process -Force
                    Start-Sleep -Seconds 1
                }
                catch {
                    Write-Host "Warning: Process already exited"
                }
            }
        }
        
        $remainingProcesses = Get-Process | Where-Object {$_.Name -like "cursor*"}
        if (-not $remainingProcesses) {
            $processesStopped = $true
            Write-Host "All Cursor processes successfully stopped."
        }
        else {
            Write-Host "Some processes remain. Try ${attempt} of ${maxAttempts}"
            $attempt++
            Start-Sleep -Seconds 2
        }
    }

    if (-not $processesStopped) {
        throw "Failed to stop all Cursor processes after ${maxAttempts} attempts"
    }
    Write-Host "Process cleanup completed successfully`n"
}

function Remove-CursorDirectories {
    Write-Host "Step 2/6: Cleaning up Cursor directories..."
    $paths = @(
        (Join-Path $env:USERPROFILE ".cursor"),
        (Join-Path $env:LOCALAPPDATA "cursor-updater"),
        (Join-Path $env:LOCALAPPDATA "Programs\cursor"),
        (Join-Path $env:APPDATA "Cursor")
    )

    foreach ($path in $paths) {
        if (Test-Path $path) {
            $maxAttempts = 3
            $attempt = 1
            $removed = $false

            while (-not $removed -and $attempt -le $maxAttempts) {
                try {
                    Remove-Item -Recurse -Force $path
                    if (-not (Test-Path $path)) {
                        $removed = $true
                        Write-Host "Successfully removed ${path}"
                    }
                    else {
                        Write-Host "Try ${attempt} - Directory still exists: ${path}"
                    }
                }
                catch {
                    Write-Host "Try ${attempt} failed for ${path}"
                }
                
                if (-not $removed) {
                    $attempt++
                    Start-Sleep -Seconds 2
                }
            }

            if (-not $removed) {
                throw "Failed to remove directory after ${maxAttempts} attempts: ${path}"
            }
        }
    }
    Write-Host "Directory cleanup completed successfully`n"
}

function Remove-CursorRegistry {
    Write-Host "Step 3/6: Cleaning up Cursor registry..."
    $registryPaths = @(
        "HKCU:\Software\Cursor",
        "HKLM:\Software\Cursor",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Cursor"
    )

    foreach ($regPath in $registryPaths) {
        if (Test-Path $regPath) {
            $maxAttempts = 3
            $attempt = 1
            $removed = $false

            while (-not $removed -and $attempt -le $maxAttempts) {
                try {
                    Remove-Item -Recurse -Force $regPath
                    if (-not (Test-Path $regPath)) {
                        $removed = $true
                        Write-Host "Successfully removed registry key: ${regPath}"
                    }
                    else {
                        Write-Host "Try ${attempt} - Registry key still exists: ${regPath}"
                    }
                }
                catch {
                    Write-Host "Try ${attempt} failed for registry key: ${regPath}"
                }
                
                if (-not $removed) {
                    $attempt++
                    Start-Sleep -Seconds 2
                }
            }

            if (-not $removed) {
                throw "Failed to remove registry key after ${maxAttempts} attempts: ${regPath}"
            }
        }
    }
    Write-Host "Registry cleanup completed successfully`n"
}

function Install-Cursor {
    Write-Host "Step 4/6: Installing Cursor..."
    $installerPath = "./cursor.exe"
    
    if (-not (Test-Path $installerPath)) {
        throw "Cursor installer not found at: ${installerPath}"
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
    Write-Host "Step 5/6: Initializing Cursor..."
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

        if ($fileExists) {
            # If the storage file exists, stop the Cursor processes
            Stop-CursorProcesses
            Write-Host "Cursor processes stopped after initialization."
        }
        else {
            Write-Host "Storage file not found after waiting for $maxWaitTime seconds. Cursor app will remain running."
        }

        Write-Host "Cursor initialization step completed`n"
    }
    catch {
        throw "Failed to initialize Cursor: $($_.Exception.Message)"
    }
}

function Reset-CursorIds {
    Write-Host "Step 6/6: Resetting Cursor IDs..."
    $storagePath = Join-Path $env:APPDATA "Cursor\User\globalStorage\storage.json"
    
    # Create backup
    if (Test-Path $storagePath) {
        $backupPath = "${storagePath}.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item $storagePath $backupPath -Force
        Write-Host "Created backup at: ${backupPath}"
    }

    # Ensure directory exists
    $storageDir = Split-Path $storagePath -Parent
    if (-not (Test-Path $storageDir)) {
        New-Item -ItemType Directory -Path $storageDir -Force | Out-Null
    }

    # Generate new IDs
    $newIds = @{
        "telemetry.machineId" = (New-Guid).Guid -replace "-", ""
        "telemetry.macMachineId" = (New-Guid).Guid -replace "-", ""
        "telemetry.devDeviceId" = (New-Guid).Guid
        "telemetry.sqmId" = "{$((New-Guid).Guid)}"
    }

    # Save new IDs
    $newIds | ConvertTo-Json | Set-Content $storagePath -Force

    Write-Host "`n🎉 Device IDs have been successfully reset. The new device IDs are:`n"
    Write-Host "----------------------------------------"
    $newIds.GetEnumerator() | ForEach-Object {
        Write-Host "$($_.Key): $($_.Value)"
    }
    Write-Host "----------------------------------------`n"
}

# Main execution
try {
    Write-Host "Starting Cursor cleanup and installation process..."
    
    Stop-CursorProcesses
    Remove-CursorDirectories
    Remove-CursorRegistry
    Install-Cursor
    Initialize-CursorApp
    Reset-CursorIds
	py reset.py
    
    Write-Host "`n🎉 All steps completed successfully!"
}
catch {
    Write-Host "`nError: $($_.Exception.Message)"
    Write-Host "Process failed - please check the error message above"
    exit 1
}