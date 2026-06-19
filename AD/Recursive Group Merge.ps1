$groups = "group1","group2"
$result =@()
foreach($group in $groups){$result += Get-ADGroupMember -Identity $group -recursive | Select @{Label="Group Name";Expression={$group}}, SamAccountName}
$result | Export-CSV "C:\Group Membership\title.csv
Import-CSV "filename.csv" | % { add-adgroupmember -identity "groupname" -member $_.samaccountname }