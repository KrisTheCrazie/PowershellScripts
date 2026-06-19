Import-Module ActiveDirectory

# Configuration
$TargetOU = "OU=PrivilegedGroups,DC=yourdomain,DC=com"
$LogPath = "C:\Reports\AdminGroupRemediation_$(Get-Date -Format yyyyMMdd_HHmmss).csv"
$EmailResults = $true

$Log = @()

# Get all groups in the OU
$Groups = Get-ADGroup -SearchBase $TargetOU -Filter *

foreach ($Group in $Groups) {
    try {
        $Members = Get-ADGroupMember -Identity $Group -Recursive | Where-Object { $_.objectClass -eq 'user' }

        foreach ($Member in $Members) {
            $User = Get-ADUser $Member.SamAccountName -Properties SamAccountName

            # Exclude a-, s-, e- accounts
            if ($User.SamAccountName -notmatch '^(a-|s-|e-)') {

                Remove-ADGroupMember -Identity $Group -Members $User -Confirm:$false

                $Log += [PSCustomObject]@{
                    GroupName      = $Group.Name
                    SamAccountName = $User.SamAccountName
                    Action         = "Removed"
                    Timestamp      = Get-Date
                }
            }
        }
    }
    catch {
        Write-Warning "Failed remediation for group: $($Group.Name)"
    }
}

# Export log
$Log | Export-Csv -Path $LogPath -NoTypeInformation

# Optional email
if ($EmailResults) {
    Send-MailMessage `
        -SmtpServer $SmtpServer `
        -From $From `
        -To $To `
        -Subject "Admin Group Remediation Completed" `
        -Body "Attached is the remediation log. Accounts starting with a-, s-, or e- were excluded." `
        -Attachments $LogPath
}