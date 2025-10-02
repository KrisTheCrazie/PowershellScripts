# Get all OUs starting with "Inactive"
$inactiveOUs = Get-ADOrganizationalUnit -Filter 'Name -like "Inactive*"' -Properties DistinguishedName

# Loop through each inactive OUs
foreach ($ou in $inactiveOUs) {
    $ouDN = $($ou.DistinguishedName)
    $parentOU = ($ou.DistinguisedName -split ',')[2] -replace '^OU=', ''

    Write-Host " --- OU: $parentOU Processing --- "
    
    # Get All user accounts within the current OU and its sub-OUs
    $usersinOU = Get-ADUser -Filter {ipPhone -like "*"} -SearchBase $ouDN -Properties ipPhone
    
    # Loop through each user
    foreach ($user in $usersinOU) {
        $usersam = $($user.SamAccountName)
        $userdn = $($user.DistringuisedName)
        Write-Host "Clearing ipPhone attribute for user: $userSam"

        # Clear the ipPhone Attribute
        Set-ADUser -Identity $userDN -Clear ipPhone
    }
    Write-Host " --- OU: $parentOU Completed --- "
}

Write-Host "Completed clearing ipPhone attribute for all users in inactive OUs."