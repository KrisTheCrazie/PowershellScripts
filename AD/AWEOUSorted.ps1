Import-Module ActiveDirectory

# Get all users in the domain with all properties
$users = Get-ADUser -Filter * -Properties *

# Filter users who are active and have no expiry
$usersWithoutExpiry = $users | Where-Object {
    ($_.Enabled -eq $true) -and ($_.accountExpires -eq 0 -or $_.accountExpires -eq 9223372036854775807)
}

# Create output with readable expiry and simplified OU
$usersProcessed = $usersWithoutExpiry | ForEach-Object {
    # Split DistinguishedName and find the second OU
    $ouParts = $_.DistinguishedName -split ','
    $secondOU = ($ouParts | Where-Object { $_ -like 'OU=*' })[1] -replace 'OU=', ''

    [PSCustomObject]@{
        Name = $_.Name
        SamAccountName = $_.SamAccountName
        OU = $secondOU
        AccountExpires = "Never"
    }
}

# Sort by OU
$usersProcessed = $usersProcessed | Sort-Object OU

# Display results
$usersProcessed | Format-Table -AutoSize

# Export to CSV
$usersProcessed | Export-Csv -Path "C:\ADUsersWithoutExpiry.csv" -NoTypeInformation