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
    [string]$Image = "Canonical:0001-com-ubuntu-server-focal:20_04-lts:latest",
    
    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [switch]$RHEL8,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [switch]$RHEL7,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [switch]$Centos7,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [switch]$Simple,    

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
    [switch]$NoPki,

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
    [string]$DomainName,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$false, ParameterSetName="ProfilesOnly")]
    [Int32]$ListenPort=443
)

$script:SSHKeyPath = ""

#region Helper Functions
Function Initialize {
    if ($IsLinux) {
        $script:RunningOS = "linux"
    } elseif ($IsMacOS) {
        $script:RunningOS = "osx"
    } else {
        $script:RunningOS = "win"
    }

    if ($RHEL8) {
        $script:Image = "RedHat:RHEL:8-LVM:latest"
    } elseif ($RHEL7) {
        $script:Image = "RedHat:RHEL:7-LVM:latest"
    } elseif ($Centos7) {
        $script:Image = "OpenLogic:CentOS:7_9:latest"
    } elseif ($Simple) {
        $script:NoProxy = $true
        $script:NoPki = $true
    }
}

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
}

Function Login {
    if (-Not $ProfilesOnly) {
        Login-Azure -SubscriptionId $SubscriptionId -VmTenantCredential $VmTenantCredential
    }
    
    Login-Graph -TenantCredential $TenantCredential
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

#region Main Functions
Function New-TunnelEnvironment {
    Login
    Initialize-Variables
    New-SSHKeys $SSHKeyPath

    $ResourceGroup = New-ResourceGroup -resourceGroup "$VmName-group"
    $TunnelVM = New-TunnelVM -VmName $VmName -Username $Username -Image $Image -Size $Size -SSHKeyPath $SSHKeyPath -location $location -ResourceGroup $ResourceGroup.name
    $ServiceVM = New-ServiceVM -VmName $VmName -Username $Username -Size $Size -SSHKeyPath $SSHKeyPath -location $location -ResourceGroup $ResourceGroup.name

    $ServiceVMName = "$VmName-server"

    if (-Not $Simple) {
        $script:ProxyIP = Get-ProxyPrivateIP -VmName $ServiceVMName -ResourceGroup $ResourceGroup.name
        New-AdvancedNetworkRules -resourceGroup $ResourceGroup.name -ProxyIP $ProxyIP -VmName $VmName -WithSSHOpen $WithSSHOpen
    } else {
        New-NetworkRules -resourceGroup $ResourceGroup.name -VmName $VmName -WithSSHOpen $WithSSHOpen
    }
    
    if (!$NoProxy) {
        # Setup Proxy server on Service VM
        Initialize-Proxy -VmName $ServiceVMName -ProxyVMData $ServiceVM -Username $Username -SSHKeyPath $SSHKeyPath -TunnelServer $TunnelVM.fqdns -ResourceGroup $ResourceGroup.name
        Invoke-ProxyScript -ProxyVMData $ServiceVM -Username $Username -SSHKeyPath $SSHKeyPath
    }

    # Create Certificates
    New-BasicPki -ServiceVMDNS $ServiceVM.fqdns -TunnelVMDNS $TunnelVm.fqdns -Username $Username -SSHKeyPath $SSHKeyPath

    # Setup DNS
    New-DnsServer -TunnelVMDNS $TunnelVM.fqdns -ProxyIP $ProxyIP -Username $Username -SSHKeyPath $SSHKeyPath -ServiceVMDNS $ServiceVM.fqdns
    # Setup WebServers
    New-NginxSetup -TunnelVMDNS $TunnelVM.fqdns -Username $Username -SSHKeyPath $SSHKeyPath -ServiceVMDNS $ServiceVM.fqdns -Email $Email

    # Create Tunnel Configuration
    $ServerConfiguration = New-TunnelConfiguration -ServerConfigurationName $VmName -ListenPort $ListenPort -DnsServer $ProxyIP -IncludeRoutes $IncludeRoutes -ExcludeRoutes $ExcludeRoutes -DefaultDomainSuffix $TunnelVM.fqdns
    $TunnelSite = New-TunnelSite -SiteName $VmName -FQDN $TunnelVM.fqdns -ServerConfiguration $ServerConfiguration

    # Enroll Tunnel Agent
    New-TunnelAgent -RunningOS $RunningOS -Site $TunnelSite -TenantCredential $TenantCredential

    Initialize-TunnelServer -FQDN $TunnelVm.fqdns -SiteId $TunnelSite.Id -SSHKeyPath $SSHKeyPath -Username $Username
    Initialize-SetupScript -FQDN $TunnelVm.fqdns -Environment $Environment -NoProxy $NoProxy -NoPki $NoPki -Email $Email -Site $TunnelSite -Username $Username
    Invoke-SetupScript -SSHKeyPath $SSHKeyPath -Username $Username -FQDN $TunnelVm.fqdns

    Update-PrivateDNSAddress -FQDN $ServiceVM.fqdns -VmUsername $Username -SSHKeyPath $SSHKeyPath -ServerConfiguration $ServerConfiguration -DNSPrivateAddress $ProxyIP

    $AppRegistration = Update-ADApplication -ADApplication $ADApplication -TenantId $GraphContext.TenantId -BundleIds $BundleIds
    New-GeneratedXCConfig -bundle $BundleIds[0] -AppId $AppRegistration.AppId -TenantId $GraphContext.TenantId

    if ($Platform -eq "ios" -or $Platform -eq "all") {
        New-IOSProfiles -VmName $VmName -certFileName cacert.pem.tmp -GroupId $Group.Id -PACUrl "$($ServiceVM.fqdns)/tunnel.pac" -Site $TunnelSite -ServerConfiguration $ServerConfiguration
    }
    if ($Platform -eq "android" -or $Platform -eq "all") {
        New-AndroidProfiles -VmName $VmName -certFileName cacert.pem.tmp -GroupId $Group.Id -PACUrl "$($ServiceVM.fqdns)/tunnel.pac" -Site $TunnelSite -ServerConfiguration $ServerConfiguration
    }

    if (!$StayLoggedIn) {
        Logout
    }
}

Function Remove-TunnelEnvironment {
    Login
    Initialize-Variables
    
    Remove-ResourceGroup -resourceGroup "$VmName-group"
    Remove-SSHKeys -SSHKeyPath "$HOME/.ssh/$VmName"

    Remove-IosProfiles -VmName $VmName
    Remove-AndroidProfiles -VmName $VmName

    Remove-TunnelServers -SiteName $VmName
    Remove-TunnelSite -SiteName $VmName
    Remove-TunnelConfiguration -ServerConfigurationName $VmName
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

# Import functions from dependent files
. ./scripts/TunnelAzure.ps1
. ./scripts/TunnelHelpers.ps1
. ./scripts/TunnelProfiles.ps1
. ./scripts/TunnelProxy.ps1
. ./scripts/TunnelSetup.ps1
. ./scripts/SetupServices.ps1

Test-Prerequisites
Initialize

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