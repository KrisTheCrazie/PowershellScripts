param (
    [Parmeter (Mandatory = $true)]
    [string] $dns_svr1,
    [Parmeter (Mandatory = $true)]
    [string] $dns_svr2,
    [Parmeter (Mandatory = $true)]
    [string] $dns_name,
    [Parmeter (Mandatory = $true)]
    [string] $psuser,
    [Parmeter (Mandatory = $true)]
    [string] $pspassword,
    [Parmeter (Mandatory = $true)]
    [string] $vcuser,
    [Parmeter (Mandatory = $true)]
    [string] $vcpassword,
    [Parmeter (Mandatory = $true)]
    [string] $dns_ipv4,
    [Parmeter (Mandatory = $true)]
    [string] $vcFQDN  
)
# DNS Trim
$dns_svr1 = $dns_svr1.Trim()
$dns_svr2 = $dns_svr2.Trim()
$dnszone = "default.ca"
$pshost = "PShost" # Replace with the VM name of your Powershell host

# Connect to vCenter
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
Write-Host "Connecting to $vcFQDN"
connect-viserver -Server $vcFQDN -User $vcenteruser -Password $vcenterpassword

# DNS Server Validation
# Validate the DNS Servers and utilize one that is online
# Define the Servers
$servers = @("dns_svr1","$dns_svr2")
# Function to check if a server is online
function Test-Server {
    param ([string]$server)
    try {
        if (test-Connection -ComputerName $server -Count 1 -Quiet) {
            return $Server
        }
        else {
            return $null
        }
    }
    catch {
        return $null # Prevent excessive error messages
    }
}
# Variable to store the online Server
$onlineServer = $null

# Check each server with minimal output
foreach ($server in $servers) {
    if (Test-Server -Server $server) {
        $onlineServer = $server
        break # Stop once a online server if found
    }
}
# Run the DNS script
Write-Host "Running DNS Server Validation"
Write-Host "DNS Server Validated: $onlineServer"
$dnssvr = $onlineServer

# Powershell script to create DNS records
$ps_adddns = @"
    Add-DNSServerResourceRecord -A -ComputerName $dnssvr -ZoneName $dnszone -Name $dns_name -IPv4Address $dns_ipv4 -AllowUpdateAny -TimeToLive 3600 -Verbose
"@

# DNS Record Management Runs
if ($dnssvr -eq $null) {
    Write-Host "No DNS Server Available"
    exit 1
}
else {
    Write-Host "Creating A record for $dns_name with $dns_ipv4"
    Write-Host "DNS: $dnssvr"
    get-vm $pshost
    Invoke-VMScript -VM $pshost -ScriptText $ps_adddns -GuestUser $psuser -GuestPassword $pspassword
}
# Disconnect from vCenter
Write-Host "Disconnecting from vCenter"
disconnect-viserver * -Confirm:$false
    