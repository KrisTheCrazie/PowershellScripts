param(
    [string]$OU = "OU=Users,DC=domain,DC=com",

    # Set to $true to apply expiry changes (1 year from today)
    [bool]$SetExpiryOneYear = $false
)

$ReportFile = "C:\Temp\AccountsWithoutExpiry.csv"

# Clear previous monthly report
if (Test-Path $ReportFile) {
    Remove-Item $ReportFile -Force
}

# Write CSV headers once
"Name,AccountName,CreatedDate,LastLoggedIn,ActionTaken" |
    Out-File -FilePath $ReportFile -Encoding UTF8

$Users = Get-ADUser `
    -SearchBase $OU `
    -Filter * `
    -Properties Name,SamAccountName,AccountExpires,LastLogonDate,whenCreated

foreach ($User in $Users) {

    # Only users with no expiry
    if ($User.AccountExpires -eq 0 -or
        $User.AccountExpires -eq 9223372036854775807) {

        # Format values
        $CreatedDate = $User.whenCreated.ToString("yyyy-MM-dd")

        $LastLogon = if ($User.LastLogonDate) {
            $User.LastLogonDate.ToString("yyyy-MM-dd")
        }
        else {
            "Never"
        }

        $ActionTaken = "Reported only"

        # Optional: set expiry to 1 year from today
        if ($SetExpiryOneYear) {

            $ExpiryDate = (Get-Date).AddYears(1)

            Set-ADAccountExpiration `
                -Identity $User.SamAccountName `
                -DateTime $ExpiryDate
            $ActionTaken = "Expiry set to $ExpiryValue"
        }

        # CSV-safe line formatting
        $Line = '"{0}","{1}","{2}","{3}","{4}","{5}"' -f `
            $User.Name,
            $User.SamAccountName,
            $CreatedDate,
            $LastLogon,
            $ActionTaken

        Add-Content -Path $ReportFile -Value $Line

        Write-Host "Processed: $($User.SamAccountName)"
    }
}