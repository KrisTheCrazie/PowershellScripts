Import-Module ActiveDirectory

# --- CONFIGURATION ---
$Company = "Example"
$BaseOU = "DC=corp,DC=local"     # Root of your domain or a higher OU
$LocationCodes = @{
    "Toronto"   = "TOR"
    "NewYork"   = "NYC"
    "Vancouver" = "VAN"
    "Montreal"  = "MTL"
}
$NumberLength = 5
$NamePattern  = "{0}-{1}-W{2:D$NumberLength}"   # Example: EXAMPLE-TOR-W00001
$RestartAfterRename = $false                  # Set to $true if you want automatic reboot
$HistoryFile = "C:\Scripts\NumberHistory.csv" # Path to store last numbers

# --- LOAD NUMBER HISTORY ---
if (Test-Path $HistoryFile) {
    $NumberHistory = Import-CSV $HistoryFile | ForEach-Object { @{ $_.Location = $_.LastNumber } }
} else {
    $NumberHistory = @{}
}

# --- GET ALL COMPUTERS ---
$Computers = Get-ADComputer -SearchBase $BaseOU -Filter * -Properties Name,DistinguishedName |
    Where-Object { $_.DistinguishedName -match "OU=Computers" }

# --- GROUP BY LOCATION (OU one level above Computers) ---
$GroupedByLocation = $Computers | Group-Object {
    if ($_.DistinguishedName -match "OU=([^,]+),OU=Computers") { $matches[1] } else { "Unknown" }
}

foreach ($Group in $GroupedByLocation) {
    $LocationName = $Group.Name
    $LocationCode = $LocationCodes[$LocationName]

    if (-not $LocationCode) {
        Write-Warning "No location code found for '$LocationName'. Skipping..."
        continue
    }

    Write-Host "`nProcessing Location: $LocationName ($LocationCode)"
    $LocComputers = $Group.Group

    # Identify last used number
    $ExistingNames = $LocComputers | ForEach-Object { $_.Name }
    $UsedNumbers = @()

    foreach ($Name in $ExistingNames) {
        if ($Name -match "$Company-$LocationCode-W(\d{$NumberLength})") {
            $UsedNumbers += [int]$matches[1]
        }
    }

    $LastNumber = 0
    if ($NumberHistory.ContainsKey($LocationName)) {
        $LastNumber = [int]$NumberHistory[$LocationName]
    } elseif ($UsedNumbers) {
        $LastNumber = ($UsedNumbers | Measure-Object -Maximum).Maximum
    }

    $NextNum = $LastNumber + 1

    foreach ($Comp in $LocComputers) {
        $CurrentName = $Comp.Name

        # Skip if W is not in the expected spot
        if ($CurrentName -notmatch "$Company-$LocationCode-W") {
            Write-Host "Skipping $CurrentName (does not contain '-W' in the correct position)"
            continue
        }

        $NewName = $NamePattern -f $Company, $LocationCode, $NextNum

        # Skip if already correctly named
        if ($CurrentName -eq $NewName) {
            Write-Host "Skipping $CurrentName (already correct)"
            continue
        }

        Write-Host "Renaming $CurrentName → $NewName"

        try {
            if ($RestartAfterRename) {
                Rename-Computer -ComputerName $CurrentName -NewName $NewName -Force -Restart
            } else {
                Rename-Computer -ComputerName $CurrentName -NewName $NewName -Force
            }
            $NextNum++
        } catch {
            Write-Warning "Failed to rename $CurrentName: $_"
        }
    }

    # Update number history for this location
    $NumberHistory[$LocationName] = $NextNum - 1
}

# --- SAVE NUMBER HISTORY ---
$HistoryOutput = $NumberHistory.GetEnumerator() | ForEach-Object {
    [PSCustomObject]@{ Location = $_.Key; LastNumber = $_.Value }
}
$HistoryOutput | Export-Csv $HistoryFile -NoTypeInformation

Write-Host "`nCompleted renaming. Number history saved to $HistoryFile"