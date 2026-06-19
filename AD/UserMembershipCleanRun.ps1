# ===== CONFIGURATION =====
$ReportPath = "C:\Temp\OU-GroupMembership-Report.csv"

# ===== SCRIPT =====
$Entries = Import-Csv $ReportPath

foreach ($Entry in $Entries) {

    Write-Host "Removing $($Entry.UserSamAccountName) from $($Entry.GroupName)"

    Remove-ADGroupMember `
        -Identity $Entry.GroupDN `
        -Members $Entry.UserDN `
        -Confirm:$false `
        -WhatIf
}