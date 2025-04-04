# Elevate to Admin if not running as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "🚀 Starting Windows 11 Fix Script..." -ForegroundColor Cyan

# Kill high resource processes
Write-Host "🔍 Checking for high CPU/memory usage..."
$highUsage = Get-Process | Where-Object { $_.CPU -gt 80 -or $_.WS -gt 1GB }
if ($highUsage) {
    $highUsage | ForEach-Object {
        Write-Host "❌ Stopping $_.ProcessName (PID: $_.Id)..." -ForegroundColor Yellow
        Stop-Process -Id $_.Id -Force
    }
} else {
    Write-Host "✅ No high resource processes found."
}

# Run System File Checker (SFC)
Write-Host "🛠 Running System File Checker (sfc /scannow)..." -ForegroundColor Green
sfc /scannow

# Run DISM to repair Windows Image
Write-Host "🛠 Running DISM RestoreHealth..." -ForegroundColor Green
DISM /Online /Cleanup-Image /RestoreHealth

# Check disk for errors (Requires restart)
Write-Host "🔍 Checking disk for errors..." -ForegroundColor Green
chkdsk C: /f /r /x

# Disable Windows Search and SysMain (if causing issues)
Write-Host "⏳ Disabling unnecessary services (Windows Search & SysMain)..."
Stop-Service -Name "SysMain" -Force -ErrorAction SilentlyContinue
Set-Service -Name "SysMain" -StartupType Disabled
Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue
Set-Service -Name "WSearch" -StartupType Disabled

# Flush DNS and reset network
Write-Host "🌐 Flushing DNS and resetting network..."
ipconfig /flushdns
netsh winsock reset

# Check and update drivers
Write-Host "🔄 Checking for outdated drivers..."
pnputil /scan-devices

# Clear temporary files
Write-Host "🧹 Cleaning up temporary files..."
Get-ChildItem -Path "C:\Windows\Temp", "$env:TEMP" -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

# Check for Windows Updates
Write-Host "🔄 Checking for Windows Updates..."
Install-Module PSWindowsUpdate -Force -AllowClobber -Scope CurrentUser
Get-WindowsUpdate -AcceptAll -Install -AutoReboot

# Run Windows Defender Scan
Write-Host "🛡 Running Windows Defender quick scan..."
Start-MpScan -ScanType QuickScan

Write-Host "✅ All fixes applied! Rebooting now..." -ForegroundColor Green
Restart-Computer -Force
