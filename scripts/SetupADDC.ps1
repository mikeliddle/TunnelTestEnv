# 2. Create AD DC
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
Import-Module ADDSDeployment
$length = if($DomainName.Split('.')[0].Length -gt 15) { 15 } Else { $DomainName.Split('.')[0].Length }
Install-ADDSForest -CreateDnsDelegation:$false -DatabasePath "D:\NTDS" -DomainMode Win2012R2 -DomainName "$DomainName" -DomainNetbiosName "$($DomainName.Split('.')[0].Substring(0,$length))" -ForestMode Win2012R2 -InstallDns:$true -LogPath "D:\NTDS" -NoRebootOnCompletion:$false -SysvolPath "D:\SYSVOL" -Force:$true
Install-ADDSDomainController -CreateDnsDelegation:$false -Credential (New-Object System.Management.Automation.PSCredential("$Username", (ConvertTo-SecureString "$AdminPassword" -AsPlainText -Force))) -DatabasePath "D:\NTDS" -DomainName "$DomainName" -InstallDns:$true -LogPath "D:\NTDS" -NoGlobalCatalog:$false -SiteName "Default-First-Site-Name" -NoRebootOnCompletion:$false -SysvolPath "D:\SYSVOL" -Force:$true

# 3. Create AD Users and groups
Import-Module ActiveDirectory
New-ADUser -Name $Username -AccountPassword (ConvertTo-SecureString "$Password" -AsPlainText -Force) -Enabled $true -PasswordNeverExpires $true -ChangePasswordAtLogon $false -Path "CN=Users,DC=$DomainName" -SamAccountName $Username -UserPrincipalName "$Username@$DomainName"
New-ADGroup -Name $GroupName -GroupCategory Security -GroupScope Global -Path "CN=Users,DC=$DomainName" -SamAccountName $GroupName
Add-ADGroupMember -Identity $GroupName -Members $Username

# 4. Create a GMSA account
Add-KdsRootKey -EffectiveTime (Get-Date).AddHours(-10)
New-ADServiceAccount FsGmsa -DNSHostName adfs.$DomainName -ServicePrincipalNames http/adfs.$DomainName

# 5. Install SSL certificate

# 6. Install Federation Server
Install-WindowsFeature ADFS-Federation