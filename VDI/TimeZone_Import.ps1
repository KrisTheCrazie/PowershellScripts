$registryPath = "HKCU:\TimeZone"
$registryValue = "Id"
 
Do {
Start-Sleep -Seconds 2
}
Until (((Get-Item -Path $registrypath).GetValue($registryValue) -ne $null) -eq $True)
 
$Id = (Get-ItemProperty -Path $registryPath).Id
 
Set-TimeZone -Id $Id