# ----------------------------
# Production Script: Account Expiry Notifications
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

# Email subjects
$SubjectUser = "Account Renewal Form"
$SubjectLog  = "Monthly Account Expiry Report"

# Attachments to send to each user
$Attachments = @("C:\Path\To\Form1.pdf","C:\Path\To\Form2.pdf")

# Recipients of the summary log
$LogRecipients = @("manager@example.com","hrlead@example.com")

# Test Mode toggle
$TestMode = $true  # Set to $false for production

# Expiry threshold: 2 months from today
$Today = Get-Date
$ExpiryThreshold = $Today.AddMonths(2)

# Log file path (timestamped)
$LogFile = "C:\Temp\AccountExpiryLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"

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

    # Skip accounts not within 2 months
    if ($User.AccountExpirationDate -gt $ExpiryThreshold) { continue }

    # Create log entry for actionable user
    $LogEntry = [PSCustomObject]@{
        Name = $User.Name
        Email = $User.EmailAddress
        AccountExpirationDate = $User.AccountExpirationDate
        Status = ""
    }

    # Compose user email body
    $BodyUser = @"
Hello $($User.Name),

Your account is set to expire on $($User.AccountExpirationDate.ToShortDateString()).

Please complete the attached account renewal form and return it as instructed.

Thank you,
HR Team
"@

    # Send email if not in test mode
    if (-not $TestMode) {
        Send-MailMessage -To $User.EmailAddress `
                         -From $From `
                         -Subject $SubjectUser `
                         -Body $BodyUser `
                         -SmtpServer $SMTPServer `
                         -Attachments $Attachments
        $LogEntry.Status = "Email Sent"
    } else {
        $LogEntry.Status = "Test Mode - Email NOT Sent"
    }

    # Add entry to log
    $Log += $LogEntry
}

# ----------------------------
# Export log and send summary
# ----------------------------

# Export log to CSV
$Log | Export-Csv -Path $LogFile -NoTypeInformation -Encoding UTF8

# Build multi-line, friendly summary email body
$BodyLog = @"
Hello Team,

The monthly account expiry check has completed. Here’s a summary of actionable accounts:

Total users expiring within 2 months: $($Log.Count)

Sample of log:
"@

# Include first few log entries for preview
$Log | Select-Object -First 10 | ForEach-Object {
    $BodyLog += "`nName: $($_.Name) | Email: $($_.Email) | Expiration: $($_.AccountExpirationDate.ToShortDateString()) | Status: $($_.Status)"
}

$BodyLog += "`n`nPlease see the attached CSV for the full list."

# Send log email
if ($TestMode) {
    $TestRecipients = @("you@example.com")
    Send-MailMessage -To $TestRecipients `
                     -From $From `
                     -Subject "TEST - $SubjectLog" `
                     -Body $BodyLog `
                     -SmtpServer $SMTPServer `
                     -Attachments $LogFile
} else {
    Send-MailMessage -To $LogRecipients `
                     -From $From `
                     -Subject $SubjectLog `
                     -Body $BodyLog `
                     -SmtpServer $SMTPServer `
                     -Attachments $LogFile
}
