param (
    [Parmeter (Mandatory = $true)]
    [string] $vraHostName,
    [Parmeter (Mandatory = $true)]
    [string] $vrauser,
    [Parmeter (Mandatory = $true)]
    [string] $vrapassword,
    [Parmeter (Mandatory = $true)]
    [string] $domain,
    [Parmeter (Mandatory = $true)]
    [string] $vcuser,
    [Parmeter (Mandatory = $true)]
    [string] $vcpassword,
    [Parmeter (Mandatory = $true)]
    [string] $SERVER,
    [Parmeter (Mandatory = $true)]
    [string] $vcFQDN  
)

# API Endpoints
$loginURL = "https://$vraHostName/csp/gateway/am/api/login"
$deploymentURL = "https://$vraHostName/deployment/api/deployments?expand=resources"

# Step 1: Authenticate and Get API Token
$loginBody = @{
    "username" = $vrauser
    "password" = $vrapassword
    "domain" = $domain
} | ConvertTo-Json -Depth 2

# Authenticate to get cspAuthToken
$loginresponse = Invoke-RestMethod -Uri $loginURL -Method Post -Body $loginBody -ContentType "application/json"
$cspAuthToken - $loginresponse.cspAuthToken

Write-Output "Access Token Retrieved Successfully."

# Step 2: Get Deployment ID from VM Name
$headers = @{ "Authorization" = "Bearer $cspAuthToken"; "Accept" = "application/json" }

# Get All deployments
$deployments = Invoke-RestMethod -Uri $deploymentURL -Method Get -Headers $headers

# Search for the deployment by VM name within the resources field
$deplyoment = $deployments.content | Foreach-Object {
    if ($_.resources) {
        $vmResource = $_.resources | Where-Object ( $_.properties.resourceName -eq $SERVER )
        if ($vmResource) {
            return $_ #return the deployment if the VM name matches
        }
    }
}

Write-Host "Deployment: $($deployment.id)"
Connect-VIServer -Server $vcFQDN -User $vcuser -password $vcpassword
Write-Host "Connected to vCenter: $vcFQDN"

$vm = Get-VM -Name $SERVER -ErrorAction SilentlyContinue

# Check for high Priority
$hasHighPri = $false
$Category = Get-TagCategory -Name "Priority"
$assignedTags = Get-Tagassignment -Entity $vm -Category $Category

foreach ($tag in $assignedTags) {
    if ($($tag.Tag.Name) -eq "Pri-High") {
        $hasHighPri = $true
    }
    else {
        $hasHighPri = $false
    }
}

# Safe Guard Check for High Priority
if ($hasHighPri) {
    Write-Host "VM $Server has High Priority. Server will not be deleted, to delete Priority needs to change."
    exit 1
} else {
    if ($deployment -ne $null) {
        # Step 3: Delete the Deployment
        $deploymentID = $($deployment.id)
        Write-Host "Found Deployment IDL $deploymentID for $SERVER"
        $deleteURL = "https://$vraHostName/deployment/api/deployments/$deploymentID"
        Invoke-RestMethod -Uri $deleteURL -Method Delete -Headers $headers
        Write-Host "Deployment $deploymentID for VM $SERVER has been deleted succesfully."
    }
    else {
        Write-Host "Deployment not found for VM: $SERVER. Proceeding to delete from vCenter."
        # Step 4: Ddelete from vCeneter if no deployment exists
        if ($vm -ne $null) {
            Write-Host "Found VM in vCenter: $SERVER. Powering off and deleting..."
            # Power Off the VM if it's running
            if ($vm.PowerState -eq "PoweredOn") {
                stop-VM -vm $vm -Confirm:$false
            }
            # Delete from vCenter
            Remove-VM -VM $vm -DeletePermanently -Confirm:$false
            Write-Host "VM $SERVER deleted succesfully from vCenter."
        }
        else {
            Write-Error "VM $SERVER not found in vCenter."
        }
    }
}
# Disconnect from vCenter
Disconnect-VIServer -Server $vcFQDN -Confirm:$false