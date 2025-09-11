# list of Locations
$OUThresholds = @{
    "OU=1,OU=Admins,DC=default,DC=ca" = 365,
    "OU=2,OU=Admins,DC=default,DC=ca" = 765
}    

foreach ($OU in $OUThresholds.Key) {
    $InactiveDays = $OUThresholds[$OU]
    $CutOffDate = (Get-Date).AddDays(-$InactiveDays)
    $inactiveOU = "OU=Inactive,$OU"
    Write-Host "Processing location $location"
    
    # Get disabled users NOT already in the Inactive sub OU filter based on defined thresholds
    $disabledUsers = Get-ADUser -SearchBase $baseOU -SearchScope OneLevel -Filter {Enabled -eq $false -and LastLogonDate -lt $CutOffDate} -Properties LastLogonDate
    
    foreach ($User in $disabledUsers) {
        Write-Host "Disabled user: $($User.SamAccountName) Moving to $inactiveOU and clearing ipPhone Attribute)
        # Move user to Inactive OU
        Move-ADObject -identity $($User.DistinguishedName) -TargetPath $inactiveOU
        # Clear ipPhone attribute
        Set-ADUser -Identity $($User.DistinguishedName) -Clear ipPhone
    }
}