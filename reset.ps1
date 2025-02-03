# Ensure script runs with elevated privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "Please run this script as Administrator!"
    exit
}

# Generate Random Values
$NewComputerName = "PC-" + (Get-Random -Minimum 1000 -Maximum 9999)
$RandomMAC = ((1..6) | ForEach-Object { "{0:X2}" -f (Get-Random -Minimum 0 -Maximum 255) }) -join '-'
$RandomIP = "192.168.1." + (Get-Random -Minimum 100 -Maximum 254)

Write-Host "Changing Computer Name to: $NewComputerName" -ForegroundColor Cyan
Rename-Computer -NewName $NewComputerName -Force

# Pause to allow name change and restart prompt
Start-Sleep -Seconds 10

# Get Network Adapter
$NetworkAdapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
if (-not $NetworkAdapter) {
    Write-Error "No active network adapter found!"
    exit
}

# Change MAC Address
Write-Host "Changing MAC Address to: $RandomMAC" -ForegroundColor Cyan
$NetworkAdapterName = $NetworkAdapter.Name
$RegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}\$(($NetworkAdapter.PNPDeviceID -split '\\')[-1])"
Set-ItemProperty -Path $RegistryPath -Name "NetworkAddress" -Value $RandomMAC

# Restart Network Adapter
Write-Host "Restarting Network Adapter: $NetworkAdapterName" -ForegroundColor Cyan
Disable-NetAdapter -Name $NetworkAdapterName -Confirm:$false
Enable-NetAdapter -Name $NetworkAdapterName -Confirm:$false

# Change IP Address
Write-Host "Changing IP Address to: $RandomIP" -ForegroundColor Cyan
New-NetIPAddress -InterfaceAlias $NetworkAdapterName -IPAddress $RandomIP -PrefixLength 24 -DefaultGateway "192.168.1.1"

# Reset Network Stack
Write-Host "Resetting Network Stack" -ForegroundColor Cyan
netsh winsock reset
netsh int ip reset
ipconfig /flushdns

Write-Host "Restarting the computer to apply all changes..." -ForegroundColor Green
Restart-Computer -Force
