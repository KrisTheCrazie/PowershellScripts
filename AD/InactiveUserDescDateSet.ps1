# Target OU
$OU = "OU=YourTargetOU,DC=domain,DC=com"

# Regex to match our specific date format at the start (e.g., 2026-01-13 or 2026-01-13 HH:mm:ss)
$DatePattern = '^\d{4}-\d{2}-\d{2}'

# Current date for the script run
$ScriptRunDate = Get-Date -Format "yyyy-MM-dd"

# Get all users in the OU
$Users = Get-ADUser -Filter * -SearchBase $OU -Properties LastLogonDate, Description

foreach ($User in $Users) {

    # Skip if Description already starts with a date
    if ($User.Description -match $DatePattern) {
        Write-Host "Skipping $($User.SamAccountName) - description already starts with a date"
        continue
    }

    # Determine last logon
    if ($User.LastLogonDate) {
        $HumanReadable = $User.LastLogonDate.ToString("yyyy-MM-dd HH:mm:ss")
    } else {
        $HumanReadable = "Never Logged On - $ScriptRunDate"
    }

    # Update Description
    Set-ADUser -Identity $User.SamAccountName -Description $HumanReadable

    Write-Host "Updated $($User.SamAccountName) description to '$HumanReadable'"
}