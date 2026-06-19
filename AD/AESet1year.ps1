param(
    [Parameter(Mandatory=$true)]
    [string]$OU,

    [int]$YearsToAdd = 1,

    [switch]$TestMode
)

# --- Define dynamic log folder ---
$DATE = (Get-Date).ToString("yyyyMMdd")
$LogFolder = "C:\Temp\ExpirySet-$DATE"

if (-not (Test-Path $LogFolder)) {
    try {
        New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
    } catch {
        Write-Error "Failed to create log folder '$LogFolder'. $_"
        exit 1
    }
}

# --- Prepare log paths ---
$timestamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
$csvLog = Join-Path $LogFolder "ADExpiryChanges_$timestamp.csv"
$textLog = Join-Path $LogFolder "ADExpiryChanges_$timestamp.txt"

$NewExpiry = (Get-Date).AddYears($YearsToAdd).Date

# --- Import AD module ---
try {
    Import-Module ActiveDirectory -ErrorAction Stop
} catch {
    Write-Error "ActiveDirectory module not found. Install RSAT or run on a DC."
    exit 1
}

# --- Gather users ---
Write-Output "Querying users in OU: $OU ..."
try {
    $users = Get-ADUser -Filter * -SearchBase $OU -Properties AccountExpirationDate, Name, SamAccountName, DistinguishedName
} catch {
    Write-Error "Failed to query AD: $_"
    exit 1
}

$targetUsers = $users | Where-Object { -not $_.AccountExpirationDate }

if (-not $targetUsers) {
    $msg = "No users without an expiration date found in OU: $OU"
    Write-Output $msg
    $msg | Out-File -FilePath $textLog -Encoding UTF8
    exit 0
}

Write-Output "Found $($targetUsers.Count) user(s) with no expiration date."

# --- Process users ---
$results = @()

foreach ($u in $targetUsers) {
    $entry = [PSCustomObject]@{
        Timestamp         = (Get-Date).ToString("s")
        SamAccountName    = $u.SamAccountName
        Name              = $u.Name
        DistinguishedName = $u.DistinguishedName
        CurrentExpiry     = $u.AccountExpirationDate
        NewExpiry         = $NewExpiry
        Action            = ""
        Message           = ""
    }

    if ($TestMode) {
        $entry.Action = "Planned"
        $entry.Message = "TestMode - no change performed"
        Write-Output "[PLANNED] $($u.SamAccountName) -> expiry $($NewExpiry.ToShortDateString())"
    } else {
        try {
            Set-ADUser -Identity $u -AccountExpirationDate $NewExpiry -ErrorAction Stop
            $entry.Action = "Updated"
            $entry.Message = "Expiration set successfully"
            Write-Output "[UPDATED] $($u.SamAccountName) -> expiry $($NewExpiry.ToShortDateString())"
        } catch {
            $entry.Action = "Failed"
            $entry.Message = $_.Exception.Message
            Write-Warning "[FAILED] $($u.SamAccountName) - $_"
        }
    }

    $results += $entry
}

# --- Export logs ---
try {
    $results | Export-Csv -Path $csvLog -NoTypeInformation -Encoding UTF8

    # Plain-text summary
    $summary = @()
    $summary += "AD Expiry Update Run: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $summary += "Target OU: $OU"
    $summary += "Mode: $([bool]$TestMode.IsPresent ? 'Test (no changes)' : 'Execute (changes applied)')"
    $summary += "New Expiry Date: $NewExpiry"
    $summary += "Total Users Processed: $($results.Count)"
    $summary += "Planned: $($results | Where-Object {$_.Action -eq 'Planned'} | Measure-Object).Count"
    $summary += "Updated: $($results | Where-Object {$_.Action -eq 'Updated'} | Measure-Object).Count"
    $summary += "Failed: $($results | Where-Object {$_.Action -eq 'Failed'} | Measure-Object).Count"
    $summary += ""
    $summary += "CSV Log: $csvLog"

    $summary | Out-File -FilePath $textLog -Encoding UTF8

    Write-Output ""
    Write-Output "Summary:"
    $summary | ForEach-Object { Write-Output "  $_" }
    Write-Output ""
    Write-Output "Detailed CSV log: $csvLog"
    Write-Output "Summary log: $textLog"

} catch {
    Write-Error "Failed to write logs: $_"
    exit 1
}
