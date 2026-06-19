# Define your OU-specific thresholds (in days)
# Add as many OU's as required
$OUThresholds = @{
    "OU=1,OU=Admins,DC=default,DC=ca" = 30,
    "OU=2,OU=Admins,DC=default,DC=ca" = 30
}    
$logpath = "C:\Temp\InactiveAdmin.log"
if (-not (Test-Path "C:\Temp")) {
    New-Item -Path "C:\Temp" -ItemType Directory | Out-Null
}

# Clear the Log content at the beginning
Clear-Content -Path $logpath -ErrorAction SilentlyContinue
Add-Content -Path $logpath -Value "=== Stale Admin Cleanup Started - $(Get-Date) ===`r`n"

foreach ($OU in $OUThresholds.Key) {
    $InactiveDays = $OUThresholds[$OU]
    $CutoffDate = (Get-Date).AddDays(-$InactiveDays)
    
    # Extract the OU Name
    $OUName = ($OU -split ',')[O] -replace '^OU=',''
    
    $sectionHeader = @(
        "==================================================",
        "OU: $OUName",
        "Threshold $InactiveDays days (Before $CutoffDate)",
        "=================================================="
    )
    
    $sectionHeaderText = $sectionHeader -join "`r`n"
    Write-Host $sectionHeaderText
    Add-Content -Path $logpath -Value "$sectionHeaderText`r`n"
    
    # Get Users who are enabled and haven't logged in since cutoff
    $Users = Get-ADUser =SearchBase $OU -Filter { Enabled -eq $true -and whenCreated -lt $CutoffDate } -Properties SamAccountName, whenCreated, lastLogonDate
    if ($Users) {
        foreach ($User in $Users) {
            # Searching for users that have been inactive based on the threshold that has been set
            if ($User.LastLogonDate -ne $null -and $User.LastLogonDate -lt $CutoffDate) {
                $line = "Disabling $($User.SamAccountName) - Last login: $($User.LastLogonDate)"
                Disable-ADAccount -Identity $($User.SamAccountName)
                Write-Host $line
                Add-Content -Path $logpath -Value "$line`r`n"
            }
            # Searching for users that have been created but never logged in based on threshold
            elseif ($User.LastLogonDate -eq $null -and $User.whenCreated -lt $CutoffDate) {
                $line = "Disabling $($User.SamAccountName) - Created and not logged in"
                Disable-ADAccount -Identity $($User.SamAccountName)
                Write-Host $line
                Add-Content -Path $logpath -Value "$line`r`n"
            }
        }
    }
    else {
        $line2 = "No inactive users found"
        Write-Host $line2
        Add-Content -Path $logpath -Value "$line2`r`n"
    }
}

Add-Content -Path $logpath -Value "`r`n=== Script Complete at $(Get-Date) ===`r`n"

# Email Content
$from = "automation@default.ca"
$to = @("user1@default.ca","user2@default.ca")
$subject = "Stale Admin Cleanup - $(Get-Date -Format 'yyyy-MM-dd')"
$smtp = "smtp.default.ca"

$body = @'
Hello,

This is an automated report from the Active Directory Stale User Cleanup Script.

The following admin accounts were automatically disabled due to inactivity exceeding the defined thresholds for their respective Organizational Units.

Please review the full details attached.

Thank you,
VCF Automation
'@

# Send the Email
Send-MailMessage -From $from -To $to -Subject $subject -Body $body -smtpserver $smtp -Attachments $logpath