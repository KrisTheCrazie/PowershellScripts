param (
    [Parmeter (Mandatory = $true)]
    [string] $psusername,
    [Parmeter (Mandatory = $true)]
    [string] $pspassword,
    [Parmeter (Mandatory = $true)]
    [string] $vcenteruser,
    [Parmeter (Mandatory = $true)]
    [string] $vcenterpassword,
    [Parmeter (Mandatory = $true)]
    [string] $pscommand
)

$vcFQDN = "vc.domain.local"
$pshost

# Connect to vCenter 
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
Write-Host "Connecting to $vcFQDN"
connect-viserver -Server $vcFQDN -User $vcenteruser -Password $vcenterpassword

# Invoke Command on powershell host
Invoke-VMScript -VM $pshost -ScriptText $ps_command -GuestUser $psusername -GuestPassword $pspassword

# Disconnect from vCenter
Write-Host "Disconnecting from vCenter"
disconnect-viserver * -Confirm:$false