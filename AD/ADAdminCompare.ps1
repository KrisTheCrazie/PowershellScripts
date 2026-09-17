```powershell
Import-Module ActiveDirectory

# ============================================================
# CONFIGURATION
# ============================================================

# Optional: Set this if you want to limit the search to a specific OU.
# Leave as $null to search the entire domain.
$SearchBase = $null

# Example:
# $SearchBase = "OU=Users,DC=domain,DC=local"

# Output CSV
$OutputFile = "C:\Temp\AD_Admin_Account_Matching.csv"

# ============================================================
# GET ALL USER ACCOUNTS
# ============================================================

Write-Host "Retrieving Active Directory users..."

if ($SearchBase) {
    $AllUsers = Get-ADUser `
        -SearchBase $SearchBase `
        -Filter * `
        -Properties Enabled,DisplayName,GivenName,Surname,SamAccountName
}
else {
    $AllUsers = Get-ADUser `
        -Filter * `
        -Properties Enabled,DisplayName,GivenName,Surname,SamAccountName
}

# ============================================================
# SEPARATE ADMIN AND NORMAL USER ACCOUNTS
# ============================================================

$AdminAccounts = $AllUsers | Where-Object {
    $_.SamAccountName -like "a-*"
}

$NormalAccounts = $AllUsers | Where-Object {
    $_.SamAccountName -notlike "a-*"
}

Write-Host "Admin accounts found:  $($AdminAccounts.Count)"
Write-Host "Normal accounts found: $($NormalAccounts.Count)"
Write-Host ""

# ============================================================
# MATCHING
# ============================================================

$Results = foreach ($Admin in $AdminAccounts) {

    $AdminName = $Admin.SamAccountName

    # Remove a- from the beginning
    $BaseName = $AdminName.Substring(2)

    # Find normal accounts that START WITH the admin account
    $Matches = @(
        $NormalAccounts | Where-Object {
            $_.SamAccountName.StartsWith(
                $BaseName,
                [System.StringComparison]::OrdinalIgnoreCase
            )
        }
    )

    # --------------------------------------------------------
    # NO MATCH
    # --------------------------------------------------------

    if ($Matches.Count -eq 0) {

        [PSCustomObject]@{
            AdminAccount       = $AdminName
            AdminEnabled       = $Admin.Enabled
            BaseName           = $BaseName
            UserAccount        = ""
            UserEnabled        = ""
            UserDisplayName    = ""
            MatchType          = "NO MATCH"
            OverallResult      = "NO MATCH"
            MatchCount         = 0
        }

        continue
    }

    # --------------------------------------------------------
    # PROCESS MATCHES
    # --------------------------------------------------------

    foreach ($Match in $Matches) {

        if ($Match.SamAccountName -ieq $BaseName) {
            $MatchType = "EXACT"
        }
        else {
            $MatchType = "POTENTIAL"
        }

        # Determine overall result
        if ($Matches.Count -gt 1) {
            $OverallResult = "MULTIPLE POSSIBLE MATCHES"
        }
        elseif ($MatchType -eq "EXACT" -and $Match.Enabled) {
            $OverallResult = "EXACT ACTIVE MATCH"
        }
        elseif ($MatchType -eq "EXACT" -and !$Match.Enabled) {
            $OverallResult = "EXACT DISABLED MATCH"
        }
        elseif ($MatchType -eq "POTENTIAL" -and $Match.Enabled) {
            $OverallResult = "POTENTIAL ACTIVE MATCH"
        }
        else {
            $OverallResult = "POTENTIAL DISABLED MATCH"
        }

        [PSCustomObject]@{
            AdminAccount       = $AdminName
            AdminEnabled       = $Admin.Enabled
            BaseName           = $BaseName
            UserAccount        = $Match.SamAccountName
            UserEnabled        = $Match.Enabled
            UserDisplayName    = $Match.DisplayName
            MatchType          = $MatchType
            OverallResult      = $OverallResult
            MatchCount         = $Matches.Count
        }
    }
}

# ============================================================
# EXPORT RESULTS
# ============================================================

$OutputDirectory = Split-Path $OutputFile -Parent

if (!(Test-Path $OutputDirectory)) {
    New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
}

$Results | Export-Csv `
    -Path $OutputFile `
    -NoTypeInformation `
    -Encoding UTF8

# ============================================================
# SUMMARY
# ============================================================

$UniqueAdminAccounts = $Results |
    Select-Object -ExpandProperty AdminAccount -Unique

$NoMatch = $Results |
    Where-Object { $_.OverallResult -eq "NO MATCH" } |
    Select-Object -ExpandProperty AdminAccount -Unique

$ExactActive = $Results |
    Where-Object { $_.OverallResult -eq "EXACT ACTIVE MATCH" } |
    Select-Object -ExpandProperty AdminAccount -Unique

$ExactDisabled = $Results |
    Where-Object { $_.OverallResult -eq "EXACT DISABLED MATCH" } |
    Select-Object -ExpandProperty AdminAccount -Unique

$PotentialActive = $Results |
    Where-Object { $_.OverallResult -eq "POTENTIAL ACTIVE MATCH" } |
    Select-Object -ExpandProperty AdminAccount -Unique

$PotentialDisabled = $Results |
    Where-Object { $_.OverallResult -eq "POTENTIAL DISABLED MATCH" } |
    Select-Object -ExpandProperty AdminAccount -Unique

$MultipleMatches = $Results |
    Where-Object { $_.OverallResult -eq "MULTIPLE POSSIBLE MATCHES" } |
    Select-Object -ExpandProperty AdminAccount -Unique

# ============================================================
# DISPLAY SUMMARY
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " AD ADMIN ACCOUNT MATCHING SUMMARY"
Write-Host "============================================================"

Write-Host "Total a- accounts:              $($UniqueAdminAccounts.Count)"
Write-Host ""

Write-Host "Exact active matches:           $($ExactActive.Count)"
Write-Host "Exact disabled matches:         $($ExactDisabled.Count)"
Write-Host ""

Write-Host "Potential active matches:       $($PotentialActive.Count)"
Write-Host "Potential disabled matches:     $($PotentialDisabled.Count)"
Write-Host ""

Write-Host "Multiple possible matches:      $($MultipleMatches.Count)"
Write-Host "No match:                       $($NoMatch.Count)"
Write-Host ""

Write-Host "CSV report saved to:"
Write-Host $OutputFile
Write-Host ""

# ============================================================
# DISPLAY ACCOUNTS WITH NO MATCH
# ============================================================

if ($NoMatch.Count -gt 0) {

    Write-Host "============================================================"
    Write-Host " ACCOUNTS WITH NO MATCH"
    Write-Host "============================================================"

    $Results |
        Where-Object { $_.OverallResult -eq "NO MATCH" } |
        Format-Table AdminAccount, BaseName -AutoSize
}

# ============================================================
# DISPLAY POTENTIAL ACTIVE MATCHES
# ============================================================

if ($PotentialActive.Count -gt 0) {

    Write-Host ""
    Write-Host "============================================================"
    Write-Host " POTENTIAL ACTIVE MATCHES"
    Write-Host "============================================================"

    $Results |
        Where-Object {
            $_.MatchType -eq "POTENTIAL" -and
            $_.UserEnabled -eq $true
        } |
        Format-Table `
            AdminAccount,
            UserAccount,
            UserDisplayName,
            UserEnabled,
            OverallResult `
            -AutoSize
}

# ============================================================
# DISPLAY MULTIPLE MATCHES
# ============================================================

if ($MultipleMatches.Count -gt 0) {

    Write-Host ""
    Write-Host "============================================================"
    Write-Host " MULTIPLE POSSIBLE MATCHES - REVIEW THESE"
    Write-Host "============================================================"

    $Results |
        Where-Object {
            $_.OverallResult -eq "MULTIPLE POSSIBLE MATCHES"
        } |
        Format-Table `
            AdminAccount,
            BaseName,
            UserAccount,
            UserEnabled,
            UserDisplayName `
            -AutoSize
}

Write-Host ""
Write-Host "============================================================"
Write-Host " COMPLETED"
Write-Host "============================================================"
Write-Host "No Active Directory accounts were modified."
```
