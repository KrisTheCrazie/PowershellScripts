# list of Locations and inactivity thresholds (in days)
$OUThresholds = @{
    "OU=1,OU=Admins,DC=default,DC=ca" = 365
    "OU=2,OU=Admins,DC=default,DC=ca" = 765
}

foreach ($OU in $OUThresholds.Keys) {

    $BaseThreshold = $OUThresholds[$OU]
    $DeleteThreshold = $BaseThreshold * 2
    $CutOffDate = (Get-Date).AddDays(-$DeleteThreshold)

    $OUName = ($OU -split ',')[1] -replace '^OU=',''

    Write-Host "========================================="
    Write-Host "Processing OU: $OUName"
    Write-Host "Base Threshold: $BaseThreshold days"
    Write-Host "Delete Threshold (2x): $DeleteThreshold days"
    Write-Host "Cutoff Date: $CutOffDate"
    Write-Host "========================================="

    # Get disabled users inactive longer than 2x threshold
    $staleUsers = Get-ADUser -SearchBase $OU -SearchScope OneLevel -Filter {Enabled -eq $false -and LastLogonDate -lt $CutOffDate} -Properties LastLogonDate

    foreach ($User in $staleUsers) {
        Write-Host "DELETING user: $($User.DistinguishedName), LastLogonDate  : $($User.LastLogonDate)"

        # OPTIONAL: export to CSV for audit before deletion
        # $User | Select SamAccountName, LastLogonDate, DistinguishedName |
        #     Export-Csv "C:\Temp\DeletedUsers.csv" -Append -NoTypeInformation

        # Delete the AD object
        Remove-ADUser -Identity $User.DistinguishedName -Confirm:$true
            # -WhatIf   # <--- Uncomment first to test safely
    }
}