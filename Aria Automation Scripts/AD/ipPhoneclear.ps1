# Get all OUs starting with "Inactive"
$inactiveOUs = Get-ADOrganizationalUnit -Filter 'Name -like "Inactive*"' -Properties DistinguishedName

# Loop through each inactive OUs
foreach ($ou in $inactiveOUs) {
    $ouDN = $($ou.DistinguishedName)
    Write-Host "Processing OU: $($ou.Name)"
    
    # Get All user accounts within the current OU and its sub-OUs
    $usersinOU = Get-ADUser -Filter * -SearchBase $ouDN -Properties ipPhone
    
    # Loop through each user
    foreach ($user in $usersinOU)
        $usersam = $($user.SamAccountName)
        $userdn = $($user.DistringuisedName)
        Write-Host "Checking ipPhone attribute for user: $userdn"
        
        # Check if IP attribute is already clear
        if ([string]::IsNullOrEmpty($($user.ipPhone))) {
            Write-Host "ipPhone attribute is already clear for user $usersam"
        } 
        else {
            Write-Host "Clearing ipPhone attribute for user: $usersam"
            # Clear the ipPhone attribute
            Set-ADUser -Identity $userDN -Clear ipPhone
        }
    }
}
Write-Host "Completed clearing ipPhone attribute for all users in inactive OUs."