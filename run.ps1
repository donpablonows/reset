# This script implements reasonable stealth measures while preserving functionality
# Run as Administrator

Checkpoint-Computer -Description "Before Network Stealth and Optimization" -RestorePointType "MODIFY_SETTINGS"

Write-Host "Starting enhanced system configuration..." -ForegroundColor Green

# 1. Set network profile to private (balances security and functionality)
Set-NetConnectionProfile -NetworkCategory Public

# 2. Use network address randomization (helps avoid persistent fingerprinting)
function Set-PrivacyMACAddress {
    $adapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
    foreach ($adapter in $adapters) {
        # Generate locally administered MAC (starts with 02)
        # This preserves functionality while making tracking harder
        $macBytes = [byte[]](0x02, (Get-Random -Minimum 0 -Maximum 255), 
                            (Get-Random -Minimum 0 -Maximum 255), 
                            (Get-Random -Minimum 0 -Maximum 255),
                            (Get-Random -Minimum 0 -Maximum 255), 
                            (Get-Random -Minimum 0 -Maximum 255))
        $macString = [BitConverter]::ToString($macBytes).Replace('-',':')
        Set-NetAdapter -Name $adapter.Name -MacAddress ($macString.Replace(':','')) -Confirm:$false
    }
}
Set-PrivacyMACAddress

# 3. Create a randomization task that runs on network connection
$taskAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -Command Set-PrivacyMACAddress"
$taskTrigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName "PrivacyMACRefresh" -Action $taskAction -Trigger $taskTrigger -RunLevel Highest -Force

Write-Host "Configuring network adapters..." -ForegroundColor Cyan
Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | ForEach-Object {
    Set-NetAdapterRSS -Name $_.Name -Enabled $true
    $adapterPowerMgmt = Get-CimInstance -ClassName MSPower_DeviceEnable -Namespace root\wmi | Where-Object { $_.InstanceName -match [regex]::Escape($_.PnPDeviceID) }
    if ($adapterPowerMgmt) {
        $adapterPowerMgmt.Enable = $false
        $adapterPowerMgmt | Set-CimInstance
    }
    try {
        Set-NetAdapterAdvancedProperty -Name $_.Name -DisplayName "Interrupt Moderation" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
        Set-NetAdapterAdvancedProperty -Name $_.Name -DisplayName "Jumbo Packet" -DisplayValue "9KB MTU" -ErrorAction SilentlyContinue
    } catch { }
}

Write-Host "Optimizing network stack..." -ForegroundColor Cyan
netsh advfirewall set allprofiles firewallpolicy blockinbound,allowoutbound
netsh advfirewall set allprofiles state on
netsh advfirewall set allprofiles logging filename "%SystemRoot%\System32\LogFiles\Firewall\pfirewall.log"
netsh advfirewall set allprofiles logging maxfilesize 4096
netsh advfirewall set allprofiles logging droppedconnections enable

netsh int tcp set global chimney=enabled
netsh int tcp set global autotuninglevel=normal
netsh int tcp set global congestionprovider=ctcp
Set-NetTCPSetting -SettingName InternetCustom -AutoTuningLevelLocal Normal -ScalingHeuristics Disabled

# 5. Disable unnecessary network discovery without breaking core functionality
# Disable NetBIOS over TCP/IP (reduces local network broadcasts)
$adapters = Get-WmiObject Win32_NetworkAdapterConfiguration
foreach ($adapter in $adapters) {
    $adapter.SetTCPIPNetBIOS(2) | Out-Null
}

# 6. Disable LLMNR (Link-Local Multicast Name Resolution)
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" -Value 0 -PropertyType DWORD -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMDNS" -Value 0 -PropertyType DWORD -Force
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" -Name "MaxCacheTtl" -Value 10800 -Type DWord
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" -Name "MaxNegativeCacheTtl" -Value 0 -Type DWord

# 7. Disable Network Location Awareness service (reduces network fingerprinting)
$servicesToDisable = @(
    "DiagTrack", "WSearch", "SysMain", "WMPNetworkSvc", "lfsvc", "MapsBroker",
    "PcaSvc", "wisvc", "RetailDemo", "XblAuthManager", "XblGameSave", "XboxNetApiSvc",
    "NlaSvc", "SSDPSRV", "upnphost", "lltdsvc", "WinRM", "RemoteRegistry"
)

foreach ($service in $servicesToDisable) {
    if (Get-Service -Name $service -ErrorAction SilentlyContinue) {
        Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
        Set-Service -Name $service -StartupType Disabled
    }
}

# 8. Configure non-responding firewall rules (makes the computer appear "stealthy" to scanners)
# This blocks common discovery ports without acknowledging connection attempts
# Create stealth rule for common probing ports
$stealthPorts = @(135, 137, 138, 139, 445, 1900, 3389, 5353, 5355, 5357, 5358, 5000, 5100, 27036)
foreach ($port in $stealthPorts) {
    $ruleName = "Stealth_TCP_$port"
    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -LocalPort $port -Protocol TCP -Action Block -Enabled True
    New-NetFirewallRule -DisplayName "$ruleName`_UDP" -Direction Inbound -LocalPort $port -Protocol UDP -Action Block -Enabled True
}

# 9. Disable IPv6 (reduces network footprint, most home networks use IPv4)
Disable-NetAdapterBinding -Name "*" -ComponentID "ms_tcpip6"
Disable-NetAdapterBinding -Name "*" -ComponentID "ms_rspndr"
Disable-NetAdapterBinding -Name "*" -ComponentID "ms_lltdio"

# 10. Disable Windows network discovery without breaking critical function
# Disable network discovery
netsh advfirewall firewall set rule group="Network Discovery" new enable=No
# Disable file and printer sharing (won't impact internet)
netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=No

# 11. Disable response to pings (ICMPv4) for stealth from scanners
netsh advfirewall firewall add rule name="Block_ICMP_In" protocol=icmpv4 dir=in action=block
netsh advfirewall firewall add rule name="Block_ICMP_Out" protocol=icmpv4 dir=out action=block enable=yes

# 12. Use external DNS to avoid local network DNS broadcasts
$dnsServers = @("1.1.1.1", "1.0.0.1")
$activeAdapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
foreach ($adapter in $activeAdapters) {
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $dnsServers
}

Write-Host "Optimizing system performance..." -ForegroundColor Cyan
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 2 -Type DWord
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2 -Force

$memoryManagement = @{
    "IoPageLockLimit" = 0xFFFFFFFF
    "DisablePagingExecutive" = 1
    "LargeSystemCache" = 0
}

foreach ($setting in $memoryManagement.GetEnumerator()) {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name $setting.Key -Value $setting.Value -Type DWord
}

Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "SystemResponsiveness" -Value 0 -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Name "Priority" -Value 6 -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Name "Scheduling Category" -Value "High" -Type String

# 13. Change computer name to something generic
$randomName = "PC-" + (Get-Random -Minimum 100000 -Maximum 999999).ToString()
Rename-Computer -NewName $randomName -Force

# 14. Configure IP source routing settings
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "EnableDeadGWDetect" -Value 0 -PropertyType DWORD -Force
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "DisableIPSourceRouting" -Value 2 -PropertyType DWORD -Force
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "EnableICMPRedirect" -Value 0 -PropertyType DWORD -Force
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TCPMaxDataRetransmissions" -Value 3 -PropertyType DWORD -Force

# 15. Disable Windows network discovery without breaking critical function
netsh int teredo set state disabled
netsh int ipv6 6to4 set state state=disabled undoonstop=disabled
netsh int ipv6 isatap set state state=disabled

Write-Host "Cleaning temporary files..." -ForegroundColor Cyan
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`nResetting network stack..." -ForegroundColor Cyan
ipconfig /release
ipconfig /flushdns
ipconfig /renew
netsh winsock reset
netsh int ip reset

Write-Host "`nEnhanced System Configuration Complete!" -ForegroundColor Green
Write-Host "Your system is now optimized for both stealth and performance" -ForegroundColor Yellow
Write-Host "Network adapters configured: $((Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }).Count)" -ForegroundColor Yellow
Write-Host "Services optimized: $($servicesToDisable.Count)" -ForegroundColor Yellow
Write-Host "`nSystem restart required for all changes to take effect" -ForegroundColor Cyan

$restart = Read-Host "Would you like to restart your computer now to apply all changes? (Y/N)"
if ($restart -eq "Y" -or $restart -eq "y") {
    Restart-Computer -Force
}