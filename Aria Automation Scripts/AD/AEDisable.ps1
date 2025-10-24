# ----------------------------
# Production Script: Disable Expired Accounts
# ----------------------------

# Import Active Directory module
Import-Module ActiveDirectory

# ----------------------------
# Configuration
# ----------------------------

$OU = "OU=Employees,DC=corp,DC=example,DC=com"

# SMTP settings
$SMTPServer = "smtp.example.com"
$From = "hr@example.com"

# Email subject
$SubjectLog  = "Monthly Disabled Accounts Report"

# Recipients for summary email
$AdminRecipients = @("admin1@example.com","admin2@example.com")

# Test Mode toggle
$TestMode = $true  # Set to $false for production

# Log file path
$Today = Get-Date
$LogFile = "C:\Temp\DisabledAccountsLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"

# Initialize log array
$Log = @()

# ----------------------------
# Process users
# ----------------------------

$Users = Get-ADUser -Filter * -SearchBase $OU -Properties AccountExpirationDate, Enabled, EmailAddress, Name

foreach ($User in $Users) {

    # Skip users without expiration date or already disabled
    if (-not $User.AccountExpirationDate) { continue }
    if (-not $User.Enabled) { continue }

    # Check if account is expired
    if ($User.AccountExpirationDate -le $Today) {

        # Disable account if not in test mode
        if (-not $TestMode) {
            Disable-ADAccount -Identity $User.DistinguishedName
            $Status = "Account Disabled"
        } else {
            $Status = "Test Mode - Would Disable"
        }

        # Log entry
        $LogEntry = [PSCustomObject]@{
            Name = $User.Name
            Email = $User.EmailAddress
            AccountExpirationDate = $User.AccountExpirationDate
            Status = $Status
        }

        $Log += $LogEntry
    }
}

# ----------------------------
# Export log and send summary
# ----------------------------

# Export log to CSV
$Log | Export-Csv -Path $LogFile -NoTypeInformation -Encoding UTF8

# Build multi-line summary email body
$BodyLog = @"
Hello Admin Team,

The monthly expired account check has completed. Below is the summary of accounts that were disabled:

Total accounts processed: $($Log.Count)

Sample of disabled accounts:
"@

# Include first few log entries
$Log | Select-Object -First 10 | ForEach-Object {
    $BodyLog += "`nName: $($_.Name) | Email: $($_.Email) | Expiration: $($_.AccountExpirationDate.ToShortDateString()) | Status: $($_.Status)"
}

$BodyLog += "`n`nPlease see the attached CSV for the full list."

# Send summary email
if ($TestMode) {
    # Send to yourself in test mode
    $TestRecipients = @("you@example.com")
    Send-MailMessage -To $TestRecipients `
                     -From $From `
                     -Subject "TEST - $SubjectLog" `
                     -Body $BodyLog `
                     -SmtpServer $SMTPServer `
                     -Attachments $LogFile
} else {
    Send-MailMessage -To $AdminRecipients `
                     -From $From `
                     -Subject $SubjectLog `
                     -Body $BodyLog `
                     -SmtpServer $SMTPServer `
                     -Attachments $LogFile
}
