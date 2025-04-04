# Fix Bluetooth Audio Skipping
# Run as Administrator

Write-Host "Fixing Bluetooth Audio Issues..." -ForegroundColor Cyan

# Restart Bluetooth Service
Write-Host "Restarting Bluetooth Services..." -ForegroundColor Yellow
Get-Service -Name bthserv | Restart-Service -Force
Start-Sleep -Seconds 3

# Disable Bluetooth Power Management (Prevents Windows from reducing Bluetooth performance)
Write-Host "Disabling Bluetooth Power Management..." -ForegroundColor Yellow
$bluetoothDevices = Get-PnpDevice | Where-Object { $_.FriendlyName -match "Bluetooth" }

foreach ($device in $bluetoothDevices) {
    $deviceID = $device.InstanceId
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$deviceID\Device Parameters"
    
    if (Test-Path $regPath) {
        Set-ItemProperty -Path $regPath -Name "EnhancedPowerManagementEnabled" -Value 0
    }
}

# Ensure High-Performance Power Plan is Active
Write-Host "Setting High-Performance Power Plan..." -ForegroundColor Yellow
powercfg /S SCHEME_MIN

# Increase Audio Buffer Size for Bluetooth
Write-Host "Increasing Audio Buffer Size..." -ForegroundColor Yellow
$regPath = "HKLM:\SOFTWARE\Microsoft\Bluetooth\Audio\AVRCP\CT"
if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
Set-ItemProperty -Path $regPath -Name "MetadataTimeout" -Value 5000

# Restart Audio Service
Write-Host "Restarting Audio Service..." -ForegroundColor Yellow
Restart-Service -Name "Audiosrv" -Force
Start-Sleep -Seconds 2

Write-Host "Bluetooth Audio Fix Applied! Try playing audio again." -ForegroundColor Green
