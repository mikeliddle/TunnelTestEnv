[cmdletbinding(DefaultParameterSetName="Create")]
param(
    [Parameter(Mandatory=$true, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$true, ParameterSetName="Delete")]
    [Parameter(Mandatory=$true, ParameterSetName="ProfilesOnly")]
    [string]$VmName,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$false, ParameterSetName="ProfilesOnly")]
    [string[]]$BundleIds=@(),

    [Parameter(Mandatory=$true, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$true, ParameterSetName="ProfilesOnly")]
    [string]$GroupName,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$false, ParameterSetName="ProfilesOnly")]
    [ValidateSet("ios","android","all")]
    [string]$Platform="all",

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [ValidateSet("eastasia","southeastasia","centralus","eastus","eastus2","westus","westus3","northcentralus","southcentralus","northeurope","westeurope","japanwest","japaneast","brazilsouth","australiaeast","australiasoutheast","southindia","centralindia","westindia","canadacentral","canadaeast","uksouth","ukwest","westcentralus","westus2","koreacentral","koreasouth","francecentral","francesouth","australiacentral","australiacentral2")]
    [string]$Location="westus",

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [ValidateSet("PE","SelfHost","OneDF")]
    [string]$Environment="PE",

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [string]$Email="",

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$false, ParameterSetName="ProfilesOnly")]
    [string]$Username="azureuser",

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [string]$Size = "Standard_B2s",

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [string]$ProxySize = "Standard_B2s",

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [string]$Image = "Canonical:0001-com-ubuntu-server-focal:20_04-lts:latest", #"RedHat:RHEL:8-LVM:latest"
    
    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$false, ParameterSetName="ProfilesOnly")]
    [string]$ADApplication = "Generated MAM Tunnel",

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$false, ParameterSetName="Delete")]
    [string]$SubscriptionId,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$false, ParameterSetName="ProfilesOnly")]
    [switch]$NoProxy,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [switch]$UseEnterpriseCa,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$false, ParameterSetName="Delete")]
    [pscredential]$VmTenantCredential,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$false, ParameterSetName="Delete")]
    [Parameter(Mandatory=$false, ParameterSetName="ProfilesOnly")]
    [pscredential]$TenantCredential,

    [Parameter(Mandatory=$true, ParameterSetName="Delete")]
    [switch]$Delete,

    [Parameter(Mandatory=$true, ParameterSetName="ProfilesOnly")]
    [switch]$ProfilesOnly,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$false, ParameterSetName="Delete")]
    [Parameter(Mandatory=$false, ParameterSetName="ProfilesOnly")]
    [switch]$StayLoggedIn,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [switch]$WithSSHOpen,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$false, ParameterSetName="ProfilesOnly")]
    [string]$PACUrl,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$false, ParameterSetName="ProfilesOnly")]
    [string[]]$IncludeRoutes=@(),

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$false, ParameterSetName="ProfilesOnly")]
    [string[]]$ExcludeRoutes=@(),

    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [switch]$WithADFS,

    [Parameter(Mandatory=$true, ParameterSetName="ADFS")]
    [string]$DomainName
)

$script:WindowsServerImage = "MicrosoftWindowsServer:WindowsServer:2022-Datacenter:latest"
$script:WindowsVmSize = "Standard_DS1_v2"
$script:Account = $null
$script:GraphContext = $null
$script:Subscription = $null
$script:ResourceGroup = $null
$script:SSHKeyPath = $null
$script:FQDN = $null
$script:ServerConfiguration = $null
$script:Site = $null
$script:App = $null
$script:Group = $null
$script:IosDeviceConfigurationPolicy = $null
$script:AndroidDeviceConfigurationPolicy = $null
$script:IosAppProtectionPolicy = $null
$script:AndroidAppProtectionPolicy = $null
$script:IosAppConfigurationPolicy = $null
$script:AndroidAppConfigurationPolicy = $null
$script:IosTrustedRootPolicy = $null
$script:AndroidTrustedRootPolicy = $null
$script:RunningOS = ""
$script:PACUrl = ""
$script:ProxyVMData = $null
$script:ProxyIP = ""

#region Helper Functions
Function Test-Prerequisites {
    Write-Header "Checking prerequisites..."
    if (-Not ([bool](Get-Command -ErrorAction Ignore az))) {
        Write-Error "Please install azure cli`nhttps://learn.microsoft.com/en-us/cli/azure/"
        Exit 1
    }
    
    if (-Not (Get-Module -ListAvailable -Name "Microsoft.Graph")) {
        Write-Header "Installing Microsoft.Graph..."
        Install-Module Microsoft.Graph -Force
    }

    if (-Not ($PSVersionTable.PSVersion.Major -ge 6)) {
        Write-Error "Please use PowerShell Core 6 or later."
        Exit 1
    }

    if ($IsLinux) {
        $script:RunningOS = "linux"
    } elseif ($IsMacOS) {
        $script:RunningOS = "osx"
    } else {
        $script:RunningOS = "win"
    }
}

Function Login {
    if (-Not $ProfilesOnly) {
        Login-Azure
    }
    
    Login-Graph
}

Function Logout {
    if (-Not $StayLoggedIn) {
        Write-Header "Logging out..."
        az logout
        $script:Account = Disconnect-MgGraph
    }
}

Function Initialize-Variables {
    $script:VmName = $VmName.ToLower()
    $script:Account = (az account show | ConvertFrom-Json)
    $script:Subscription = $Account.id
    if ($Email -eq "") {
        Write-Header "Email not provided. Detecting email..."
        $script:Email = $Account.user.name
        Write-Host "Detected your email as '$Email'"
    }

    $script:ResourceGroup = "$VmName-group"
    $script:SSHKeyPath = "$HOME/.ssh/$VmName"

    $script:GraphContext = Get-MgContext

    $script:FQDN = "$VmName.$Location.cloudapp.azure.com"

    if ($PACUrl -eq "") {
        $script:PACUrl = "http://$FQDN/tunnel.pac"
    }

    if (-Not $Delete) {
        # We only need a group name for the create flow
        $script:Group = Get-MgGroup -Filter "displayName eq '$GroupName'"
        if (-Not $Group) {
            Write-Error "Could not find group named '$GroupName'"
            Exit -1
        }
    }
}
#endregion Helper Functions

#region Setup Script
Function Initialize-SetupScript {
    try{
        Write-Header "Generating setup script..."
        $ServerName = $FQDN.Split('.')[0]
        $GitBranch = git branch --show-current
        $Content = @"
        export intune_env=$Environment;

        if [ -f "/etc/debian_version" ]; then
            # debian
            installer="apt-get"
        else
            # RHEL
            installer="dnf"
        fi

        `$installer install -y git >> install.log 2>&1

        git clone --single-branch --branch $GitBranch https://github.com/mikeliddle/TunnelTestEnv.git >> install.log 2>&1
        cd TunnelTestEnv

        cp ../agent.p12 .
        cp ../agent-info.json .
        cp ../tunnel.pac.tmp nginx_data/tunnel.pac

        git submodule update --init >> install.log 2>&1

        chmod +x scripts/*
        
        PUBLIC_IP=`$(curl ifconfig.me)
        $(if (-Not $NoProxy) {"sed -i.bak -e 's/##PROXY_IP##/$ProxyIP/' -e's/# local-data/local-data/'  unbound.conf.d/a-records.conf"})
        sed -i.bak -e "s/SERVER_NAME=/SERVER_NAME=$ServerName/" -e "s/DOMAIN_NAME=/DOMAIN_NAME=$FQDN/" -e "s/SERVER_PUBLIC_IP=/SERVER_PUBLIC_IP=`$PUBLIC_IP/" -e "s/EMAIL=/EMAIL=$Email/" -e "s/SITE_ID=/SITE_ID=$($Site.Id)/" vars
        export SETUP_ARGS="-i$(if ($UseEnterpriseCa) {"e"})"
        
        ./scripts/setup-expect.sh
        
        expect -f ./scripts/setup.exp
"@

        $file = Join-Path $pwd -ChildPath "Setup.sh"
        Set-Content -Path $file -Value $Content -Force
        

        # Replace CR+LF with LF
        $text = [IO.File]::ReadAllText($file) -replace "`r`n", "`n"
        [IO.File]::WriteAllText($file, $text)

        # Replace CR with LF
        $text = [IO.File]::ReadAllText($file) -replace "`r", "`n"
        [IO.File]::WriteAllText($file, $text)

        Write-Header "Copying setup script to remote server..."
        scp -i $sshKeyPath -o "StrictHostKeyChecking=no" ./Setup.sh "$($username)@$($FQDN):~/" > $null
        scp -i $sshKeyPath -o "StrictHostKeyChecking=no" ./agent.p12 "$($username)@$($FQDN):~/" > $null
        scp -i $sshKeyPath -o "StrictHostKeyChecking=no" ./agent-info.json "$($username)@$($FQDN):~/" > $null

        Write-Header "Marking setup scripts as executable..."
        ssh -i $sshKeyPath -o "StrictHostKeyChecking=no" "$($username)@$($FQDN)" "chmod +x ~/Setup.sh"
    }
    finally {
        Remove-Item "./Setup.sh"
    }
}

Function Invoke-SetupScript {
    Write-Header "Connecting into remote server..."
    ssh -i $sshKeyPath -o "StrictHostKeyChecking=no" "$($username)@$($FQDN)" "sudo su -c './Setup.sh'"
}
#endregion Setup Script

#region ADFS Functions
Function Initialize-ADFSVariables {
    $script:VmName = $VmName.ToLower()
    $script:Account = (az account show | ConvertFrom-Json)
    $script:Subscription = $Account.id

    if ($Email -eq "") {
        Write-Header "Email not provided. Detecting email..."
        $script:Email = $Account.user.name
        Write-Host "Detected your email as '$Email'"
    }

    $script:ResourceGroup = "$VmName-group"
    $script:GraphContext = Get-MgContext
}

Function New-ADFSEnvironment {
    Write-Header "Creating ADFS Environment"

    Test-Prerequisites
    Login
    Initialize-ADFSVariables
    New-ResourceGroup

    New-ADDCVM

    # Temporarily undo all the work done to create
    # Remove-ResourceGroup
}

Function New-ADDCVM {
    $AdminPassword = New-RandomPassword
    $length = if($VmName.Length -gt 12) { 12 } Else { $VmName.Length }
    $winName=$VmName.Substring(0,$length) + "-dc"
    
    Write-Header "Creating VM '$winName'..."

    $windowsVmData = az vm create --location $location --resource-group $resourceGroup --name $winName --image $WindowsServerImage --size $WindowsVmSize --public-ip-address-dns-name "$VmName-dc" --admin-username $Username --admin-password $AdminPassword --only-show-errors | ConvertFrom-Json
`
    # Install AD DS role on the first VM and promote it to a domain controller
    az vm run-command invoke --command-id RunPowerShellScript --resource-group $resourceGroup --name $winName --scripts @"
        Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
        Import-Module ADDSDeployment
        $length = if($DomainName.Split('.')[0].Length -gt 15) { 15 } Else { $DomainName.Split('.')[0].Length }
        Install-ADDSForest -CreateDnsDelegation:$false -DatabasePath "D:\NTDS" -DomainMode Win2012R2 -DomainName "$DomainName" -DomainNetbiosName "$($DomainName.Split('.')[0].Substring(0,$length))" -ForestMode Win2012R2 -InstallDns:$true -LogPath "D:\NTDS" -NoRebootOnCompletion:$false -SysvolPath "D:\SYSVOL" -Force:$true
        Install-ADDSDomainController -CreateDnsDelegation:$false -Credential (New-Object System.Management.Automation.PSCredential("$Username", (ConvertTo-SecureString "$AdminPassword" -AsPlainText -Force))) -DatabasePath "D:\NTDS" -DomainName "$DomainName" -InstallDns:$true -LogPath "D:\NTDS" -NoGlobalCatalog:$false -SiteName "Default-First-Site-Name" -NoRebootOnCompletion:$false -SysvolPath "D:\SYSVOL" -Force:$true
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

#region Main Functions
Function New-TunnelEnvironment {
    Test-Prerequisites
    Login
    Initialize-Variables
    New-SSHKeys
    New-ResourceGroup
    New-TunnelVM
    
    if ($NoProxy) {
        Write-Host "Skipping proxy VM creation..."
        $script:ProxyIP = ""
    } else {
        New-ProxyVM
        Initialize-Proxy
        Invoke-ProxyScript
    }
    
    New-NetworkRules

    New-TunnelConfiguration
    New-TunnelSite

    New-TunnelAgent

    Initialize-SetupScript
    Invoke-SetupScript

    Update-PrivateDNSAddress
    
    Update-ADApplication
    New-GeneratedXCConfig

    New-IOSProfiles
    New-AndroidProfiles

    Logout
}

Function Remove-TunnelEnvironment {
    Test-Prerequisites
    Login
    Initialize-Variables
    
    Remove-ResourceGroup
    Remove-SSHKeys

    Remove-IosProfiles
    Remove-AndroidProfiles

    Remove-TunnelServers
    Remove-TunnelSite
    Remove-TunnelConfiguration
    Logout
}

Function New-ProfilesOnlyEnvironment {
    Test-Prerequisites
    Login
    Initialize-Variables

    New-TunnelConfiguration
    New-TunnelSite

    Update-ADApplication
    New-GeneratedXCConfig
    
    New-IOSProfiles
    New-AndroidProfiles

    Logout
}

if ($ProfilesOnly) {
    New-ProfilesOnlyEnvironment
} elseif ($Delete) {
    Remove-TunnelEnvironment
} elseif ($WithADFS) {
    New-ADFSEnvironment
} else {
    New-TunnelEnvironment
}
#endregion Main Functions
