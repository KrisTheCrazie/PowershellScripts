# ----------------------------
# Production Script: Admin Notifications for Accounts Expiring Within 1 Month
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
$SubjectLog = "Accounts Expiring Within 1 Month - Admin Notification"

# Admin recipients
$AdminRecipients = @("admin1@example.com","admin2@example.com")

# Test Mode toggle
$TestMode = $true  # Set to $false for production

# Expiry threshold: 1 month from today
$Today = Get-Date
$ExpiryThreshold = $Today.AddMonths(1)

# Log file path (timestamped)
$LogFile = "C:\Temp\AdminAccountExpiryLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"

# Initialize log array
$Log = @()

# ----------------------------
# Process users
# ----------------------------

$Users = Get-ADUser -Filter * -SearchBase $OU -Properties EmailAddress, AccountExpirationDate, Enabled

foreach ($User in $Users) {

    # Skip users without email, disabled, or no expiration date
    if (-not $User.EmailAddress) { continue }
    if (-not $User.Enabled) { continue }
    if (-not $User.AccountExpirationDate) { continue }

    # Skip already expired accounts
    if ($User.AccountExpirationDate -le $Today) { continue }

    # Skip accounts not within 1 month
    if ($User.AccountExpirationDate -gt $ExpiryThreshold) { continue }

    # Create log entry for accounts within 1 month
    $LogEntry = [PSCustomObject]@{
        Name = $User.Name
        Email = $User.EmailAddress
        AccountExpirationDate = $User.AccountExpirationDate
        Status = "Account within 1 month of expiry"
    }

    # Add to log
    $Log += $LogEntry
}

# ----------------------------
# Export log and send summary to Admins
# ----------------------------

# Export log to CSV
$Log | Export-Csv -Path $LogFile -NoTypeInformation -Encoding UTF8

# Build multi-line email body for Admins
$BodyLog = @"
Hello Admin Team,

This is a notification of user accounts expiring within 1 month.

Total users expiring within 1 month: $($Log.Count)

Sample of accounts:
"@

# Include first few log entries for preview
$Log | Select-Object -First 10 | ForEach-Object {
    $BodyLog += "`nName: $($_.Name) | Email: $($_.Email) | Expiration: $($_.AccountExpirationDate.ToShortDateString())"
}

$BodyLog += "`n`nPlease see the attached CSV for the full list."

# Send email to Admins
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
