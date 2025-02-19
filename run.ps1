# IMPORTANT: This script will severely restrict network functionality
# Run as Administrator
# Back up your network settings before running this

# 1. Change MAC address to a random value (requires restart to take effect)
function Set-RandomMAC {
    $adapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
    foreach ($adapter in $adapters) {
        $mac = [string]::Join('',(0..5 | ForEach-Object {"{0:X2}" -f (Get-Random -Minimum 0 -Maximum 255)}))
        $mac = $mac -replace '(..)','$1-'
        $mac = $mac.Substring(0,$mac.Length-1)
        # Ensure locally administered bit is set (second hex digit is 2,6,A,E)
        $secondChar = $mac.Substring(1,1)
        if ($secondChar -notmatch "[26AE]") {
            $newSecondChar = "2"
            $mac = $mac.Substring(0,1) + $newSecondChar + $mac.Substring(2)
        }
        Write-Host "Setting $($adapter.Name) MAC to $mac"
        Set-NetAdapter -Name $adapter.Name -MacAddress $mac -Confirm:$false
    }
}
Set-RandomMAC

# 2. Disable all network discovery protocols and services
# Network Discovery
netsh advfirewall firewall set rule group="Network Discovery" new enable=No
# File and Printer Sharing
Set-NetFirewallRule -DisplayGroup "File and Printer Sharing" -Enabled False
# Set network profile to public (most restrictive)
Set-NetConnectionProfile -NetworkCategory Public

# 3. Disable common network services that might respond to probes
$servicesToDisable = @(
    "SSDPSRV",        # SSDP Discovery
    "upnphost",       # UPnP Device Host
    "lltdsvc",        # Link-Layer Topology Discovery Mapper
    "WinRM",          # Windows Remote Management
    "RemoteRegistry", # Remote Registry
    "W32Time",        # Windows Time
    "lanmanserver",   # Server
    "lanmanworkstation", # Workstation
    "WSearch",        # Windows Search
    "iphlpsvc",       # IP Helper
    "LanmanWorkstation", # Workstation
    "Browser"         # Computer Browser
)

foreach ($service in $servicesToDisable) {
    if (Get-Service -Name $service -ErrorAction SilentlyContinue) {
        Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
        Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host "Disabled service: $service"
    }
}

# 4. Disable NetBIOS over TCP/IP on all interfaces
$adapters = Get-WmiObject Win32_NetworkAdapterConfiguration
foreach ($adapter in $adapters) {
    $adapter.SetTCPIPNetBIOS(2) | Out-Null
}

# 5. Disable IPv6 (which can leak identifying information)
Disable-NetAdapterBinding -Name "*" -ComponentID "ms_tcpip6"

# 6. Configure advanced TCP/IP settings to minimize fingerprinting
# Disable TCP Timestamps
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "Tcp1323Opts" -Value 0 -PropertyType DWORD -Force

# 7. Configure Windows Firewall to block almost everything
# Block all inbound connections
Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultInboundAction Block
# Allow established outbound connections
Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultOutboundAction Allow
# Turn on the firewall for all profiles
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True

# 8. Disable LLMNR (Link-Local Multicast Name Resolution)
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" -Value 0 -PropertyType DWORD -Force

# 9. Disable mDNS (Multicast DNS)
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMDNS" -Value 0 -PropertyType DWORD -Force

# 10. Configure DNS to use only external servers (avoiding local network DNS broadcasts)
$adapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
foreach ($adapter in $adapters) {
    # Use Cloudflare's DNS instead of local network DNS
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses "1.1.1.1","1.0.0.1"
}

# 11. Disable SMB (Server Message Block) protocol entirely
Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
Set-SmbServerConfiguration -EnableSMB2Protocol $false -Force

# 12. Disable WPAD (Web Proxy Auto-Discovery)
New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad" -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad" -Name "WpadOverride" -Value 1 -PropertyType DWORD -Force

# 13. Randomize host ID every time network is connected
$taskName = "RandomizeHostIdentifiers"
$taskAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -Command Set-RandomMAC"
$taskTrigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -RunLevel Highest -Force

Write-Host "`nSTEALTH CONFIGURATION COMPLETE" -ForegroundColor Green
Write-Host "`nWARNING: Your computer will have SEVERELY LIMITED network functionality." -ForegroundColor Yellow
Write-Host "A system restart is recommended for all changes to take effect." -ForegroundColor Yellow
Write-Host "`nTo restore normal network functionality, you will need to manually re-enable services and reset configurations." -ForegroundColor Red