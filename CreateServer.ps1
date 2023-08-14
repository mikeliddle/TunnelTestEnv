[cmdletbinding(DefaultParameterSetName="Create")]
param(
    [Parameter(Mandatory=$true, ParameterSetName="Create")]
    [Parameter(Mandatory=$true, ParameterSetName="SprintSignoff")]
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
    [Parameter(Mandatory=$false, ParameterSetName="SprintSignoff")]
    [ValidateSet("eastasia","southeastasia","centralus","eastus","eastus2","westus","westus3","northcentralus","southcentralus","northeurope","westeurope","japanwest","japaneast","brazilsouth","australiaeast","australiasoutheast","southindia","centralindia","westindia","canadacentral","canadaeast","uksouth","ukwest","westcentralus","westus2","koreacentral","koreasouth","francecentral","francesouth","australiacentral","australiacentral2")]
    [string]$Location="westus",

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [ValidateSet("PE","SelfHost","OneDF")]
    [string]$Environment="PE",

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="SprintSignoff")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [string]$Email="",

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$false, ParameterSetName="ProfilesOnly")]
    [Parameter(Mandatory=$false, ParameterSetName="SprintSignoff")]
    [string]$Username="azureuser",

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$false, ParameterSetName="SprintSignoff")]
    [string]$Size = "Standard_B2s",

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$false, ParameterSetName="SprintSignoff")]
    [string]$ProxySize = "Standard_B2s",

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$false, ParameterSetName="SprintSignoff")]
    [string]$Image = "Canonical:0001-com-ubuntu-server-focal:20_04-lts:latest",
    
    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$false, ParameterSetName="SprintSignoff")]
    [switch]$RHEL8,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$false, ParameterSetName="SprintSignoff")]
    [switch]$RHEL7,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$false, ParameterSetName="SprintSignoff")]
    [switch]$Centos7,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$false, ParameterSetName="SprintSignoff")]
    [switch]$Simple,    

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$false, ParameterSetName="ProfilesOnly")]
    [string]$ADApplication = "Generated MAM Tunnel",

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$false, ParameterSetName="Delete")]
    [Parameter(Mandatory=$false, ParameterSetName="SprintSignoff")]
    [string]$SubscriptionId,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$false, ParameterSetName="ProfilesOnly")]
    [Parameter(Mandatory=$false, ParameterSetName="SprintSignoff")]
    [switch]$NoProxy,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ProfilesOnly")]
    [switch]$NoPACUrl,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$false, ParameterSetName="SprintSignoff")]
    [pscredential[]]$AuthenticatedProxyCredentials=$null,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="SprintSignoff")]
    [Parameter(Mandatory=$false, ParameterSetName="ProfilesOnly")]
    [switch]$NoPki,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$false, ParameterSetName="Delete")]
    [Parameter(Mandatory=$false, ParameterSetName="SprintSignoff")]
    [pscredential]$VmTenantCredential,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$false, ParameterSetName="Delete")]
    [Parameter(Mandatory=$false, ParameterSetName="ProfilesOnly")]
    [pscredential]$TenantCredential,

    [Parameter(Mandatory=$true, ParameterSetName="Delete")]
    [switch]$Delete,

    [Parameter(Mandatory=$true, ParameterSetName="ProfilesOnly")]
    [Parameter(Mandatory=$false, ParameterSetName="Delete")]
    [switch]$ProfilesOnly,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$false, ParameterSetName="Delete")]
    [Parameter(Mandatory=$false, ParameterSetName="ProfilesOnly")]
    [Parameter(Mandatory=$false, ParameterSetName="SprintSignoff")]
    [switch]$StayLoggedIn,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$false, ParameterSetName="SprintSignoff")]
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

    [Parameter(Mandatory=$false, ParameterSetName="SprintSignoff")]
    [switch]$SprintSignoff,

    [Parameter(Mandatory=$true, ParameterSetName="ADFS")]
    [string]$DomainName,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$false, ParameterSetName="ProfilesOnly")]
    [Int32]$ListenPort=443,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$false, ParameterSetName="SprintSignoff")]
    [switch]$UseInspection,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ADFS")]
    [Parameter(Mandatory=$false, ParameterSetName="SprintSignoff")]
    [switch]$UseAllowList
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

    if (-Not $Delete -And -Not $SprintSignoff) {
        # We only need a group name for the create and profile flows
        $script:Group = Get-MgGroup -Filter "displayName eq '$GroupName'"
        if (-Not $Group) {
            Write-Error "Could not find group named '$GroupName'"
            Exit -1
        }
    }
}

Function New-Profiles {
    if ($NoProxy) {
        $ProxyHostname = ""
        $ProxyPort = ""
        $PACUrl = ""
    } else {
        # TODO: If $TunnelVm doesn't resolve (due to being profiles only), then fetch it from the az cli
        $ProxyHostname = $TunnelVm.fqdns
        $ProxyPort = "3128"
        $PACUrl = "http://$($TunnelVm.fqdns)/tunnel.pac"
    }

    if ($NoPACUrl) {
        if ($Platform -eq "ios" -or $Platform -eq "all") {
            New-IOSProfiles -VmName $VmName -certFileName cacert.pem.tmp -GroupId $Group.Id -ProxyHostname $ProxyHostname -ProxyPort $ProxyPort -Site $TunnelSite -ServerConfiguration $ServerConfiguration
        }
        if ($Platform -eq "android" -or $Platform -eq "all") {
            New-AndroidProfiles -VmName $VmName -certFileName cacert.pem.tmp -GroupId $Group.Id -ProxyHostname $ProxyHostname -ProxyPort $ProxyPort -Site $TunnelSite -ServerConfiguration $ServerConfiguration
        }
    } else {
        if ($Platform -eq "ios" -or $Platform -eq "all") {
            New-IOSProfiles -VmName $VmName -certFileName cacert.pem.tmp -GroupId $Group.Id -PACUrl $PACUrl -Site $TunnelSite -ServerConfiguration $ServerConfiguration
        }
        if ($Platform -eq "android" -or $Platform -eq "all") {
            New-AndroidProfiles -VmName $VmName -certFileName cacert.pem.tmp -GroupId $Group.Id -PACUrl $PACUrl -Site $TunnelSite -ServerConfiguration $ServerConfiguration
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
    $script:ProxyIP = Get-ProxyPrivateIP -VmName $ServiceVMName -ResourceGroup $ResourceGroup.name

    if (-Not $Simple) {
        New-AdvancedNetworkRules -resourceGroup $ResourceGroup.name -ProxyIP $ProxyIP -VmName $VmName -WithSSHOpen $WithSSHOpen
    } else {
        New-NetworkRules -resourceGroup $ResourceGroup.name -VmName $VmName -WithSSHOpen $WithSSHOpen
    }

    if (!$NoProxy) {
        # Setup Proxy server on Service VM
        Initialize-Proxy -VmName $ServiceVMName -ProxyVMData $ServiceVM -Username $Username -SSHKeyPath $SSHKeyPath -TunnelServer $TunnelVM.fqdns -ResourceGroup $ResourceGroup.name -UseInspection $UseInspection -UseAllowList $UseAllowList -AuthenticatedProxyCredentials $AuthenticatedProxyCredentials
        Invoke-ProxyScript -ProxyVMData $ServiceVM -Username $Username -SSHKeyPath $SSHKeyPath -UseInspection $UseInspection
    }

    # Create Certificates
    New-BasicPki -ServiceVMDNS $ServiceVM.fqdns -TunnelVMDNS $TunnelVm.fqdns -Username $Username -SSHKeyPath $SSHKeyPath

    # Setup DNS
    New-DnsServer -TunnelVMDNS $TunnelVM.fqdns -ProxyIP $ProxyIP -Username $Username -SSHKeyPath $SSHKeyPath -ServiceVMDNS $ServiceVM.fqdns
    # Setup WebServers
    New-NginxSetup -TunnelVMDNS $TunnelVM.fqdns -Username $Username -SSHKeyPath $SSHKeyPath -ServiceVMDNS $ServiceVM.fqdns -Email $Email -ServerIp $ProxyIP

    Update-RebootVM -VmName $ServiceVMName -ResourceGroup $ResourceGroup.name

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

    New-Profiles

    New-Summary
    
    if (!$StayLoggedIn) {
        Logout
    }
}

Function New-SprintSignoffEnvironment {
    Login-Azure -SubscriptionId $SubscriptionId -VmTenantCredential $VmTenantCredential
    Initialize-Variables
    New-SSHKeys $SSHKeyPath

    $ResourceGroup = New-ResourceGroup -resourceGroup "$VmName-group"
    $TunnelVM = New-TunnelVM -VmName $VmName -Username $Username -Image $Image -Size $Size -SSHKeyPath $SSHKeyPath -location $location -ResourceGroup $ResourceGroup.name
    $ServiceVM = New-ServiceVM -VmName $VmName -Username $Username -Size $Size -SSHKeyPath $SSHKeyPath -location $location -ResourceGroup $ResourceGroup.name

    $ServiceVMName = "$VmName-server"
    $script:ProxyIP = Get-ProxyPrivateIP -VmName $ServiceVMName -ResourceGroup $ResourceGroup.name

    if (-Not $Simple) {
        New-AdvancedNetworkRules -resourceGroup $ResourceGroup.name -ProxyIP $ProxyIP -VmName $VmName -WithSSHOpen $WithSSHOpen
    } else {
        New-NetworkRules -resourceGroup $ResourceGroup.name -VmName $VmName -WithSSHOpen $WithSSHOpen
    }

    if (!$NoProxy) {
        # Setup Proxy server on Service VM
        Initialize-Proxy -VmName $ServiceVMName -ProxyVMData $ServiceVM -Username $Username -SSHKeyPath $SSHKeyPath -TunnelServer $TunnelVM.fqdns -ResourceGroup $ResourceGroup.name -UseInspection $UseInspection -UseAllowList $UseAllowList -AuthenticatedProxyCredentials $AuthenticatedProxyCredentials
        Invoke-ProxyScript -ProxyVMData $ServiceVM -Username $Username -SSHKeyPath $SSHKeyPath -UseInspection $UseInspection
    }

    # Create Certificates
    New-BasicPki -ServiceVMDNS $ServiceVM.fqdns -TunnelVMDNS $TunnelVm.fqdns -Username $Username -SSHKeyPath $SSHKeyPath

    # Setup DNS
    New-DnsServer -TunnelVMDNS $TunnelVM.fqdns -ProxyIP $ProxyIP -Username $Username -SSHKeyPath $SSHKeyPath -ServiceVMDNS $ServiceVM.fqdns
    # Setup WebServers
    New-NginxSetup -TunnelVMDNS $TunnelVM.fqdns -Username $Username -SSHKeyPath $SSHKeyPath -ServiceVMDNS $ServiceVM.fqdns -Email $Email -ServerIp $ProxyIP

    Update-RebootVM -VmName $ServiceVMName -ResourceGroup $ResourceGroup.name

    New-Summary

    if (!$StayLoggedIn) {
        az logout
    }
}

Function New-Summary {
    Write-Success "=====================Summary====================="
    
    Write-Success "VM Username: $Username"
    Write-Success "VM SSH Key: $SSHKeyPath"
    Write-Success ""
    Write-Success "Tunnel Server Address: $($TunnelVM.fqdns)"
    Write-Success ""

    if (!$SprintSignoff) {
        Write-Success "Profiles targeted to $($Group.displayName)"
        Write-Success ""
    }

    if ($BundleIds.Count -gt 0) {
        Write-Success "Targeted App Bundle IDs for MAM: $($BundleIds -join ', ')"
        Write-Success ""
    }

    if ($IncludeRoutes.Count -gt 0) {
        Write-Success "Routes to include: $($IncludeRoutes -join ', ')"
        Write-Success ""
    }

    if ($ExcludeRoutes.Count -gt 0) {
        Write-Success "Routes to exclude: $($ExcludeRoutes -join ', ')"
        Write-Success ""
    }

    if (!$NoProxy) {
        Write-Success "PAC URL: http://$($TunnelVM.fqdns)/proxy.pac"
        Write-Success "Proxy Hostname: proxy.$($TunnelVM.fqdns)"
        Write-Success "Proxy Port: 3128"
        Write-Success ""
        Write-Success "These URLS Bypass the proxy when using a PAC file: "
        Write-Success "  www.google.com"
        Write-Success "  excluded.$($TunnelVM.fqdns)"
        Write-Success ""
        
        if ($UseAllowList) {
            Write-Success "Proxy is configured for TLS Inspection"
        }

        if ($UseAllowList) {
            Write-Success "Only the following URLs are allowed through the proxy:"
            $Allowlist = Get-Content -Path "proxy\allowlist.tmp"
            Write-Success $Allowlist
        }
    }
    Write-Success ""
    Write-Success "DNS Server: $ProxyIP"
    Write-Success "Default Search Suffix: $($TunnelVM.fqdns)"
    Write-Success ""
    Write-Success "Internal Endpoints: "
    Write-Success "  http://$ProxyIP - most stable for reachability check"
    Write-Success "  https://webapp or https://webapp.$($TunnelVM.fqdns) - When using a proxy, this should show your IP as $ProxyIP"
    Write-Success "  https://excluded or https://excluded.$($TunnelVM.fqdns) - When using a proxy, this should show you a different IP than above"
    Write-Success "  https://trusted or https://trusted.$($TunnelVM.fqdns)"
    Write-Success "  https://$($TunnelVM.fqdns) - This endpoint is secured using LetsEncrypt when accessed through the VPN."
    Write-Success "  https://untrusted or https://untrusted.$($TunnelVM.fqdns) - This endpoint should give you a certificate error"
    Write-Success ""
    Write-Success "Trusted Certificate Path: cacert.pem.tmp"
    Write-Success "You will need to rename and upload that certificate to Intune as a trusted certificate."
    Write-Success "The certificate is also printed out above."
    Write-Success "================================================="
}

Function Remove-TunnelEnvironment {
    Login
    Initialize-Variables
    
    Remove-ResourceGroup -resourceGroup "$VmName-group"
    Remove-SSHKeys -SSHKeyPath "$HOME/.ssh/$VmName" -TunnelFQDN "$VmName.$Location.cloudapp.azure.com" -ServiceFQDN "$VmName-server.$Location.cloudapp.azure.com"

    Remove-IosProfiles -VmName $VmName
    Remove-AndroidProfiles -VmName $VmName

    Remove-TunnelServers -SiteName $VmName
    Remove-TunnelSite -SiteName $VmName
    Remove-TunnelConfiguration -ServerConfigurationName $VmName

    Remove-TempFiles

    if (!$StayLoggedIn) {
        Logout
    }
}

Function Remove-TempFiles {
    Remove-Item proxy/*.tmp
    Remove-Item nginx_data/tunnel.pac.tmp
    Remove-Item nginx.conf.d/nginx.conf.tmp
    Remove-Item cacert.pem.tmp
    Remove-Item scripts/*.tmp
    Remove-Item agent.p12
    Remove-Item agent-info.json
}

Function New-ProfilesOnlyEnvironment {
    Test-Prerequisites
    Login
    Initialize-Variables

    $ServerConfiguration = New-TunnelConfiguration -ServerConfigurationName $VmName -ListenPort $ListenPort -DnsServer $ProxyIP -IncludeRoutes $IncludeRoutes -ExcludeRoutes $ExcludeRoutes -DefaultDomainSuffix $TunnelVM.fqdns
    $TunnelSite = New-TunnelSite -SiteName $VmName -FQDN $TunnelVM.fqdns -ServerConfiguration $ServerConfiguration

    $AppRegistration = Update-ADApplication -ADApplication $ADApplication -TenantId $GraphContext.TenantId -BundleIds $BundleIds
    New-GeneratedXCConfig -bundle $BundleIds[0] -AppId $AppRegistration.AppId -TenantId $GraphContext.TenantId
    
    New-Profiles

    if (!$StayLoggedIn) {
        Logout
    }
}

Function Remove-ProfilesOnlyEnvironment {
    Test-Prerequisites
    Login
    Initialize-Variables

    if ($Platform -eq "ios" -or $Platform -eq "all") {
        Remove-IosProfiles -VmName $VmName
    }
    if ($Platform -eq "android" -or $Platform -eq "all") {
        Remove-AndroidProfiles -VmName $VmName
    }

    if (!$StayLoggedIn) {
        Logout
    }
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

if ($Delete) {
    if ($ProfilesOnly) {
        Remove-ProfilesOnlyEnvironment
    } else {
        Remove-TunnelEnvironment
    }
} elseif ($SprintSignoff) {
    New-SprintSignoffEnvironment
} else {
    if ($ProfilesOnly) {
        New-ProfilesOnlyEnvironment
    } elseif ($WithADFS) {
        New-ADFSEnvironment
    } else {
        New-TunnelEnvironment
    }
}
#endregion Main Functions