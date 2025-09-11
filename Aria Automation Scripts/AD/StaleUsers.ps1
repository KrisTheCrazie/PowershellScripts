# Define your OU-specific thresholds (in days)
# Add as many OU's as required
$OUThresholds = @{
    "OU=1,DC=default,DC=ca" = 365,
    "OU=2,DC=default,DC=ca" = 730
}    


foreach ($OU in $OUThresholds.Key) {
    $InactiveDays = $OUThresholds[$OU]
    $CutoffDate = (Get-Date).AddDays(-$InactiveDays)
    $inactiveOU = "OU=Inactive,$OU"
    
    # Extract the OU Name
    $OUName = ($OU -split ',')[O] -replace '^OU=',''
    
    Write-Host "Checking OU: $OUName | Inactive > $InactiveDays days (Before $CutoffDate)"
    
    # Get Users who are enabled and haven't logged in since cutoff
    $Users = Get-ADUser =SearchBase $OU -Filter { Enabled -eq $true -and whenCreated -lt $CutoffDate } -Properties SamAccountName, whenCreated, lastLogonDate

    foreach ($User in $Users) {
        Write-Host = "Disabling $($User.SamAccountName) - Last login: $($User.LastLogonDate)"
        Disable-ADAccount -Identity $($User.SamAccountName)
        # Move to Inactive OU
        Move-ADObject -identity $($User.DistinguishedName) -TargetPath $inactiveOU
        # Clear ipPhone attribute
        Set-ADUser -Identity $($User.DistinguishedName) -Clear ipPhone
    }
    if ($User.Count -eq 0) {
        Write-Host "No Inactive Users found in $OU"
    }
}