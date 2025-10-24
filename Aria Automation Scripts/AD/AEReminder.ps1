# Import the Active Directory module
Import-Module ActiveDirectory

# ----------------------------
# Configuration
# ----------------------------

# Target OU
$OU = "OU=Employees,DC=corp,DC=example,DC=com"

# SMTP settings
$SMTPServer = "smtp.example.com"
$From = "hr@example.com"

# Subject lines
$SubjectUser = "Account Renewal Form"
$SubjectLog  = "Monthly Account Expiry Report"

# Attachments to send to each user
$Attachments = @("C:\Path\To\Form1.pdf","C:\Path\To\Form2.pdf")

# Recipients of the summary log
$LogRecipients = @("manager@example.com","hrlead@example.com")

# Check for accounts expiring within this many months
$ExpiryThreshold = (Get-Date).AddMonths(2)
$Today = Get-Date

# Log file path (timestamped)
$LogFile = "C:\Temp\AccountExpiryLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"

# Initialize log array
$Log = @()

# ----------------------------
# Process users
# ----------------------------

$Users = Get-ADUser -Filter * -SearchBase $OU -Properties EmailAddress, AccountExpirationDate, Enabled

foreach ($User in $Users) {

    # Prepare log entry
    $LogEntry = [PSCustomObject]@{
        Name = $User.Name
        Email = $User.EmailAddress
        AccountExpirationDate = $User.AccountExpirationDate
        Status = ""
    }

    # Skip users without email or disabled accounts
    if (-not $User.EmailAddress) {
        $LogEntry.Status = "Skipped - No Email"
        $Log += $LogEntry
        continue
    }
    if (-not $User.Enabled) {
        $LogEntry.Status = "Skipped - Disabled"
        $Log += $LogEntry
        continue
    }

    # Skip users without expiration date
    if (-not $User.AccountExpirationDate) {
        $LogEntry.Status = "Skipped - No Expiration Date"
        $Log += $LogEntry
        continue
    }

    # Skip already expired accounts
    if ($User.AccountExpirationDate -le $Today) {
        $LogEntry.Status = "Skipped - Already Expired"
        $Log += $LogEntry
        continue
    }

    # If account expires within 2 months, send email
    if ($User.AccountExpirationDate -le $ExpiryThreshold) {

        $BodyUser = @"
Hello $($User.Name),

Your account is set to expire on $($User.AccountExpirationDate.ToShortDateString()).

Please complete the attached account renewal form and return it as instructed.

Thank you,
HR Team
"@

        Send-MailMessage -To $User.EmailAddress `
                         -From $From `
                         -Subject $SubjectUser `
                         -Body $BodyUser `
                         -SmtpServer $SMTPServer `
                         -Attachments $Attachments

        $LogEntry.Status = "Email Sent"

    } else {
        $LogEntry.Status = "Skipped - Not within 2 months"
    }

    # Add log entry
    $Log += $LogEntry
}

# ----------------------------
# Export log and send summary
# ----------------------------

# Export log to CSV
$Log | Export-Csv -Path $LogFile -NoTypeInformation -Encoding UTF8

# Compose multi-line email body for log summary
$BodyLog = @"
Hello Team,

The monthly account expiry check has completed. Here’s a summary:

Total users processed: $($Log.Count)
Emails sent: $((($Log | Where-Object { $_.Status -eq 'Email Sent' }).Count))
Accounts skipped: $((($Log | Where-Object { $_.Status -ne 'Email Sent' }).Count))

Please find the detailed report attached, which includes information about each user and the reason if an email was not sent.

Thank you,
IT / HR Team
"@

# Send log summary email
Send-MailMessage -To $LogRecipients `
                 -From $From `
                 -Subject $SubjectLog `
                 -Body $BodyLog `
                 -SmtpServer $SMTPServer `
                 -Attachments $LogFile