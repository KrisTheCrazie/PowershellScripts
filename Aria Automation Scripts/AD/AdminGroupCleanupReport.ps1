mport-Module ActiveDirectory

# Configuration
$TargetOU = "OU=PrivilegedGroups,DC=yourdomain,DC=com"
$ReportPath = "C:\Reports\AdminGroupAudit_$(Get-Date -Format yyyyMMdd_HHmmss).csv"
$SmtpServer = "smtp.yourdomain.com"
$From       = "ad-audit@yourdomain.com"
$To         = "security@yourdomain.com"
$Subject    = "Admin Group Audit – Non a-/s-/e- Accounts Detected"

$Results = @()

# Get all groups in the OU
$Groups = Get-ADGroup -SearchBase $TargetOU -Filter *

foreach ($Group in $Groups) {
    try {
        $Members = Get-ADGroupMember -Identity $Group -Recursive | Where-Object { $_.objectClass -eq 'user' }

        foreach ($Member in $Members) {
            $User = Get-ADUser $Member.SamAccountName -Properties SamAccountName, DisplayName

            # Exclude a-, s-, e- accounts
            if ($User.SamAccountName -notmatch '^(a-|s-|e-)') {
                $Results += [PSCustomObject]@{
                    GroupName      = $Group.Name
                    SamAccountName = $User.SamAccountName
                    DisplayName    = $User.DisplayName
                }
            }
        }
    }
    catch {
        Write-Warning "Failed to process group: $($Group.Name)"
    }
}

# Export and email
$Results | Export-Csv -Path $ReportPath -NoTypeInformation

Send-MailMessage `
    -SmtpServer $SmtpServer `
    -From $From `
    -To $To `
    -Subject $Subject `
    -Body "Attached is the admin group audit report. Accounts starting with a-, s-, or e- are excluded." `
    -Attachments $ReportPath