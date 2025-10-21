Import-Module ActiveDirectory

# Define your OUs
$OUs = @(
    "OU=Workstations,OU=Toronto,DC=corp,DC=example,DC=com",
    "OU=Workstations,OU=Vancouver,DC=corp,DC=example,DC=com",
    "OU=Workstations,OU=Montreal,DC=corp,DC=example,DC=com"
)

# Define cutoff (6 months ago)
$Cutoff = (Get-Date).AddMonths(-6)

# Collect results from all OUs
$Results = foreach ($OU in $OUs) {
    Get-ADComputer -SearchBase $OU -Filter * -Properties lastLogonTimestamp |
    Select-Object @{Name="OU";Expression={$OU}},
                  @{Name="Name";Expression={$_.Name}},
                  @{Name="LastLogonDate";Expression={[DateTime]::FromFileTime($_.lastLogonTimestamp)}}
}

# Filter computers logged in within last 6 months
$Filtered = $Results |
Where-Object { $_.LastLogonDate -ge $Cutoff } |
Sort-Object OU, @{Expression="LastLogonDate";Descending=$true}

# Display results
$Filtered | Format-Table -AutoSize

# Optional: export to CSV
# $Filtered | Export-Csv "C:\Reports\AD_LastLogon_6Months.csv" -NoTypeInformation