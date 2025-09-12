# Define the base domain
$domain = "DC=default,DC=ca"

# Source OU where all new computers are placed
$sourceOU = "CN=Computers,$domains"

# Define Valid locations to their OU's
$locationmap = @{
    "OTT" = "OU=OTT",
    "TOR" = "OU=TOR",
    "VAN" = "OU=VAN",
    "MTL" = "OU=MTL"
}

# Map first letter of TypeID to specific OUs
$typeMap = @{
    "W" = "OU=Workstation",
    "L" = "OU=Laptop"
}

# Get all computers from the Computers OU
$computers = Get-ADComputer -SearchBase $sourceOU -Filter *

foreach ($computer in $computers) {
    # Split the name into sections that can be called upon
    $nameParts = $computer.Name =Split '-'
    
    if($nameParts.Length -ge 3) {
        $locCode = $nameParts[1] #e.g. OTT from HH-OTT-W0001
        $typeChar = $nameParts[2].Substring(0,1) # Pull out the typeMap to filter
        Write-Host "Location Code is $locCode and Type is $TypeChar"
        
        # Validate it has a valid location code
        if ($locationMap.ContainsKey($locCode) -and $typeMap.ContainsKey($typeChar)) {
            $locationOU = $locationmap[$locCode]
            $deviceOU = $typeMap[$typeChar]
            $targetOU = "$deviceOU,OU=Computers,$locationOU,$domain"
            try {
                Write-Host "Moving $computer tp $targetOU"
                Move-ADObject -Identity $($computer.DistinguishedName) -TargetPath $targetOU
            }
            catch {
                Write-Warning "Failed to move $($computer.DistinguishedName): $_"
            }
        }
        else {
            Write-Warning "Location code $locCode or Type code $typeChar not found in mapping. Skipping $($computer.DistinguishedName)"
        }
    }
    else {
        Write-Warning "Skipping $($computer.DistinguishedName): Name format not recongized"
    }
}