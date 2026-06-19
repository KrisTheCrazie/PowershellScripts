
# ===== CONFIGURATION =====
$OU = "OU=TargetUsers,OU=Corp,DC=example,DC=com"
$ReportPath = "C:\Temp\OU-GroupMembership-Report.csv"

# Email settings
$SmtpServer = "smtp.example.com"
$From       = "ad-reports@example.com"
$To         = "it-ops@example.com"
$Subject    = "AD Group Membership Report - OU Cleanup"
$Body       = "Attached is the group membership report for users in the specified OU. Domain Users has been excluded."

# ===== SCRIPT =====
$Results = @()

$Users = Get-ADUser -SearchBase $OU -Filter * -Properties MemberOf

foreach ($User in $Users) {

    if (-not $User.MemberOf) { continue }

    foreach ($GroupDN in $User.MemberOf) {

        $Group = Get-ADGroup $GroupDN

        if ($Group.Name -eq "Domain Users") { continue }

        $Results += [PSCustomObject]@{
            UserSamAccountName = $User.SamAccountName
            UserDN             = $User.DistinguishedName
            GroupName          = $Group.Name
            GroupDN            = $Group.DistinguishedName
        }
    }
}

# Export CSV
$Results | Export-Csv -Path $ReportPath -NoTypeInformation

# Send Email
Send-MailMessage `
    -From $From `
    -To $To `
    -Subject $Subject `
    -Body $Body `
    -SmtpServer $SmtpServer `
    -Attachments $ReportPath

Write-Host "Report generated and emailed successfully."