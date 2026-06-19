param (
    [Parmeter (Mandatory = $true)]
    [string] $vcFQDN,
    [Parmeter (Mandatory = $true)]
    [string] $vcenteruser,
    [Parmeter (Mandatory = $true)]
    [string] $vcenterpassword,
    [Parmeter (Mandatory = $true)]
    [string] $backup,
    [Parmeter (Mandatory = $true)]
    [string] $Environment,
    [Parmeter (Mandatory = $true)]
    [string] $Priority,
    [Parmeter (Mandatory = $true)]
    [string] $AppType,
    [Parmeter (Mandatory = $true)]
    [string] $aduser,
    [Parmeter (Mandatory = $true)]
    [string] $apptier,
    [Parmeter (Mandatory = $true)]
    [string] $aduser,
    [Parmeter (Mandatory = $true)]
    [string] $SERVER  
)

# Additional Variables
$categoryName = "Manager"

# Format the Tags
$backuptag = "Backup-$backup"
$pritag = "Pri-$priority"
$envtag = "Env-$Environment"
$apptypetag = "AppType-$AppType"
$ostag = "OS-$OS"
$apptiertag = "App-$apptier"

# Connect to vCenter 
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
Write-Host "Connecting to $vcFQDN"
connect-viserver -Server $vcFQDN -User $vcenteruser -Password $vcenterpassword

# Formatting the OPI Tag
$user = Get-ADUSer -Identity $aduser -Properties GivenName, Surname -Credential $Credential
$firstname = $user.GivenName
$lastname = ($user.Surname -split " ")[0]
$formatted = "OPI-$firstname-$lastname"
Write-Host "Formatted User Tag: $formatted"

$tag = Get-Tag -Name $formatted -ErrorAction SilentlyContinue

if ($tag) {
    Write-Host "Assigning OPI $formatted"
    New-TagAssignment -Tag $formatted -Entity $SERVER
}
else {
    Write-Host "Tag $formatted does not exist creating the tag"
    New-Tag -Name $formatted -Category $categoryName -Description "Tag created by VCF Automation contact information needs to be added"
    Write-Host "Tag has been created"
    Write-Host "Asssigning Manager $formatted"
    New-TagAssignment -Tag $formatted -Entity $server

# Assign Additional Required Tags
Write-Host "Assigning Backup Tag"
New-TagAssignment -Tag $backuptag -Entity $server
Write-Host "Assigning Environment Tag"
New-TagAssignment -Tag $envtag -Entity $server
Write-Host "Assigning Priority Tag"
New-TagAssignment -Tag $pritag -Entity $server
Write-Host "Assigning App Type Tag"
New-TagAssignment -Tag $ostag -Entity $server
Write-Host "Assigning OS Tag"
New-TagAssignment -Tag $backuptag -Entity $server
Write-Host "Assigning App Tier Tag"
New-TagAssignment -Tag $bapptiertag -Entity $server

# Disconnect from vCenter
Write-Host "Disconnecting from vCenter"
disconnect-viserver * -Confirm:$false