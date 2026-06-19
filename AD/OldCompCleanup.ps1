Import-Module ActiveDirectory

# Define your OUs
$OUs = @(
    "OU=Workstations,OU=Toronto,DC=corp,DC=example,DC=com",
    "OU=Workstations,OU=Vancouver,DC=corp,DC=example,DC=com",
    "OU=Workstations,OU=Montreal,DC=corp,DC=example,DC=com"
)

# Define cutoffs
$LastLogonCutoff = (Get-Date).AddYears(-1)      # Last login older than 6 months
$CreationCutoff = (Get-Date).AddYears(-1)        # Created more than 1 year ago

# Test flag: $true = simulate, $false = actually delete
$TestMode = $true

# Collect results from all OUs
$Results = foreach ($OU in $OUs) {
    Get-ADComputer -SearchBase $OU -Filter * -Properties lastLogonTimestamp, whenCreated |
    Select-Object @{Name="OU";Expression={$OU}},
                  @{Name="Name";Expression={$_.Name}},
                  @{Name="LastLogonDate";Expression={if ($_.lastLogonTimestamp) {[DateTime]::FromFileTime($_.lastLogonTimestamp)} else {$null}}},
                  @{Name="CreationDate";Expression={$_.whenCreated}}
}

# Filter computers:
# 1. Never logged in & older than 1 year
# 2. Or last logged in more than 1 year ago
$Filtered = $Results |
Where-Object {
    (-not $_.LastLogonDate -and $_.CreationDate -lt $CreationCutoff) -or
    ($_.LastLogonDate -and $_.LastLogonDate -lt $LastLogonCutoff)
} |
Sort-Object OU, @{Expression="LastLogonDate";Descending=$true}

# Display results
$Filtered | Format-Table -AutoSize

# Optional: Export report
# $Filtered | Export-Csv "C:\Reports\AD_LastLogon_6Months.csv" -NoTypeInformation

# Delete computers if not in Test mode
if (-not $TestMode) {
    foreach ($comp in $Filtered) {
        Write-Host "Deleting computer: $($comp.Name) from OU: $($comp.OU)"
        Remove-ADComputer -Identity $comp.Name -Confirm:$false
    }
} else {
    Write-Host "Test mode is ON. No computers will be deleted."
}
