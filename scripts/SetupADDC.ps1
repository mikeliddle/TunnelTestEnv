$script:WindowsServerImage = "MicrosoftWindowsServer:WindowsServer:2022-Datacenter:latest"
$script:WindowsVmSize = "Standard_DS1_v2"

#region ADFS Functions
Function Initialize-ADFSVariables {
    $script:VmName = $VmName.ToLower()
    $script:Account = (az account show | ConvertFrom-Json)
    $script:Username = "AdminUser"
    $script:SubscriptionId = $Account.id
    $script:location = "westus"

    if ($Email -eq "") {
        Write-Header "Email not provided. Detecting email..."
        $script:Email = $Account.user.name
        Write-Host "Detected your email as '$Email'"
    }

    $script:ResourceGroup = "$VmName-group"
    $script:GraphContext = Get-MgContext

    $script:WindowsServerImage = "Win2022AzureEditionCore"
}

Function New-ADFSEnvironment {
    param(
        [string] $VmName,
        [string] $DomainName,
        [string] $ResourceGroup,
        [string] $location
    )
    Write-Header "Creating ADFS Environment"

    Login-Azure -SubscriptionId $SubscriptionId -VmTenantCredential $VmTenantCredential
    
    Initialize-ADFSVariables
    New-ResourceGroup -resourceGroup $ResourceGroup -location $location | Out-Null

    New-ADDCVM
}

Function New-ADDCVM {
    $AdminPassword = New-RandomPassword
    $length = if($VmName.Length -gt 12) { 12 } else { $VmName.Length }
    $winName=$VmName.Substring(0,$length) + "-dc"
    
    Write-Header "Creating VM '$winName'..."

    $windowsVmData = az vm create --location $location --resource-group $resourceGroup --name $winName --image $WindowsServerImage --size $WindowsVmSize --public-ip-address-dns-name "$VmName-dc" --admin-username $Username --admin-password $AdminPassword --only-show-errors | ConvertFrom-Json
`
    $domainLength = if("$DomainName".Split('.')[0].Length -gt 15) { 15 } Else { "$DomainName".Split('.')[0].Length }
    # Install AD DS role on the first VM and promote it to a domain controller
    az vm run-command invoke --command-id RunPowerShellScript --resource-group $resourceGroup --name $winName --scripts @"
        Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
        Import-Module ADDSDeployment
        Install-ADDSForest -DatabasePath "D:\NTDS" -DomainMode Win2012R2 -DomainName "$DomainName" -DomainNetbiosName "$($DomainName.Split('.')[0].Substring(0,$domainLength))" -ForestMode Win2012R2 -InstallDns -LogPath "D:\NTDS"  -SysvolPath "D:\SYSVOL" -Force
        Install-ADDSDomainController -Credential (New-Object System.Management.Automation.PSCredential("$Username", (ConvertTo-SecureString "$AdminPassword" -AsPlainText -Force))) -DatabasePath "D:\NTDS" -DomainName "$DomainName" -InstallDns -LogPath "D:\NTDS" -NoGlobalCatalog:$false -SiteName "Default-First-Site-Name" -SysvolPath "D:\SYSVOL" -Force
"@

    # Create AD Users and groups
    az vm run-command invoke --comand-id RunPowerShellScript --resource-group $resourceGroup --name $winName --scripts @"
    Import-Module ActiveDirectory
    New-ADUser -Name $Username -AccountPassword (ConvertTo-SecureString "$Password" -AsPlainText -Force) -Enabled $true -PasswordNeverExpires $true -ChangePasswordAtLogon $false -Path "CN=Users,DC=$DomainName" -SamAccountName $Username -UserPrincipalName "$Username@$DomainName"
    New-ADGroup -Name $GroupName -GroupCategory Security -GroupScope Global -Path "CN=Users,DC=$DomainName" -SamAccountName $GroupName
    Add-ADGroupMember -Identity $GroupName -Members $Username
"@

    # Create a GMSA account
    az vm run-command invoke --comand-id RunPowerShellScript --resource-group $resourceGroup --name $winName --scripts @"
    Add-KdsRootKey -EffectiveTime (Get-Date).AddHours(-10)
    New-ADServiceAccount FsGmsa -DNSHostName adfs.$DomainName -ServicePrincipalNames http/adfs.$DomainName
"@

    # Install Federation Server 
    az vm run-command invoke --comand-id RunPowerShellScript --resource-group $resourceGroup --name $winName --scripts @"
    Install-WindowsFeature ADFS-Federation -IncludeManagementTools
"@
}
#endregion ADFS Functions