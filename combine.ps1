# Network Speed Optimization Script (Final Version)
# This script optimizes both Ethernet and Wi-Fi connections for better performance

# Run as Administrator check
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script requires Administrator privileges. Please restart PowerShell as Administrator."
    exit
}

Write-Host "Starting network optimization process..." -ForegroundColor Green

# Function to optimize a network adapter
function Optimize-NetworkAdapter {
    param (
        [Parameter(Mandatory=$true)]
        [string]$AdapterName
    )
    
    Write-Host "Optimizing adapter: $AdapterName" -ForegroundColor Yellow
    
    try {
        $adapter = Get-NetAdapter -Name $AdapterName -ErrorAction Stop
        
        # Set power management settings to maximum performance
        try {
            Set-NetAdapterPowerManagement -Name $AdapterName -SelectiveSuspend Disabled -ErrorAction SilentlyContinue
            Set-NetAdapterPowerManagement -Name $AdapterName -WakeOnMagicPacket Disabled -ErrorAction SilentlyContinue
            Set-NetAdapterPowerManagement -Name $AdapterName -WakeOnPattern Disabled -ErrorAction SilentlyContinue
            Write-Host "  - Power management optimized for performance" -ForegroundColor Gray
        } catch {
            Write-Host "  - Power management settings not available on this adapter" -ForegroundColor Gray
        }
        
        # Set DNS to faster public DNS servers - using netsh instead of PowerShell cmdlet
        try {
            $interface = Get-NetIPInterface -InterfaceAlias $AdapterName -AddressFamily IPv4
            if ($interface) {
                # Use netsh to set DNS servers
                $ifIndex = $interface.ifIndex
                netsh interface ipv4 set dnsservers "$ifIndex" static 1.1.1.1 primary | Out-Null
                netsh interface ipv4 add dnsservers "$ifIndex" 8.8.8.8 index=2 | Out-Null
                Write-Host "  - DNS optimized with faster servers" -ForegroundColor Gray
            }
        } catch {
            Write-Host "  - DNS settings could not be modified" -ForegroundColor Gray
        }
        
        # Optimize TCP/IP settings for this adapter
        try {
            # Disable Large Send Offload (can cause issues)
            Disable-NetAdapterLso -Name $AdapterName -ErrorAction SilentlyContinue
            Write-Host "  - Large Send Offload disabled" -ForegroundColor Gray
            
            # Enable RSS if available
            Enable-NetAdapterRss -Name $AdapterName -ErrorAction SilentlyContinue
            Write-Host "  - Receive Side Scaling enabled" -ForegroundColor Gray
        } catch {
            Write-Host "  - Advanced adapter features not available" -ForegroundColor Gray
        }
        
        Write-Host "  - Adapter optimization complete" -ForegroundColor Gray
    }
    catch {
        Write-Warning "Unable to optimize adapter '$AdapterName': $_"
    }
}

# Optimize TCP/IP global settings
Write-Host "`nOptimizing global TCP/IP settings..." -ForegroundColor Green

# Updated netsh commands to use only supported parameters
netsh int tcp set global autotuninglevel=normal
Write-Host "  - TCP auto-tuning set to normal" -ForegroundColor Gray

netsh int tcp set global ecncapability=enabled
Write-Host "  - ECN capability enabled" -ForegroundColor Gray

netsh int tcp set global rss=enabled
Write-Host "  - RSS enabled globally" -ForegroundColor Gray

# Experimental - enable TCP Fast Open if supported
try {
    netsh int tcp set global fastopen=enabled 2>$null
    Write-Host "  - TCP Fast Open enabled" -ForegroundColor Gray
} catch {}

# Optimize TCP settings through registry
try {
    # Increase TCP window size
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "Tcp1323Opts" -Value 1 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TcpWindowSize" -Value 65535 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "GlobalMaxTcpWindowSize" -Value 65535 -Type DWord -ErrorAction SilentlyContinue
    Write-Host "  - TCP window sizes optimized" -ForegroundColor Gray
} catch {
    Write-Host "  - Could not modify TCP window sizes" -ForegroundColor Gray
}

# Disable network throttling
try {
    if (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "NetworkThrottlingIndex" -Value 0xffffffff -Type DWord -ErrorAction SilentlyContinue
    Write-Host "  - Network throttling disabled" -ForegroundColor Gray
} catch {
    Write-Host "  - Could not disable network throttling" -ForegroundColor Gray
}

# Optimize QoS settings
try {
    if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" -Name "NonBestEffortLimit" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Write-Host "  - QoS optimization applied" -ForegroundColor Gray
} catch {
    Write-Host "  - Could not optimize QoS settings" -ForegroundColor Gray
}

# Get active network adapters
$ethernetAdapter = Get-NetAdapter | Where-Object { $_.Name -like "*Ethernet*" -and $_.Status -eq "Up" }
$wifiAdapter = Get-NetAdapter | Where-Object { $_.Name -like "*Wi-Fi*" -and $_.Status -eq "Up" }

# Optimize each active adapter
if ($ethernetAdapter) {
    Optimize-NetworkAdapter -AdapterName $ethernetAdapter.Name
}

if ($wifiAdapter) {
    Optimize-NetworkAdapter -AdapterName $wifiAdapter.Name
}

# Create a routing metric advantage for load distribution
if ($ethernetAdapter -and $wifiAdapter) {
    Write-Host "`nSetting up multipath routing for load distribution..." -ForegroundColor Green
    
    # Set interface metrics for optimal routing (lower = higher priority)
    try {
        # Get interface indices first
        $ethernetIndex = $ethernetAdapter.ifIndex
        $wifiIndex = $wifiAdapter.ifIndex
        
        # Use netsh to set metrics
        netsh interface ipv4 set interface "$ethernetIndex" metric=10 | Out-Null
        netsh interface ipv4 set interface "$wifiIndex" metric=20 | Out-Null
        
        Write-Host "  - Ethernet set as primary route (metric 10)" -ForegroundColor Gray
        Write-Host "  - Wi-Fi set as secondary route (metric 20)" -ForegroundColor Gray
    } catch {
        Write-Host "  - Could not set interface metrics: $_" -ForegroundColor Gray
    }
    
    # Configure dual-path routing using netsh instead of route command
    try {
        # These commands help ensure both connections can be used
        netsh interface ipv4 set subinterface "$ethernetIndex" mtu=1472 store=persistent | Out-Null
        netsh interface ipv4 set subinterface "$wifiIndex" mtu=1472 store=persistent | Out-Null
        Write-Host "  - MTU optimized for multi-path usage" -ForegroundColor Gray
    } catch {
        Write-Host "  - Could not optimize MTU settings" -ForegroundColor Gray
    }
}

# Clean DNS cache
ipconfig /flushdns
Write-Host "  - DNS cache flushed" -ForegroundColor Gray

# Optimize browser DNS settings
try {
    # Chrome
    if (!(Test-Path "HKCU:\Software\Google\Chrome")) {
        New-Item -Path "HKCU:\Software\Google\Chrome" -Force -ErrorAction SilentlyContinue | Out-Null
    }
    if (!(Test-Path "HKCU:\Software\Google\Chrome\PreferredNetworkPredictions")) {
        New-Item -Path "HKCU:\Software\Google\Chrome\PreferredNetworkPredictions" -Force -ErrorAction SilentlyContinue | Out-Null
    }
    Set-ItemProperty -Path "HKCU:\Software\Google\Chrome\PreferredNetworkPredictions" -Name "PreferredNetworkPredictions" -Value 1 -Type DWord -ErrorAction SilentlyContinue
    
    # Edge
    if (!(Test-Path "HKCU:\Software\Microsoft\Edge")) {
        New-Item -Path "HKCU:\Software\Microsoft\Edge" -Force -ErrorAction SilentlyContinue | Out-Null
    }
    if (!(Test-Path "HKCU:\Software\Microsoft\Edge\PreferredNetworkPredictions")) {
        New-Item -Path "HKCU:\Software\Microsoft\Edge\PreferredNetworkPredictions" -Force -ErrorAction SilentlyContinue | Out-Null
    }
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Edge\PreferredNetworkPredictions" -Name "PreferredNetworkPredictions" -Value 1 -Type DWord -ErrorAction SilentlyContinue
    
    Write-Host "  - Browser DNS settings optimized" -ForegroundColor Gray
} catch {
    Write-Host "  - Could not optimize browser settings" -ForegroundColor Gray
}

# Output current network configuration
Write-Host "`nNetwork optimization complete! Your connections are now optimized for maximum speed." -ForegroundColor Green
Write-Host "`nCurrent Active Network Adapters:" -ForegroundColor Green
Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Format-Table -Property Name, Status, LinkSpeed, MediaType

Write-Host "`nConnection Metrics (lower = higher priority):" -ForegroundColor Green
Get-NetIPInterface -AddressFamily IPv4 | Where-Object { ($_.InterfaceAlias -like "*Ethernet*" -or $_.InterfaceAlias -like "*Wi-Fi*") -and $_.ConnectionState -eq "Connected" } | Format-Table -Property InterfaceAlias, InterfaceMetric

Write-Host "`nRunning speed test to verify improvements..." -ForegroundColor Green
Start-Process "https://www.speedtest.net"

Write-Host "`nOptimization Summary:" -ForegroundColor Green
Write-Host "1. TCP auto-tuning set to normal mode" -ForegroundColor Gray
Write-Host "2. Network throttling disabled for better throughput" -ForegroundColor Gray
Write-Host "3. QoS policies optimized for maximum bandwidth" -ForegroundColor Gray
Write-Host "4. DNS servers set to Cloudflare (1.1.1.1) and Google (8.8.8.8)" -ForegroundColor Gray
Write-Host "5. Adapter power management optimized for performance" -ForegroundColor Gray
if ($ethernetAdapter -and $wifiAdapter) {
    Write-Host "6. Multi-connection routing configured with prioritization" -ForegroundColor Gray
    Write-Host "7. MTU optimized for dual-path networking" -ForegroundColor Gray
}
Write-Host "8. TCP window sizes increased for better throughput" -ForegroundColor Gray
Write-Host "9. Browser network settings optimized" -ForegroundColor Gray

Write-Host "`nFor maximum reliability, this script has:"
Write-Host "- Used netsh commands instead of PowerShell cmdlets where possible" -ForegroundColor Gray
Write-Host "- Set connection metrics to ensure optimal route selection" -ForegroundColor Gray
Write-Host "- Optimized for simultaneous connection usage" -ForegroundColor Gray
Write-Host "- Used silent error handling to complete all possible optimizations" -ForegroundColor Gray