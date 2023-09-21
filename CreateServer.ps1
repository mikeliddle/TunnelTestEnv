[cmdletbinding(DefaultParameterSetName = "Create")]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "Create")]
    [Parameter(Mandatory = $true, ParameterSetName = "SprintSignoff")]
    [Parameter(Mandatory = $false, ParameterSetName = "ADFS")]
    [Parameter(Mandatory = $true, ParameterSetName = "Delete")]
    [Parameter(Mandatory = $true, ParameterSetName = "ProfilesOnly")]
    [string]$VmName,

    [Parameter(Mandatory = $false, ParameterSetName = "Create")]
    [Parameter(Mandatory = $false, ParameterSetName = "ADFS")]
    [Parameter(Mandatory = $false, ParameterSetName = "ProfilesOnly")]
    [string[]]$BundleIds = @(),

    [Parameter(Mandatory = $true, ParameterSetName = "Create")]
    [Parameter(Mandatory = $false, ParameterSetName = "ADFS")]
    [Parameter(Mandatory = $true, ParameterSetName = "ProfilesOnly")]
    [string]$GroupName,

    [Parameter(Mandatory = $false, ParameterSetName = "Create")]
    [Parameter(Mandatory = $false, ParameterSetName = "ADFS")]
    [Parameter(Mandatory = $false, ParameterSetName = "ProfilesOnly")]
    [ValidateSet("ios", "android", "all")]
    [string]$Platform = "all",

    [Parameter(Mandatory = $false, ParameterSetName = "Create")]
    [Parameter(Mandatory = $false, ParameterSetName = "ADFS")]
    [Parameter(Mandatory = $false, ParameterSetName = "SprintSignoff")]
    [ValidateSet("eastasia", "southeastasia", "centralus", "eastus", "eastus2", "westus", "westus3", "northcentralus", "southcentralus", "northeurope", "westeurope", "japanwest", "japaneast", "brazilsouth", "australiaeast", "australiasoutheast", "southindia", "centralindia", "westindia", "canadacentral", "canadaeast", "uksouth", "ukwest", "westcentralus", "westus2", "koreacentral", "koreasouth", "francecentral", "francesouth", "australiacentral", "australiacentral2")]
    [string]$Location = "westus",

    [Parameter(Mandatory = $false, ParameterSetName = "Create")]
    [Parameter(Mandatory = $false, ParameterSetName = "ADFS")]
    [ValidateSet("PE", "SelfHost", "OneDF")]
    [string]$Environment = "PE",

    [Parameter(Mandatory = $false, ParameterSetName = "Create")]
    [Parameter(Mandatory = $false, ParameterSetName = "SprintSignoff")]
    [Parameter(Mandatory = $false, ParameterSetName = "ADFS")]
    [string]$Email = "",

    [Parameter(Mandatory = $false, ParameterSetName = "Create")]
    [Parameter(Mandatory = $false, ParameterSetName = "ADFS")]
    [Parameter(Mandatory = $false, ParameterSetName = "ProfilesOnly")]
    [Parameter(Mandatory = $false, ParameterSetName = "SprintSignoff")]
    [string]$Username = "azureuser",

    [Parameter(Mandatory = $false, ParameterSetName = "Create")]
    [Parameter(Mandatory = $false, ParameterSetName = "ADFS")]
    [Parameter(Mandatory = $false, ParameterSetName = "SprintSignoff")]
    [string]$Size = "Standard_B2s",

    [Parameter(Mandatory = $false, ParameterSetName = "Create")]
    [Parameter(Mandatory = $false, ParameterSetName = "ADFS")]
    [Parameter(Mandatory = $false, ParameterSetName = "SprintSignoff")]
    [string]$ProxySize = "Standard_B2s",

    [Parameter(Mandatory = $false, ParameterSetName = "Create")]
    [Parameter(Mandatory = $false, ParameterSetName = "ADFS")]
    [Parameter(Mandatory = $false, ParameterSetName = "SprintSignoff")]
    [string]$Image = "Canonical:0001-com-ubuntu-server-jammy:22_04-lts:latest",
    
    [Parameter(Mandatory = $false, ParameterSetName = "Create")]
    [Parameter(Mandatory = $false, ParameterSetName = "ADFS")]
    [Parameter(Mandatory = $false, ParameterSetName = "SprintSignoff")]
    [switch]$RHEL8,

    [Parameter(Mandatory = $false, ParameterSetName = "Create")]
    [Parameter(Mandatory = $false, ParameterSetName = "ADFS")]
    [Parameter(Mandatory = $false, ParameterSetName = "SprintSignoff")]
    [switch]$RHEL7,

    [Parameter(Mandatory = $false, ParameterSetName = "Create")]
    [Parameter(Mandatory = $false, ParameterSetName = "ADFS")]
    [Parameter(Mandatory = $false, ParameterSetName = "SprintSignoff")]
    [switch]$Centos7,

    [Parameter(Mandatory = $false, ParameterSetName = "Create")]
    [Parameter(Mandatory = $false, ParameterSetName = "ADFS")]
    [Parameter(Mandatory = $false, ParameterSetName = "SprintSignoff")]
    [switch]$Simple,    

    [Parameter(Mandatory = $false, ParameterSetName = "Create")]
    [Parameter(Mandatory = $false, ParameterSetName = "ADFS")]
    [Parameter(Mandatory = $false, ParameterSetName = "ProfilesOnly")]
    [string]$ADApplication = "Generated MAM Tunnel",

    [Parameter(Mandatory = $false, ParameterSetName = "Create")]
    [Parameter(Mandatory = $false, ParameterSetName = "ADFS")]
    [Parameter(Mandatory = $false, ParameterSetName = "Delete")]
    [Parameter(Mandatory = $false, ParameterSetName = "SprintSignoff")]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false, ParameterSetName = "Create")]
    [Parameter(Mandatory = $false, ParameterSetName = "ADFS")]
    [Parameter(Mandatory = $false, ParameterSetName = "ProfilesOnly")]
    [Parameter(Mandatory = $false, ParameterSetName = "SprintSignoff")]
    [switch]$NoProxy,

    [Parameter(Mandatory = $false, ParameterSetName = "Create")]
    [Parameter(Mandatory = $false, ParameterSetName = "ProfilesOnly")]
    [switch]$NoPACUrl,

    [Parameter(Mandatory = $false, ParameterSetName = "Create")]
    [Parameter(Mandatory = $false, ParameterSetName = "ADFS")]
    [Parameter(Mandatory = $false, ParameterSetName = "SprintSignoff")]
    [pscredential[]]$AuthenticatedProxyCredentials = $null,

    [Parameter(Mandatory = $false, ParameterSetName = "Create")]
    [Parameter(Mandatory = $false, ParameterSetName = "SprintSignoff")]
    [Parameter(Mandatory = $false, ParameterSetName = "ProfilesOnly")]
    [switch]$NoPki,

    [Parameter(Mandatory = $false, ParameterSetName = "Create")]
    [Parameter(Mandatory = $false, ParameterSetName = "ADFS")]
    [Parameter(Mandatory = $false, ParameterSetName = "Delete")]
    [Parameter(Mandatory = $false, ParameterSetName = "SprintSignoff")]
    [pscredential]$VmTenantCredential,

    [Parameter(Mandatory = $false, ParameterSetName = "Create")]
    [Parameter(Mandatory = $false, ParameterSetName = "ADFS")]
    [Parameter(Mandatory = $false, ParameterSetName = "Delete")]
    [Parameter(Mandatory = $false, ParameterSetName = "ProfilesOnly")]
    [pscredential]$TenantCredential,

    [Parameter(Mandatory = $true, ParameterSetName = "Delete")]
    [switch]$Delete,

    [Parameter(Mandatory = $false, ParameterSetName = "SprintSignoff")]
    [switch]$DeleteSprintSignoff,

    [Parameter(Mandatory = $true, ParameterSetName = "ProfilesOnly")]
    [Parameter(Mandatory = $false, ParameterSetName = "Delete")]
    [switch]$ProfilesOnly,

    [Parameter(Mandatory = $false, ParameterSetName = "Create")]
    [Parameter(Mandatory = $false, ParameterSetName = "ADFS")]
    [Parameter(Mandatory = $false, ParameterSetName = "Delete")]
    [Parameter(Mandatory = $false, ParameterSetName = "ProfilesOnly")]
    [Parameter(Mandatory = $false, ParameterSetName = "SprintSignoff")]
    [switch]$StayLoggedIn,

    [Parameter(Mandatory = $false, ParameterSetName = "Create")]
    [Parameter(Mandatory = $false, ParameterSetName = "ADFS")]
    [Parameter(Mandatory = $false, ParameterSetName = "SprintSignoff")]
    [switch]$WithSSHOpen,

    [Parameter(Mandatory = $false, ParameterSetName = "Create")]
    [Parameter(Mandatory = $false, ParameterSetName = "ADFS")]
    [Parameter(Mandatory = $false, ParameterSetName = "ProfilesOnly")]
    [string]$PACUrl,

    [Parameter(Mandatory = $false, ParameterSetName = "Create")]
    [Parameter(Mandatory = $false, ParameterSetName = "ADFS")]
    [Parameter(Mandatory = $false, ParameterSetName = "ProfilesOnly")]
    [string[]]$IncludeRoutes = @(),

    [Parameter(Mandatory = $false, ParameterSetName = "Create")]
    [Parameter(Mandatory = $false, ParameterSetName = "ADFS")]
    [Parameter(Mandatory = $false, ParameterSetName = "ProfilesOnly")]
    [string[]]$ExcludeRoutes = @(),

    [Parameter(Mandatory = $false, ParameterSetName = "ADFS")]
    [switch]$WithADFS,

    [Parameter(Mandatory = $false, ParameterSetName = "SprintSignoff")]
    [switch]$SprintSignoff,

    [Parameter(Mandatory = $true, ParameterSetName = "ADFS")]
    [string]$DomainName,

    [Parameter(Mandatory = $false, ParameterSetName = "Create")]
    [Parameter(Mandatory = $false, ParameterSetName = "ADFS")]
    [Parameter(Mandatory = $false, ParameterSetName = "ProfilesOnly")]
    [Int32]$ListenPort = 443,

    [Parameter(Mandatory = $false, ParameterSetName = "Create")]
    [Parameter(Mandatory = $false, ParameterSetName = "ADFS")]
    [Parameter(Mandatory = $false, ParameterSetName = "SprintSignoff")]
    [switch]$UseInspection,

    [Parameter(Mandatory = $false, ParameterSetName = "Create")]
    [Parameter(Mandatory = $false, ParameterSetName = "ADFS")]
    [Parameter(Mandatory = $false, ParameterSetName = "SprintSignoff")]
    [switch]$UseAllowList,

    [Parameter(Mandatory = $false, ParameterSetName = "CreateContext")]
    [switch]$CreateFromContext,

    [Parameter(Mandatory = $false, ParameterSetName = "Create")]
    [Parameter(Mandatory = $false, ParameterSetName = "ADFS")]
    [Parameter(Mandatory = $false, ParameterSetName = "SprintSignoff")]
    [switch]$BootDiagnostics
)

#region Helper Functions

Function Test-Prerequisites {
    Write-Header "Checking prerequisites..."
    if (-Not ([bool](Get-Command -ErrorAction Ignore az))) {
        Write-Error "Please install azure cli`nhttps://learn.microsoft.com/en-us/cli/azure/"
        Exit 1
    }
    
    if (-Not $SprintSignoff) {
        if (-Not (Get-Module -ListAvailable -Name "Microsoft.Graph.Beta")) {
            Write-Header "Installing Microsoft.Graph..."
            Install-Module Microsoft.Graph -Force -MinimumVersion 2.6.1
            Install-Module Microsoft.Graph.Beta -Force -MinimumVersion 2.6.1
        }

        Import-Module Microsoft.Graph.Beta -MinimumVersion 2.6.1
    }

    if (-Not ($PSVersionTable.PSVersion.Major -ge 6)) {
        Write-Error "Please use PowerShell Core 6 or later."
        Exit 1
    }
}

Function Login {
    if (-Not $ProfilesOnly) {
        Login-Azure -VmTenantCredential $VmTenantCredential
    }
    
    if (-Not $SprintSignoff) {
        Login-Graph -TenantCredential $TenantCredential
    }
}

Function Logout {
    if (-Not $StayLoggedIn) {
        Write-Header "Logging out..."
        az logout
        if (-Not $SprintSignoff) {
            $script:Account = Disconnect-MgGraph
        }
    }
}

Function Initialize {
    $script:Context = [TunnelContext]::new()
    $script:Context.SubscriptionId = $SubscriptionId

    if ($CreateFromContext) {
        $script:Context = Get-Content -Path "context.json" | ConvertFrom-Json
        return
    }

    if ($IsLinux) {
        $script:Context.RunningOS = "linux"
    }
    elseif ($IsMacOS) {
        $script:Context.RunningOS = "osx"
    }
    else {
        $script:Context.RunningOS = "win"
    }

    if ($RHEL8) {
        $script:Context.Image = "RedHat:RHEL:8-LVM:latest"
    }
    elseif ($RHEL7) {
        $script:Context.Image = "RedHat:RHEL:7-LVM:latest"
    }
    elseif ($Centos7) {
        $script:Context.Image = "OpenLogic:CentOS:7_9:latest"
    }
    else {
        $script:Context.Image = "Canonical:0001-com-ubuntu-server-jammy:22_04-lts:latest"
    }
    
    if ($NoPki) {
        $script:Context.NoPki = $true
    }
    else {
        $script:Context.NoPki = $false
    }

    if ($NoProxy) {
        $script:Context.NoProxy = $true
    }
    else {
        $script:Context.NoProxy = $false
    }

    if ($Simple) {
        $script:Context.NoProxy = $true
        $script:Context.NoPki = $true
    }

    if ($BootDiagnostics) {
        $script:Context.BootDiagnostics = $true
    }
    else {
        $script:Context.BootDiagnostics = $false
    }
}

Function Initialize-Variables {
    $script:Context.VmName = $VmName = $VmName.ToLower()    # Force $VmName to lower case since we don't want $VmName and $Context.VmName to be different.
    $script:Context.ProxyVmName = $Context.VmName + "-server"
    $script:Context.Location = $Location
    $script:Context.Environment = $Environment
    $script:Context.Username = $Username
    $script:Context.Size = $Size
    $script:Context.ProxySize = $ProxySize
    $script:Context.Platform = $Platform
    $script:Context.BundleIds = $BundleIds
    $script:Context.Username = $Username
    $script:Context.AuthenticatedProxyCredentials = $AuthenticatedProxyCredentials
    $script:Context.IncludeRoutes = $IncludeRoutes
    $script:Context.ExcludeRoutes = $ExcludeRoutes
    $script:Context.ListenPort = $ListenPort
    $script:Context.NoProxy = $NoProxy
    $script:Context.NoPACUrl = $NoPACUrl
    $script:Context.UseInspection = $UseInspection
    $script:Context.UseAllowList = $UseAllowList

    $script:Context.Account = (az account show | ConvertFrom-Json)
    $script:Context.Subscription = $Context.Account.id
    if ($Email -eq "") {
        Write-Header "Email not provided. Detecting email..."
        $script:Context.Email = $Context.Account.user.name
        Write-Host "Detected your email as '$($Context.Email)'"
    }
    else {
        $script:Context.Email = $Email
    }

    $script:Context.ResourceGroup = "$VmName-group"
    $script:Context.SSHKeyPath = "$HOME/.ssh/$VmName"

    $script:Context.GraphContext = Get-MgContext

    $script:Context.TunnelFQDN = "$VmName.$Location.cloudapp.azure.com"
    $script:Context.ServiceFQDN = "$VmName-server.$Location.cloudapp.azure.com"

    if ($PACUrl -eq "") {
        $script:Context.PACUrl = "http://$($Context.TunnelFQDN)/tunnel.pac"
    }
    else {
        $script:Context.PACUrl = $PACUrl
    }

    if (-Not $Delete -And -Not $SprintSignoff) {
        # We only need a group name for the create and profile flows
        $script:Context.Group = Get-MgGroup -Filter "displayName eq '$GroupName'"
        if (-Not $Context.Group) {
            Write-Error "Could not find group named '$GroupName'"
            Exit -1
        }
        $script:Context.GroupName = $GroupName
    }
}

Function New-Profiles {
    if ($Context.NoProxy) {
        $script:Context.ProxyHostname = ""
        $script:Context.ProxyPort = ""
        $script:Context.PACUrl = ""
    }
    else {
        # TODO: If $TunnelVm doesn't resolve (due to being profiles only), then fetch it from the az cli
        $script:Context.ProxyHostname = $Context.TunnelFQDN
        $script:Context.ProxyPort = "3128"
        $script:Context.PACUrl = "http://$($Context.TunnelFQDN)/tunnel.pac"
    }

    if ($Context.Platform -eq "ios" -or $Context.Platform -eq "all") {
        New-IOSProfiles
    }
    if ($Context.Platform -eq "android" -or $Context.Platform -eq "all") {
        New-AndroidProfiles
    }
}
#endregion Helper Functions

#region Main Functions
Function New-TunnelEnvironment {
    Login
    if (!$CreateFromContext) {
        Initialize-Variables
    }

    New-SSHKeys

    New-ServicePrincipal

    New-ResourceGroup
    New-Network
    New-TunnelVM
    New-ServiceVM
    
    $script:Context.ProxyIP = Get-ProxyPrivateIP -VmName $ServiceVMName

    if (-Not $Simple) {
        New-AdvancedNetworkRules
    }
    else {
        New-NetworkRules
    }

    if (!$Context.NoProxy) {
        # Setup Proxy server on Service VM
        Initialize-Proxy
        Invoke-ProxyScript
    }

    # Create Certificates
    New-BasicPki
    # Setup DNS
    New-DnsServer
    # Setup WebServers
    Set-Endpoints
    Set-Content -Path "context.json" -Value (ConvertTo-Json $Context) -Force
    New-NginxSetup

    Update-RebootVM

    # Create Tunnel Configuration
    New-TunnelConfiguration
    New-TunnelSite

    # Enroll Tunnel Agent
    New-TunnelAgent -TenantCredential $TenantCredential

    Initialize-TunnelServer
    Initialize-SetupScript
    Invoke-SetupScript

    Update-PrivateDNSAddress

    $AppRegistration = Update-ADApplication
    New-GeneratedXCConfig -AppId $AppRegistration.AppId

    New-Profiles

    New-Summary
    
    if (!$StayLoggedIn) {
        Logout
    }
}

Function New-SprintSignoffEnvironment {
    Login-Azure -VmTenantCredential $VmTenantCredential

    if (!$CreateFromContext) {
        Initialize-Variables
    }

    New-SSHKeys

    New-ResourceGroup
    New-Network
    New-TunnelVM
    New-ServiceVM

    $script:Context.ProxyIP = Get-ProxyPrivateIP -VmName $ServiceVMName

    if (-Not $Simple) {
        New-AdvancedNetworkRules
    }
    else {
        New-NetworkRules
    }

    if (!$Context.NoProxy) {
        # Setup Proxy server on Service VM
        Initialize-Proxy
        Invoke-ProxyScript
    }

    # Create Certificates
    New-BasicPki
    # Setup DNS
    New-DnsServer
    # Setup WebServers
    Set-Endpoints
    Set-Content -Path "context.json" -Value (ConvertTo-Json $Context) -Force
    New-NginxSetup

    Update-RebootVM

    New-Summary

    if (!$StayLoggedIn) {
        az logout
    }
}

Function New-Summary {
    Write-Success "=====================Summary====================="
    
    Write-Success "VM Username: $($Context.Username)"
    Write-Success "VM SSH Key: $($Context.SSHKeyPath)"
    Write-Success ""
    Write-Success "Tunnel Server Address: $($Context.TunnelFQDN)"
    Write-Success ""

    if (!$SprintSignoff) {
        Write-Success "Profiles targeted to $($Context.GroupName)"
        Write-Success ""
    }

    if ($Context.BundleIds.Count -gt 0) {
        Write-Success "Targeted App Bundle IDs for MAM: $($Context.BundleIds -join ', ')"
        Write-Success ""
    }

    if ($Context.IncludeRoutes.Count -gt 0) {
        Write-Success "Routes to include: $($Context.IncludeRoutes -join ', ')"
        Write-Success ""
    }

    if ($Context.ExcludeRoutes.Count -gt 0) {
        Write-Success "Routes to exclude: $($Context.ExcludeRoutes -join ', ')"
        Write-Success ""
    }

    if (!$Context.NoProxy) {
        Write-Success "PAC URL: http://$($Context.TunnelFQDN)/tunnel.pac"
        Write-Success "Proxy Hostname: proxy.$($Context.TunnelFQDN)"
        Write-Success "Proxy Port: 3128"
        Write-Success ""
        Write-Success "These URLS Bypass the proxy when using a PAC file: "
        Write-Success "  www.google.com"
        Write-Success "  excluded.$($Context.TunnelFQDN)"
        Write-Success ""
        
        if ($Context.UseInspection) {
            Write-Success "Proxy is configured for TLS Inspection"
            Write-Success ""
        }

        if ($Context.UseAllowList) {
            Write-Success "Only the following URLs are allowed through the proxy:"
            $Allowlist = Get-Content -Path "proxy\allowlist.tmp"
            Write-Success $Allowlist
            Write-Success ""
        }
    }

    Write-Success "DNS Server: $($Context.ProxyIP)"
    Write-Success "Default Search Suffix: $($Context.TunnelFQDN)"
    Write-Success ""
    Write-Success "Internal Endpoints: "
    Write-Success "  http://$($Context.ProxyIP) - most stable for reachability check"
    Write-Success "  https://webapp or https://webapp.$($Context.TunnelFQDN) - When using a proxy, this should show your IP as $($Context.ProxyIP)"
    Write-Success "  https://excluded or https://excluded.$($Context.TunnelFQDN) - When using a proxy, this should show you a different IP than above"
    Write-Success "  https://$($Context.TunnelFQDN) - This endpoint is secured using LetsEncrypt when accessed through the VPN."
    Write-Success "  https://cert or https://cert.$($Context.TunnelFQDN) - This endpoint requires a client certificate"
    Write-Success "  https://optionalcert or https://optionalcert.$($Context.TunnelFQDN) - This endpoint prompts for a client certificate but does not require it"
    Write-Success "  https://untrusted or https://untrusted.$($Context.TunnelFQDN) - This endpoint should give you a certificate error"

    if ($SprintSignoff) {
        Write-Success ""
        Write-Success "Trusted Certificate Path: cacert.pem.tmp"
        Write-Success "You will need to rename and upload that certificate to Intune as a trusted certificate."
        Write-Success "The certificate is also printed out above."
    }

    Write-Success "================================================="

    Set-Content -Path "context.json" -Value (ConvertTo-Json $Context) -Force
}

Function Remove-TunnelEnvironment {
    Login
    Initialize-Variables
    
    Remove-ResourceGroup -resourceGroup "$VmName-group"
    Remove-SSHKeys -SSHKeyPath "$HOME/.ssh/$VmName" -TunnelFQDN "$VmName.$Location.cloudapp.azure.com" -ServiceFQDN "$VmName-server.$Location.cloudapp.azure.com"

    if (-Not $SprintSignoff) {
        Remove-IosProfiles -VmName $VmName
        Remove-AndroidProfiles -VmName $VmName

        Remove-TunnelServers -SiteName $VmName
        Remove-TunnelSite -SiteName $VmName
        Remove-TunnelConfiguration -ServerConfigurationName $VmName
    }

    Remove-TempFiles

    if (!$StayLoggedIn) {
        Logout
    }
}

Function New-ProfilesOnlyEnvironment {
    Test-Prerequisites
    Login
    Initialize-Variables

    $ServerConfiguration = New-TunnelConfiguration
    $TunnelSite = New-TunnelSite

    $AppRegistration = Update-ADApplication
    New-GeneratedXCConfig -AppId $AppRegistration.AppId
    
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
    }
    else {
        Remove-TunnelEnvironment
    }
}
elseif ($DeleteSprintSignoff) {
    Remove-TunnelEnvironment
}
elseif ($SprintSignoff) {
    New-SprintSignoffEnvironment
}
else {
    if ($ProfilesOnly) {
        New-ProfilesOnlyEnvironment
    }
    elseif ($WithADFS) {
        New-ADFSEnvironment
    }
    else {
        New-TunnelEnvironment
    }
}
#endregion Main Functions