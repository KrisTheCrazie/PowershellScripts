Import-Module ActiveDirectory

# --- CONFIGURATION ---
$BaseOU = "DC=corp,DC=local"
$Company = "Contoso"

# Subnet → Location mapping
$SubnetMap = @{
    "192.168.10.0/24" = "Toronto"
    "192.168.20.0/24" = "NewYork"
    "192.168.30.0/24" = "Vancouver"
    "192.168.40.0/24" = "Montreal"
}

# Location → Code mapping
$LocationCodes = @{
    "Toronto"   = "TOR"
    "NewYork"   = "NYC"
    "Vancouver" = "VAN"
    "Montreal"  = "MTL"
}

$NumberLength = 5
$RestartAfterRename = $false
$HistoryFile = "C:\Scripts\NumberHistory.csv"

# Test mode toggle
$TestMode = $true   # Set to $true for dry-run, $false to actually rename

# --- LOAD NUMBER HISTORY ---
if (Test-Path $HistoryFile) {
    $NumberHistory = @{}
    Import-Csv $HistoryFile | ForEach-Object { $NumberHistory[$_.Location] = $_.LastNumber }
} else {
    $NumberHistory = @{}
}

# --- FUNCTION: Determine location from IP ---
function Get-LocationFromIP {
    param (
        [string[]]$IPs,
        [hashtable]$SubnetMap
    )

    foreach ($IP in $IPs) {
        foreach ($subnet in $SubnetMap.Keys) {
            $network, $prefix = $subnet -split '/'
            $maskLength = [int]$prefix

            $ipAddr = [System.Net.IPAddress]::Parse($IP)
            $netAddr = [System.Net.IPAddress]::Parse($network)

            $ipInt = [BitConverter]::ToUInt32($ipAddr.GetAddressBytes()[::-1],0)
            $netInt = [BitConverter]::ToUInt32($netAddr.GetAddressBytes()[::-1],0)
            $maskInt = [uint32](([math]::Pow(2, $maskLength)-1) -shl (32-$maskLength))

            if (($ipInt -band $maskInt) -eq ($netInt -band $maskInt)) {
                return $SubnetMap[$subnet]
            }
        }
    }

    return $null
}

# --- GET ALL COMPUTERS ---
$Computers = Get-ADComputer -SearchBase $BaseOU -Filter * -Properties Name

foreach ($Comp in $Computers) {
    $CurrentName = $Comp.Name

    # Skip computers that do not contain -W or -L
    if ($CurrentName -notmatch "-[WL]") {
        Write-Host "Skipping $CurrentName (does not contain '-W' or '-L')"
        continue
    }

    # Detect type (W or L)
    if ($CurrentName -match "-([WL])") {
        $TypeLetter = $matches[1]
    } else {
        $TypeLetter = "W"
    }

    # Get IPs from the computer
    try {
        $IPs = Get-CimInstance -ComputerName $CurrentName -ClassName Win32_NetworkAdapterConfiguration |
               Where-Object { $_.IPAddress -ne $null } | Select-Object -ExpandProperty IPAddress
    } catch {
        Write-Warning "Could not retrieve IP for $CurrentName. Skipping."
        continue
    }

    # Determine location from IP
    $LocationName = Get-LocationFromIP -IPs $IPs -SubnetMap $SubnetMap
    if (-not $LocationName) {
        Write-Warning "Could not determine location for $CurrentName. Skipping."
        continue
    }

    $LocationCode = $LocationCodes[$LocationName]
    if (-not $LocationCode) {
        Write-Warning "No code found for location '$LocationName'. Skipping."
        continue
    }

    # Determine next sequential number
    $ExistingNames = $Computers | Where-Object { $_.Name -match "$Company-$LocationCode-[WL]\d{$NumberLength}" } | ForEach-Object { $_.Name }
    $UsedNumbers = @()
    foreach ($Name in $ExistingNames) {
        if ($Name -match "$Company-$LocationCode-[WL](\d{$NumberLength})") {
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

    # Build new name
    $NewName = "{0}-{1}-{2}{3:D$NumberLength}" -f $Company, $LocationCode, $TypeLetter, $NextNum

    # Skip if already correct
    if ($CurrentName -eq $NewName) {
        Write-Host "Skipping $CurrentName (already correct)"
        continue
    }

    # Perform rename or just print if in test mode
    if ($TestMode) {
        Write-Host "[TEST] Would rename $CurrentName → $NewName"
    } else {
        Write-Host "Renaming $CurrentName → $NewName"
        try {
            if ($RestartAfterRename) {
                Rename-Computer -ComputerName $CurrentName -NewName $NewName -Force -Restart
            } else {
                Rename-Computer -ComputerName $CurrentName -NewName $NewName -Force
            }
        } catch {
            Write-Warning "Failed to rename $CurrentName: $_"
            continue
        }
    }

    # Update number history
    $NumberHistory[$LocationName] = $NextNum
}

# --- SAVE NUMBER HISTORY ---
$HistoryOutput = $NumberHistory.GetEnumerator() | ForEach-Object {
    [PSCustomObject]@{ Location = $_.Key; LastNumber = $_.Value }
}
$HistoryOutput | Export-Csv $HistoryFile -NoTypeInformation

Write-Host "`nCompleted renaming. Number history saved to $HistoryFile"
