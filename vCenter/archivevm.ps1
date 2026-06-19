param (
    [Parmeter (Mandatory = $true)]
    [string] $vcFQDN,
    [Parmeter (Mandatory = $true)]
    [string] $vcenteruser,
    [Parmeter (Mandatory = $true)]
    [string] $vcenterpassword,
    [Parmeter (Mandatory = $true)]
    [string] $SERVER
)


# Connect to vCenter 
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
Write-Host "Connecting to $vcFQDN"
connect-viserver -Server $vcFQDN -User $vcenteruser -Password $vcenterpassword

# Get VM
$vmname = GET-VM -Name $SERVER

# Backup Tag Cleanup & Assignment
$backup-Category = Get-TagCategory -Name "Backup"
$assignedTags = Get-TagAssignment -Entity $vmname -Category $backupCategory

foreach ($tag in $assignedTags) {
    Write-Host "Removing Tag: $($tag.Tag.name)"
    Remove-TagAssignment -TagAssignment $tag -Confirm:$false
}

$newTag = Get-Tag -Name "Backup-Acrhive"
New-TagAssignment -Entity $vmname -Tag $newTag
Write-Host "Assigned Archive Backup Tag"

# Disconnect from vCenter
Write-Host "Disconnecting from vCenter"
disconnect-viserver * -Confirm:$false