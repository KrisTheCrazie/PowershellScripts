Import-Module ActiveDirectory

# Define your target OU
$OU = "OU=Users,OU=Toronto,DC=corp,DC=example,DC=com"

# Get all users in that OU with all properties
$users = Get-ADUser -SearchBase $OU -Filter * -Properties *

# Filter users who have no expiry (accountExpires = 0 or 9223372036854775807)
$usersWithoutExpiry = $users | Where-Object {
    $_.accountExpires -eq 0 -or $_.accountExpires -eq 9223372036854775807
}

# Create output with readable expiry
$usersProcessed = $usersWithoutExpiry | ForEach-Object {
    [PSCustomObject]@{
        Name = $_.Name
        SamAccountName = $_.SamAccountName
        AccountExpires = "Never"
    }
}

# Display results
$usersProcessed | Format-Table -AutoSize

# Export to CSV
$usersProcessed | Export-Csv -Path "C:\ADUsersWithoutExpiry.csv" -NoTypeInformation
