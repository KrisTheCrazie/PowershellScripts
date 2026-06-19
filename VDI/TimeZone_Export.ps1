$registryPath = "HKCU:\TimeZone"

New-Item -Path $registryPath -Force
New-ItemProperty -Path $registryPath -Name Id -Value (Get-TimeZone).Id -Force