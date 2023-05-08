[cmdletbinding(DefaultParameterSetName="Create")]
param(
    [Parameter(Mandatory=$true, ParameterSetName="Create")]
    [Parameter(Mandatory=$true, ParameterSetName="Delete")]
    [Parameter(Mandatory=$true, ParameterSetName="ProfilesOnly")]
    [string]$VmName,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ProfilesOnly")]
    [string[]]$BundleIds=@(),

    [Parameter(Mandatory=$true, ParameterSetName="Create")]
    [Parameter(Mandatory=$true, ParameterSetName="ProfilesOnly")]
    [string]$GroupName,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ProfilesOnly")]
    [ValidateSet("ios","android","all")]
    [string]$Platform="all",

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [ValidateSet("eastasia","southeastasia","centralus","eastus","eastus2","westus","westus3","northcentralus","southcentralus","northeurope","westeurope","japanwest","japaneast","brazilsouth","australiaeast","australiasoutheast","southindia","centralindia","westindia","canadacentral","canadaeast","uksouth","ukwest","westcentralus","westus2","koreacentral","koreasouth","francecentral","francesouth","australiacentral","australiacentral2")]
    [string]$Location="westus",

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [ValidateSet("PE","SelfHost","OneDF")]
    [string]$Environment="PE",

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [string]$Email="",

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ProfilesOnly")]
    [string]$Username="azureuser",

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [string]$Size = "Standard_B2s",

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [string]$ProxySize = "Standard_B2s",

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [string]$Image = "Canonical:0001-com-ubuntu-server-focal:20_04-lts:latest", #"RedHat:RHEL:8-LVM:latest"
    
    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ProfilesOnly")]
    [string]$ADApplication = "Generated MAM Tunnel",

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="Delete")]
    [string]$SubscriptionId,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ProfilesOnly")]
    [switch]$NoProxy,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [switch]$UseEnterpriseCa,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="Delete")]
    [pscredential]$VmTenantCredential,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="Delete")]
    [Parameter(Mandatory=$false, ParameterSetName="ProfilesOnly")]
    [pscredential]$TenantCredential,

    [Parameter(Mandatory=$true, ParameterSetName="Delete")]
    [switch]$Delete,

    [Parameter(Mandatory=$true, ParameterSetName="ProfilesOnly")]
    [switch]$ProfilesOnly,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="Delete")]
    [Parameter(Mandatory=$false, ParameterSetName="ProfilesOnly")]
    [switch]$StayLoggedIn,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [switch]$WithSSHOpen,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ProfilesOnly")]
    [string]$PACUrl,

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ProfilesOnly")]
    [string[]]$IncludeRoutes=@(),

    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="ProfilesOnly")]
    [string[]]$ExcludeRoutes=@()
)

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

#region Helper Functions
Function Write-Header([string]$Message) {
    Write-Host $Message -ForegroundColor Cyan
}

Function Write-Success([string]$Message) {
    Write-Host $Message -ForegroundColor Green
}

Function New-SSHKeys{
    Write-Header "Generating new RSA 4096 SSH Key"
    ssh-keygen -t rsa -b 4096 -f $SSHKeyPath -q -N ""
}

Function New-RandomPassword {
    # Define the character sets to use for the password
    $lowercaseLetters = "abcdefghijklmnopqrstuvwxyz"
    $uppercaseLetters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $numbers = "0123456789"
    $specialCharacters = "!@#$%&*()_+-=[]{};:,./<>?"

    # Combine the character sets into a single string
    $validCharacters = $lowercaseLetters + $uppercaseLetters + $numbers + $specialCharacters

    # Define the length of the password
    $passwordLength = 16

    # Generate the password
    $password = ""
    for ($i = 0; $i -lt $passwordLength; $i++) {
        # Get a random index into the valid characters string
        $randomIndex = Get-Random -Minimum 0 -Maximum $validCharacters.Length

        # Add the character at the random index to the password
        $password += $validCharacters[$randomIndex]
    }

    # Output the password
    return $password
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
        Write-Header "Logging into Azure..."
        if (-Not $VmTenantCredential) {
            Write-Header "Select the account to manage the VM."
            az login --only-show-errors | Out-Null
        } else {
            az login -u $VmTenantCredential.UserName -p $VmTenantCredential.GetNetworkCredential().Password --only-show-errors | Out-Null
        }

        if ($SubscriptionId) {
            Write-Header "Setting subscription to $SubscriptionId"
            az account set --subscription $SubscriptionId | Out-Null
        } else {
            $accounts = (az account list | ConvertFrom-Json)
            if ($accounts.Count -gt 1) {
                foreach ($account in $accounts) {
                    Write-Host "$($account.name) - $($account.id)"
                }
                $SubscriptionId = Read-Host "Please specify a subscription id: "
                Write-Header "Setting subscription to $SubscriptionId"
                az account set --subscription $SubscriptionId | Out-Null
            }
        }
    }
    
    Write-Header "Logging into graph..."
    if (-Not $TenantCredential) {    
        Write-Header "Select the account to manage the profiles."
        $script:JWT = Invoke-Expression "mstunnel-utils/mstunnel-$RunningOS.exe JWT"
    } else {
        $script:JWT = Invoke-Expression "mstunnel-utils/mstunnel-$RunningOS.exe JWT $($TenantCredential.UserName) $($TenantCredential.GetNetworkCredential().Password)"
    }
    
    if (-Not $JWT) {
        Write-Error "Could not get JWT for account"
        Exit -1
    }

    Connect-MgGraph -AccessToken $script:JWT | Out-Null
    
    # Switch to beta since most of our endpoints are there
    Select-MgProfile -Name "beta"    
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

#region Azure Functions
Function New-ResourceGroup {
    Write-Header "Checking for resource group '$resourceGroup'..."
    if ([bool](az group show --name $resourceGroup 2> $null)) {
        Write-Error "Group '$resourceGroup' already exists"
        exit -1
    }
    
    Write-Header "Creating resource group '$resourceGroup'..."
    az group create --location $location --name $resourceGroup --only-show-errors | ConvertFrom-Json
}

Function Remove-ResourceGroup {
    Write-Header "Checking for resource group '$resourceGroup'..."
    if ([bool](az group show --name $resourceGroup 2> $null)) {
        Write-Header "Deleting resource group '$resourceGroup'..."
        az group delete --name $resourceGroup --yes --no-wait
    } else {
        Write-Host "Group '$resourceGroup' does not exist"
    }
}

Function New-TunnelVM {
    Write-Header "Creating VM '$VmName'..."
    $vmdata = az vm create --location $location --resource-group $resourceGroup --name $VmName --image $Image --size $Size --ssh-key-values "$SSHKeyPath.pub" --public-ip-address-dns-name $VmName --admin-username $Username --only-show-errors | ConvertFrom-Json
    $script:FQDN = $vmdata.fqdns
    Write-Host "DNS is '$FQDN'"
}

Function New-NetworkRules {
    Write-Header "Creating network rules..."
    
    if ($WithSSHOpen)
    {
        az network nsg rule create --resource-group $resourceGroup --nsg-name "$($VmName)NSG" -n SSHIN --priority 100 --source-address-prefixes '*' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 22 --access Allow --protocol Tcp --description "Allow SSH" > $null
    }
    
    az network nsg rule create --resource-group $resourceGroup --nsg-name "$($VmName)NSG" -n HTTPIN --priority 101 --source-address-prefixes 'Internet' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 443 --access Allow --protocol '*' --description "Allow HTTP" > $null
}

Function Move-SSHKeys{
    Write-Header "Moving generated SSH keys..."
    Move-Item -Path ~/.ssh/id_rsa -Destination $sshKeyPath -Force
    Move-Item -Path ~/.ssh/id_rsa.pub -Destination ~/.ssh/$VmName.pub -Force    
}

Function Remove-SSHKeys{
    Write-Header "Deleting SSH keys..."
    if (Test-Path $sshKeyPath) {
        Remove-Item -Path $sshKeyPath -Force
    } else {
        Write-Host "Key at path '$sshKeyPath' does not exist."
    }

    if (Test-Path ~/.ssh/$VmName.pub) {
        Remove-Item -Path ~/.ssh/$VmName.pub -Force 
    } else {
        Write-Host "Key at path '~/.ssh/$VmName.pub' does not exist."
    }
}
#endregion Azure Functions

#region Proxy Functions
Function New-ProxyVM {
    Write-Header "Creating VM '$VmName-squid'..."
    $script:ProxyVMData = az vm create --location $location --resource-group $resourceGroup --name "$VmName-squid" --image $Image --size $ProxySize --ssh-key-values "$SSHKeyPath.pub" --public-ip-address-dns-name "$VmName-squid" --admin-username $Username --only-show-errors | ConvertFrom-Json
}

Function Initialize-Proxy {
    $configFile = Join-Path $pwd -ChildPath "proxy" -AdditionalChildPath "squid.conf"
    $allowlistFile = Join-Path $pwd -ChildPath "proxy" -AdditionalChildPath "allowlist"
    $proxyScript = Join-Path $pwd -ChildPath "scripts" -AdditionalChildPath "proxySetup.sh"
    $pacFile = Join-Path $pwd -ChildPath "nginx_data" -AdditionalChildPath "tunnel.pac"

    (Get-Content $configFile) -replace "##DOMAIN_NAME##","$FQDN" | out-file "$configFile.tmp"
    (Get-Content $allowlistFile) -replace "##DOMAIN_NAME##","$FQDN" | out-file "$allowlistFile.tmp"

    $proxyBypassNames = ("www.google.com", "excluded.$($FQDN)")
    foreach ($name in $proxyBypassNames) {
        (Get-Content $pacFile) -replace "// PROXY_BYPASS_NAMES","`nif (shExpMatch(host, '$($name)')) { return bypass; } // PROXY_BYPASS_NAMES" | out-file "$pacFile.tmp"
    }

    # Replace CR+LF with LF
    $text = [IO.File]::ReadAllText($proxyScript) -replace "`r`n", "`n"
    [IO.File]::WriteAllText($proxyScript, $text)

    # Replace CR with LF
    $text = [IO.File]::ReadAllText($proxyScript) -replace "`r", "`n"
    [IO.File]::WriteAllText($proxyScript, $text)

    Write-Header "Copying proxy script to remote server..."

    scp -i $sshKeyPath -o "StrictHostKeyChecking=no" "$configFile.tmp" "$($username)@$("$($ProxyVMData.fqdns)"):~/" > $null
    scp -i $sshKeyPath -o "StrictHostKeyChecking=no" "$allowlistFile.tmp" "$($username)@$("$($ProxyVMData.fqdns)"):~/" > $null
    scp -i $sshKeyPath -o "StrictHostKeyChecking=no" "$proxyScript" "$($username)@$("$($ProxyVMData.fqdns)"):~/" > $null

    scp -i $sshKeyPath -o "StrictHostKeyChecking=no" "$pacFile.tmp" "$($username)@$("$FQDN"):~/" > $null

    Write-Header "Marking proxy scripts as executable..."
    ssh -i $sshKeyPath -o "StrictHostKeyChecking=no" "$($username)@$($ProxyVMData.fqdns)" "chmod +x ~/proxySetup.sh"
}

Function Invoke-ProxyScript {
    Write-Header "Connecting into remote server..."
    ssh -i $sshKeyPath -o "StrictHostKeyChecking=no" "$($username)@$("$($ProxyVMData.fqdns)")" "sudo su -c './proxySetup.sh'"
}
#endregion Proxy Functions

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
        cp ../tunnel.pac nginx_data/tunnel.pac

        git submodule update --init >> install.log 2>&1

        chmod +x setup.exp envSetup.sh exportCert.sh setup-expect.sh
        
        PUBLIC_IP=`$(curl ifconfig.me)
        sed -i.bak -e "s/SERVER_NAME=/SERVER_NAME=$ServerName/" -e "s/DOMAIN_NAME=/DOMAIN_NAME=$FQDN/" -e "s/SERVER_PUBLIC_IP=/SERVER_PUBLIC_IP=`$PUBLIC_IP/" -e "s/EMAIL=/EMAIL=$Email/" -e "s/SITE_ID=/SITE_ID=$($Site.Id)/" vars
        export SETUP_ARGS="-i$(if ($UseEnterpriseCa) {"e"})"
        
        ./setup-expect.sh
        
        expect -f ./setup.exp
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

#region Tunnel Components
Function New-TunnelConfiguration {
    Write-Header "Creating Server Configuration..."
    $script:ServerConfiguration = Get-MgDeviceManagementMicrosoftTunnelConfiguration -Filter "displayName eq '$VmName'" -Limit 1
    if ($ServerConfiguration) {
        Write-Host "Already found Server Configuration named '$VmName'"
    } else {
        $ListenPort = 443
        $DnsServers = @("8.8.8.8")
        $Network = "169.254.0.0/16"
        $script:ServerConfiguration = New-MgDeviceManagementMicrosoftTunnelConfiguration -DisplayName $VmName -ListenPort $ListenPort -DnsServers $DnsServers -Network $Network -AdvancedSettings @() -DefaultDomainSuffix "" -RoleScopeTagIds @("0") -RouteExcludes $ExcludeRoutes -RouteIncludes $IncludeRoutes -SplitDns @()    
    }
}

Function Remove-TunnelConfiguration {
    Write-Header "Deleting Server Configuration..."
    $script:ServerConfiguration = Get-MgDeviceManagementMicrosoftTunnelConfiguration -Filter "displayName eq '$VmName'" -Limit 1
    if($ServerConfiguration) {
        Remove-MgDeviceManagementMicrosoftTunnelConfiguration -MicrosoftTunnelConfigurationId $ServerConfiguration.Id
    } else {
        Write-Host "Server Configuration '$VmName' does not exist."
    }
}

Function Update-PrivateDNSAddress {
    Write-Header "Updating server configuration private DNS..."
    if ($Image.Contains("RHEL"))
    {
        $DNSPrivateAddress = ssh -i $sshKeyPath -o "StrictHostKeyChecking=no" "$($username)@$($FQDN)" 'sudo podman container inspect -f "{{ .NetworkSettings.Networks.podman.IPAddress }}" unbound'
    }
    else
    {
        $DNSPrivateAddress = ssh -i $sshKeyPath -o "StrictHostKeyChecking=no" "$($username)@$($FQDN)" 'sudo docker container inspect -f "{{ .NetworkSettings.Networks.bridge.IPAddress }}" unbound'
    }
    $newServers = $DNSPrivateAddress #+ $ServerConfiguration.DnsServers
    Update-MgDeviceManagementMicrosoftTunnelConfiguration -DnsServers $newServers -MicrosoftTunnelConfigurationId $ServerConfiguration.Id
    $script:ServerConfiguration = Get-MgDeviceManagementMicrosoftTunnelConfiguration -MicrosoftTunnelConfigurationId $ServerConfiguration.Id
}

Function New-TunnelAgent{
    if (-Not $TenantCredential) {
        $script:JWT = Invoke-Expression "mstunnel-utils/mstunnel-$RunningOS.exe Agent $($Site.Id)"
    } else {
        $script:JWT = Invoke-Expression "mstunnel-utils/mstunnel-$RunningOS.exe Agent $($Site.Id) $($TenantCredential.UserName) $($TenantCredential.GetNetworkCredential().Password)"
    }
}

Function New-TunnelSite {
    Write-Header "Creating Site..."
    $script:Site = Get-MgDeviceManagementMicrosoftTunnelSite -Filter "displayName eq '$VmName'" -Limit 1
    if ($Site) {
        Write-Host "Already found Site named '$VmName'"
    } else {
        $script:Site = New-MgDeviceManagementMicrosoftTunnelSite -DisplayName $VmName -PublicAddress $FQDN -MicrosoftTunnelConfiguration @{id=$ServerConfiguration.id} -RoleScopeTagIds @("0") -UpgradeAutomatically    
    }
}

Function Remove-TunnelSite {
    Write-Header "Deleting Site..."
    $script:Site = Get-MgDeviceManagementMicrosoftTunnelSite -Filter "displayName eq '$VmName'" -Limit 1
    if($Site) {
        Remove-MgDeviceManagementMicrosoftTunnelSite -MicrosoftTunnelSiteId $Site.Id
    } else {
        Write-Host "Site '$VmName' does not exist."
    }
}

Function Remove-TunnelServers {
    Write-Header "Deleting Servers..."
    $script:Site = Get-MgDeviceManagementMicrosoftTunnelSite -Filter "displayName eq '$VmName'" -Limit 1
    if($Site){
        $servers = Get-MgDeviceManagementMicrosoftTunnelSiteMicrosoftTunnelServer -MicrosoftTunnelSiteId $Site.Id
        $servers | ForEach-Object {
            Write-Header "Deleting '$($_.DisplayName)'..."
            Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/beta/deviceManagement/microsoftTunnelSites/$($Site.Id)/microsoftTunnelServers/$($_.Id)"
        }
    } else {
        Write-Host "No site found for '$VmName', so no servers will be deleted."
    }
}

#endregion Tunnel Components

#region iOS MAM Specific Functions
Function Update-ADApplication {
    $script:App = Get-MgApplication -Filter "displayName eq '$ADApplication'" -Limit 1
    if($App) {
        Write-Success "Client Id: $($App.AppId)"
        Write-Success "Tenant Id: $($GraphContext.TenantId)"

        if ($BundleIds -and $BundleIds.Count -gt 0){
            Write-Header "Found AD Application '$ADApplication'..."
            $uris = [System.Collections.ArrayList]@()
            foreach ($bundle in $BundleIds) {
                $uri1 = "msauth://code/msauth.$bundle%3A%2F%2Fauth"
                $uri2 = "msauth.$($bundle)://auth"
                if(-Not $App.PublicClient.RedirectUris.Contains($uri1)) {
                    Write-Host "Missing Uri '$uri1' for '$bundle', preparing to add."
                    $uris.Add($uri1) | Out-Null
                }
                if(-Not $App.PublicClient.RedirectUris.Contains($uri2)) {
                    Write-Host "Missing Uri '$uri2' for '$bundle', preparing to add."
                    $uris.Add($uri2) | Out-Null
                }
            }
            if($uris.Count -gt 0) {
                $newUris = $App.PublicClient.RedirectUris + $uris
                $PublicClient = @{
                    RedirectUris = $newUris
                }

                Write-Header "Updating Redirect URIs..."
                Update-MgApplication -ApplicationId $App.Id -PublicClient $PublicClient
            }
        }
    } else {
        Write-Header "Creating AD Application '$ADApplication'..."
        $RequiredResourceAccess = @(
            @{
                ResourceAppId = "00000003-0000-0000-c000-000000000000"
                ResourceAccess = @(
                    @{
                        Id = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"
                        Type = "Scope"
                    }
                )
            }
            @{
                ResourceAppId = "0a5f63c0-b750-4f38-a71c-4fc0d58b89e2"
                ResourceAccess = @(
                    @{
                        Id = "3c7192af-9629-4473-9276-d35e4e4b36c5"
                        Type = "Scope"
                    }
                )
            }
            @{
                ResourceAppId = "3678c9e9-9681-447a-974d-d19f668fcd88"
                ResourceAccess = @(
                    @{
                        Id = "eb539595-3fe1-474e-9c1d-feb3625d1be5"
                        Type = "Scope"
                    }
                )
            }
        )
        
        $OptionalClaims = @{
            IdToken = @()
            AccessToken = @(
                @{
                    Name = "acct"
                    Essential = $false
                    AdditionalProperties = @()
                }
            )
            Saml2Token = @()
        }
        $uris = [System.Collections.ArrayList]@()
        foreach ($bundle in $BundleIds) {
            $uris.Add("msauth://code/msauth.$bundle%3A%2F%2Fauth") | Out-Null
            $uris.Add("msauth.$($bundle)://auth") | Out-Null
        }
        $PublicClient = @{
            RedirectUris = $uris
        }
        
        $script:App = New-MgApplication -DisplayName $ADApplication -RequiredResourceAccess $RequiredResourceAccess -OptionalClaims $OptionalClaims -PublicClient $PublicClient -SignInAudience "AzureADMyOrg"

        Write-Success "Client Id: $($App.AppId)"
        Write-Success "Tenant Id: $($GraphContext.TenantId)"

        Write-Header "You will need to grant consent. Opening browser in 15 seconds..."
        Start-Sleep -Seconds 15
        Start-Process "https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/CallAnAPI/appId/$($App.AppId)/isMSAApp~/false"
    }
}

Function New-GeneratedXCConfig {
    $bundle = $BundleIds[0]
    $Content = @"
CONFIGURED_BUNDLE_IDENTIFIER = $bundle
CONFIGURED_TENANT_ID = $($GraphContext.TenantId)
CONFIGURED_CLIENT_ID = $($App.AppId)
"@
    Set-Content -Path "./Generated.xcconfig" -Value $Content -Force
}
#endregion iOS MAM Specific Functions

#region Profile Functions
Function New-IosAppProtectionPolicy{
    $DisplayName = "ios-$VmName-Protection"
    $script:IosAppProtectionPolicy = Get-MgDeviceAppManagementiOSManagedAppProtection -Filter "displayName eq '$DisplayName'" -Limit 1
    if ($IosAppProtectionPolicy) {
        Write-Host "Already found App Protection policy named '$DisplayName'"
    } else {
        Write-Header "Creating App Protection policy '$DisplayName'..."
        $script:IosAppProtectionPolicy = New-MgDeviceAppManagementiOSManagedAppProtection -DisplayName $DisplayName
        Write-Header "Targeting bundles to '$DisplayName'..."
        $targetedApps = $BundleIds | ForEach-Object { 
            @{
                mobileAppIdentifier = @{
                    "@odata.type" = "#microsoft.graph.iosMobileAppIdentifier"
                    bundleId = $_
                }
            }
        }
        if (-not ($targetedApps -is [array])) {
            $targetedApps = @($targetedApps)
        }
        $body = @{
            apps = $targetedApps
            appGroupType = "selectedPublicApps"
        } | ConvertTo-Json -Depth 10
        
        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceAppManagement/iosManagedAppProtections('$($IosAppProtectionPolicy.Id)')/targetApps" -Body $Body
        
        Write-Header "Assigning App Protection policy '$DisplayName' to group '$($Group.DisplayName)'..."
        $Body = @{
            assignments = @(
                @{
                    target = @{
                        groupId = $Group.Id
                        deviceAndAppManagementAssignmentFilterId = $null
                        deviceAndAppManagementAssignmentFilterType = "none"
                        "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                    }
                }
            )
        } | ConvertTo-Json -Depth 10

        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceAppManagement/iosManagedAppProtections('$($IosAppProtectionPolicy.Id)')/assign" -Body $Body
    }
}

Function Remove-IosAppProtectionPolicy{
    $DisplayName = "ios-$VmName-Protection"
    Write-Header "Deleting App Protection Policy '$DisplayName'..."
    $script:IosAppProtectionPolicy = Get-MgDeviceAppManagementiOSManagedAppProtection -Filter "displayName eq '$DisplayName'" -Limit 1
    if($IosAppProtectionPolicy) {
        Remove-MgDeviceAppManagementiOSManagedAppProtection -IosManagedAppProtectionId $IosAppProtectionPolicy.Id
    } else {
        Write-Host "App Protection Policy '$DisplayName' does not exist."
    }
}

Function New-IosTrustedRootPolicy {
    $DisplayName = "ios-$VmName-TrustedRoot"
    $script:IosTrustedRootPolicy = Get-MgDeviceManagementDeviceConfiguration -Filter "displayName eq '$DisplayName'"
    if($IosTrustedRootPolicy) {
        Write-Host "Already found Trusted Root policy named '$DisplayName'"
    } else {
        $cerFileName = "./$([System.Guid]::NewGuid().ToString())$VmName.pem"
        try{
            Write-Header "Copying root certificate locally..."
            scp -i $sshKeyPath -o "StrictHostKeyChecking=no" "$($username)@$($FQDN):/etc/pki/tls/certs/cacert.pem" $cerFileName > $null 
            $certValue = (Get-Content $cerFileName).Replace("-----BEGIN CERTIFICATE-----","").Replace("-----END CERTIFICATE-----","") -join ""
            
            $Body = @{
                "@odata.type" = "#microsoft.graph.iosTrustedRootCertificate"
                displayName = $DisplayName
                id = [System.Guid]::Empty.ToString()
                roleScopeTagIds = @("0")
                certFileName = "$VmName.cer"
                trustedRootCertificate = $certValue
            } | ConvertTo-Json -Depth 10

            Write-Header "Creating Trusted Root Policy..."
            $script:IosTrustedRootPolicy = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations" -Body $Body
            # re-fetch the policy so the root certificate is included
            $script:IosTrustedRootPolicy = Get-MgDeviceManagementDeviceConfiguration -Filter "displayName eq '$DisplayName'"
            
            $Body = @{
                "assignments" = @(@{
                    "target" = @{
                        "groupId" = $Group.Id
                        "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                    }
                })
            }
        
            Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($IosTrustedRootPolicy.Id)/assign" -Body $Body
        } finally {
            Remove-Item $cerFileName
        } 
    }
}

Function Remove-IosTrustedRootPolicy{
    $DisplayName = "ios-$VmName-TrustedRoot"
    Write-Header "Deleting Trusted Root Policy '$DisplayName'..."
    $script:IosTrustedRootPolicy = Get-MgDeviceManagementDeviceConfiguration -Filter "displayName eq '$DisplayName'"
    if($IosTrustedRootPolicy) {
        Remove-MgDeviceManagementDeviceConfiguration -DeviceConfigurationId $IosTrustedRootPolicy.Id
    } else {
        Write-Host "Trusted Root Policy '$DisplayName' does not exist."
    }
}

Function New-IosDeviceConfigurationPolicy{
    $DisplayName = "ios-$VmName-DeviceConfiguration"
    $script:IosDeviceConfigurationPolicy = Get-MgDeviceManagementDeviceConfiguration -Filter "displayName eq '$DisplayName'"

    if($IosDeviceConfigurationPolicy) {
        Write-Host "Already found Device Configuration policy named '$DisplayName'"
    } else {
        Write-Header "Creating Device Configuration policy '$DisplayName'..."
        $Body = @{
            "@odata.type" = "#microsoft.graph.iosVpnConfiguration"
            displayName = $DisplayName
            id = [System.Guid]::Empty.ToString()
            roleScopeTagIds = @("0")
            authenticationMethod = "usernameAndPassword"
            connectionType = "microsoftTunnel"
            connectionName = $DisplayName
            microsoftTunnelSiteId = $Site.Id
            server = @{
                address = "$($Site.PublicAddress):$($ServerConfiguration.ListenPort)"
                description = ""
            }
            proxyServer = @{ automaticConfigurationScriptUrl = "$PACUrl" }
            customData = @(@{
                key = "MSTunnelProtectMode"
                value = "1"
            })
            enableSplitTunneling = $false
        } | ConvertTo-Json -Depth 10

        $script:IosDeviceConfigurationPolicy = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations" -Body $Body

        $Body = @{
            "assignments" = @(@{
                "target" = @{
                    "groupId" = $Group.Id
                    "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                }
            })
        }
    
        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($IosDeviceConfigurationPolicy.Id)/assign" -Body $Body
    }
}

Function Remove-IosDeviceConfigurationPolicy{
    $DisplayName = "ios-$VmName-DeviceConfiguration"
    Write-Header "Deleting Device Configuration Policy '$DisplayName'..."
    $script:IosDeviceConfigurationPolicy = Get-MgDeviceManagementDeviceConfiguration -Filter "displayName eq '$DisplayName'"
    if($IosDeviceConfigurationPolicy) {
        Remove-MgDeviceManagementDeviceConfiguration -DeviceConfigurationId $IosDeviceConfigurationPolicy.Id
    } else {
        Write-Host "Device Configuration Policy '$DisplayName' does not exist."
    }
}

Function New-IosAppConfigurationPolicy{
    $DisplayName = "ios-$VmName-Configuration"
    $script:IosAppConfigurationPolicy = Get-MgDeviceAppManagementManagedAppPolicy -Filter "displayName eq '$DisplayName'" -Limit 1
    if ($script:IosAppConfigurationPolicy) {
        Write-Host "Already found App Configuration policy named '$DisplayName'"
    } else {
        Write-Header "Creating App Configuration policy '$DisplayName'..."
        $customSettings = @(
            @{
                name="com.microsoft.intune.mam.managedbrowser.TunnelAvailable.IntuneMAMOnly"
                value="true"
            }
            @{
                name="com.microsoft.tunnel.connection_type"
                value="MicrosoftProtect"
            }
            @{
                name="com.microsoft.tunnel.connection_name"
                value=$VmName
            }
            @{
                name="com.microsoft.tunnel.site_id"
                value=$Site.Id
            }
            @{
                name="com.microsoft.tunnel.server_address"
                value="$($Site.PublicAddress):$($ServerConfiguration.ListenPort)"
            }
            @{
                name="com.microsoft.tunnel.trusted_root_certificates"
                value= (@(
                    @{
                        "@odata.type" = $IosTrustedRootPolicy.AdditionalProperties."@odata.type"
                        id = $IosTrustedRootPolicy.Id
                        displayName = $IosTrustedRootPolicy.DisplayName
                        lastModifiedDateTime = $IosTrustedRootPolicy.LastModifiedDateTime
                        trustedRootCertificate = $IosTrustedRootPolicy.AdditionalProperties.trustedRootCertificate
                    }
                ) | ConvertTo-Json -Depth 10 -Compress -AsArray)
            }
        )

        if (-Not $NoProxy){
            $customSettings += @(@{
                name="com.microsoft.tunnel.proxy_pacurl"
                value=$PACUrl
            })
        }

        $targetedApps = $BundleIds | ForEach-Object { 
            @{
                mobileAppIdentifier = @{
                    "@odata.type" = "#microsoft.graph.iosMobileAppIdentifier"
                    bundleId = $_
                }
            }
        }
        if (-not ($targetedApps -is [array])) {
            $targetedApps = @($targetedApps)
        }
        $body = @{
            apps = $targetedApps
            assignments = @(
                @{
                    target = @{
                        groupId = $Group.Id
                        deviceAndAppManagementAssignmentFilterId = $null
                        deviceAndAppManagementAssignmentFilterType = "none"
                        "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                    }
                }
            )
            appGroupType = "selectedPublicApps"
            customSettings = $customSettings
            displayName = $DisplayName
            description = ""
            roleScopeTagIds = @()
            scSettings = @()
            targetedAppManagementLevels = "unspecified"
        } | ConvertTo-Json -Depth 10 -Compress

        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceAppManagement/targetedManagedAppConfigurations" -Body $Body | Out-Null
        $script:IosAppConfigurationPolicy = Get-MgDeviceAppManagementTargetedManagedAppConfiguration -Filter "displayName eq '$DisplayName'" -Limit 1
    }
}

Function Remove-IosAppConfigurationPolicy{
    $DisplayName = "ios-$VmName-Configuration"
    Write-Header "Deleting App Configuration Policy '$DisplayName'..."
    $script:IosAppConfigurationPolicy = Get-MgDeviceAppManagementManagedAppPolicy -Filter "displayName eq '$DisplayName'" -Limit 1
    if($IosAppConfigurationPolicy) {
        Remove-MgDeviceAppManagementManagedAppPolicy -ManagedAppPolicyId $IosAppConfigurationPolicy.Id
    } else {
        Write-Host "App Configuration Policy '$DisplayName' does not exist."
    }
}

Function New-AndroidTrustedRootPolicy{
    $DisplayName = "android-$VmName-RootCertificate"
    $script:AndroidTrustedRootPolicy = Get-MgDeviceManagementDeviceConfiguration -Filter "displayName eq '$DisplayName'"
    if($AndroidTrustedRootPolicy) {
        Write-Host "Already found Trusted Root policy named '$DisplayName'"
    } else {
        $cerFileName = "./$([System.Guid]::NewGuid().ToString())$VmName.pem"
        try{
            Write-Header "Copying root certificate locally..."
            scp -i $sshKeyPath -o "StrictHostKeyChecking=no" "$($username)@$($FQDN):/etc/pki/tls/certs/cacert.pem" $cerFileName > $null 
            $certValue = (Get-Content $cerFileName).Replace("-----BEGIN CERTIFICATE-----","").Replace("-----END CERTIFICATE-----","") -join ""
            
            $Body = @{
                "@odata.type" = "#microsoft.graph.androidWorkProfileTrustedRootCertificate"
                displayName = $DisplayName
                id = [System.Guid]::Empty.ToString()
                roleScopeTagIds = @("0")
                certFileName = "$VmName.cer"
                trustedRootCertificate = $certValue
            } | ConvertTo-Json -Depth 10

            Write-Header "Creating Trusted Root Policy..."
            $script:AndroidTrustedRootPolicy = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations" -Body $Body
            # re-fetch the policy so the root certificate is included
            $script:AndroidTrustedRootPolicy = Get-MgDeviceManagementDeviceConfiguration -Filter "displayName eq '$DisplayName'"

            $Body = @{
                "assignments" = @(@{
                    "target" = @{
                        "groupId" = $Group.Id
                        "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                    }
                })
            }
        
            Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($AndroidTrustedRootPolicy.Id)/assign" -Body $Body
        } finally {
            Remove-Item $cerFileName
        } 
    }
}

Function Remove-AndroidTrustedRootPolicy{
    $DisplayName = "android-$VmName-RootCertificate"
    Write-Header "Deleting Device Configuration Policy '$DisplayName'..."
    $script:AndroidDeviceConfigurationPolicy = Get-MgDeviceManagementDeviceConfiguration -Filter "displayName eq '$DisplayName'"
    if($AndroidDeviceConfigurationPolicy) {
        Remove-MgDeviceManagementDeviceConfiguration -DeviceConfigurationId $AndroidDeviceConfigurationPolicy.Id
    } else {
        Write-Host "Device Configuration Policy '$DisplayName' does not exist."
    }
}

Function New-AndroidDeviceConfigurationPolicy{
    $DisplayName = "android-$VmName-DeviceConfiguration"
    $script:AndroidTrustedRootPolicy = Get-MgDeviceManagementDeviceConfiguration -Filter "displayName eq '$DisplayName'"

    if($AndroidDeviceConfigurationPolicy) {
        Write-Host "Already found Device Configuration policy named '$DisplayName'"
    } else {
        Write-Header "Creating Device Configuration policy '$DisplayName'..."
        $Body = @{
            "@odata.type" = "#microsoft.graph.androidWorkProfileVpnConfiguration"
            displayName = $DisplayName
            id = [System.Guid]::Empty.ToString()
            roleScopeTagIds = @("0")
            authenticationMethod = "azureAD"
            connectionType = "microsoftProtect"
            connectionName = $DisplayName
            microsoftTunnelSiteId = $Site.Id
            servers = @(@{
                address = "$($Site.PublicAddress):$($ServerConfiguration.ListenPort)"
                description = ""
            })
            proxyServer = @{ automaticConfigurationScriptUrl = "$PACUrl" }
            customData = @(@{
                key = "MicrosoftDefenderAppSettings"
                value = $null
            })
        } | ConvertTo-Json -Depth 10

        $script:AndroidDeviceConfigurationPolicy = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations" -Body $Body

        $Body = @{
            "assignments" = @(@{
                "target" = @{
                    "groupId" = $Group.Id
                    "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                }
            })
        }
    
        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($AndroidDeviceConfigurationPolicy.Id)/assign" -Body $Body
    }
}

Function Remove-AndroidDeviceConfigurationPolicy{
    $DisplayName = "android-$VmName-DeviceConfiguration"
    Write-Header "Deleting Device Configuration Policy '$DisplayName'..."
    $script:AndroidDeviceConfigurationPolicy = Get-MgDeviceManagementDeviceConfiguration -Filter "displayName eq '$DisplayName'"
    if($AndroidDeviceConfigurationPolicy) {
        Remove-MgDeviceManagementDeviceConfiguration -DeviceConfigurationId $AndroidDeviceConfigurationPolicy.Id
    } else {
        Write-Host "Device Configuration Policy '$DisplayName' does not exist."
    }
}

Function New-AndroidAppProtectionPolicy{
    $DisplayName = "android-$VmName-AppProtection"
    $script:AndroidAppProtectionPolicy = Get-MgDeviceAppManagementAndroidManagedAppProtection -Filter "displayName eq '$DisplayName'"
    if ($AndroidAppProtectionPolicy) {
        Write-Host "Already found App Protection policy named '$DisplayName'"
    } else {
        Write-Header "Creating App Protection policy '$DisplayName'..."
        # $script:AndroidAppProtectionPolicy = New-MgDeviceAppManagementiOSManagedAppProtection -DisplayName $DisplayName
        Write-Header "Targeting bundles to '$DisplayName'..."

        $customApps = $BundleIds | ForEach-Object { 
            @{
                mobileAppIdentifier = @{
                    "@odata.type" = "#microsoft.graph.androidMobileAppIdentifier"
                    packageId = $_
                }
            }
        }
        if (-not ($customApps -is [array])) {
            $customApps = @($customApps)
        }

        $defaultApps = @(
            @{
                mobileAppIdentifier = @{
                    "@odata.type" = "#microsoft.graph.androidMobileAppIdentifier"
                    packageId = "com.microsoft.scmx"
                }
            }
            @{
                mobileAppIdentifier = @{
                    "@odata.type" = "#microsoft.graph.androidMobileAppIdentifier"
                    packageId = "com.microsoft.emmx"
                }
            }
        )

        $targetedApps = $customApps + $defaultApps

        $body = @{
            displayName = $DisplayName
            apps = $targetedApps
            appGroupType = "selectedPublicApps"
            connectToVpnOnLaunch = $true
        } | ConvertTo-Json -Depth 10
        
        $script:AndroidAppProtectionPolicy = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceAppManagement/androidManagedAppProtections" -Body $Body
        
        Write-Header "Assigning App Protection policy '$DisplayName' to group '$($Group.DisplayName)'..."
        $Body = @{
            assignments = @(
                @{
                    target = @{
                        groupId = $Group.Id
                        deviceAndAppManagementAssignmentFilterId = $null
                        deviceAndAppManagementAssignmentFilterType = "none"
                        "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                    }
                }
            )
            appGroupType = "selectedPublicApps"
            customSettings = $customSettings
            displayName = $DisplayName
            description = ""
            roleScopeTagIds = @()
            scSettings = @()
            targetedAppManagementLevels = "unspecified"
        } | ConvertTo-Json -Depth 10 -Compress

        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceAppManagement/androidManagedAppProtections('$($AndroidAppProtectionPolicy.Id)')/assign" -Body $Body
    }
}

Function Remove-AndroidAppProtectionPolicy{
    $DisplayName = "android-$VmName-AppProtection"
    Write-Header "Deleting App Protection Policy '$DisplayName'..."
    $script:AndroidAppProtectionPolicy = Get-MgDeviceAppManagementAndroidManagedAppProtection -Filter "displayName eq '$DisplayName'" -Limit 1
    if($AndroidAppProtectionPolicy) {
        Remove-MgDeviceAppManagementAndroidManagedAppProtection -AndroidManagedAppProtectionId $AndroidAppProtectionPolicy.Id
    } else {
        Write-Host "App Protection Policy '$DisplayName' does not exist."
    }
}

Function New-AndroidAppConfigurationPolicy{
    $DisplayName = "android-$VmName-Configuration"
    $script:AndroidAppConfigurationPolicy = Get-MgDeviceAppManagementManagedAppPolicy -Filter "displayName eq '$DisplayName'" -Limit 1
    if ($script:AndroidAppConfigurationPolicy) {
        Write-Host "Already found App Configuration policy named '$DisplayName'"
    } else {
        Write-Header "Creating App Configuration policy '$DisplayName'..."


        $perApps = ""
        if ($bundleIds.Count -eq 0) {
            $perApps = ""
        } elseif ($BundleIds.Count -eq 1) {
            $perApps = $BundleIds[0]
        } else {
            $BundleIds | ForEach-Object { 
                $perApps = $perApps + "|" + $_
            }
        }

        $customSettings = @(
            @{
                name="com.microsoft.intune.mam.managedbrowser.TunnelAvailable.IntuneMAMOnly"
                value="true"
            }
            @{
                name="com.microsoft.tunnel.connection_type"
                value="MicrosoftProtect"
            }
            @{
                name="com.microsoft.tunnel.connection_name"
                value=$VmName
            }
            @{
                name="com.microsoft.tunnel.site_id"
                value=$Site.Id
            }
            @{
                name="com.microsoft.tunnel.server_address"
                value="$($Site.PublicAddress):$($ServerConfiguration.ListenPort)"
            }
            @{
                name = "com.microsoft.tunnel.targeted_apps"
                value=$perApps
            }
            @{
                name="com.microsoft.tunnel.trusted_root_certificates"
                value= (@(
                    @{
                        "@odata.type" = $AndroidTrustedRootPolicy.AdditionalProperties."@odata.type"
                        id = $AndroidTrustedRootPolicy.Id
                        displayName = $AndroidTrustedRootPolicy.DisplayName
                        lastModifiedDateTime = $AndroidTrustedRootPolicy.LastModifiedDateTime
                        trustedRootCertificate = $AndroidTrustedRootPolicy.AdditionalProperties.trustedRootCertificate
                    }
                ) | ConvertTo-Json -Depth 10 -Compress -AsArray)
            }
        )

        if (-Not $NoProxy){
            $customSettings += @(@{
                name="com.microsoft.tunnel.proxy_pacurl"
                value="$PACUrl"
            })
        }

        $customApps = $BundleIds | ForEach-Object { 
            @{
                mobileAppIdentifier = @{
                    "@odata.type" = "#microsoft.graph.androidMobileAppIdentifier"
                    packageId = $_
                }
            }
        }
        if (-not ($customApps -is [array])) {
            $customApps = @($customApps)
        }

        $defaultApps = @(
            @{
                mobileAppIdentifier = @{
                    "@odata.type" = "#microsoft.graph.androidMobileAppIdentifier"
                    packageId = "com.microsoft.scmx"
                }
            }
            @{
                mobileAppIdentifier = @{
                    "@odata.type" = "#microsoft.graph.androidMobileAppIdentifier"
                    packageId = "com.microsoft.emmx"
                }
            }
        )

        $targetedApps = $customApps + $defaultApps

        $body = @{
            apps = $targetedApps
            assignments = @(
                @{
                    target = @{
                        groupId = $Group.Id
                        deviceAndAppManagementAssignmentFilterId = $null
                        deviceAndAppManagementAssignmentFilterType = "none"
                        "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                    }
                }
            )
            appGroupType = "selectedPublicApps"
            customSettings = $customSettings
            displayName = $DisplayName
            description = ""
            roleScopeTagIds = @()
            scSettings = @()
            targetedAppManagementLevels = "unspecified"
        } | ConvertTo-Json -Depth 10 -Compress

        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceAppManagement/targetedManagedAppConfigurations" -Body $Body | Out-Null
        $script:AndroidAppConfigurationPolicy = Get-MgDeviceAppManagementTargetedManagedAppConfiguration -Filter "displayName eq '$DisplayName'" -Limit 1
    }
}

Function Remove-AndroidAppConfigurationPolicy{
    $DisplayName = "android-$VmName-Configuration"
    Write-Header "Deleting App Configuration Policy '$DisplayName'..."
    $script:AndroidAppConfigurationPolicy = Get-MgDeviceAppManagementManagedAppPolicy -Filter "displayName eq '$DisplayName'" -Limit 1
    if($AndroidAppConfigurationPolicy) {
        Remove-MgDeviceAppManagementManagedAppPolicy -ManagedAppPolicyId $AndroidAppConfigurationPolicy.Id
    } else {
        Write-Host "App Configuration Policy '$DisplayName' does not exist."
    }
}

Function New-IOSProfiles{
    if ($Platform -eq "ios" -or $Platform -eq "all") {
        New-IosTrustedRootPolicy
        New-IosDeviceConfigurationPolicy
        New-IosAppProtectionPolicy
        New-IosAppConfigurationPolicy
    }
}

Function New-AndroidProfiles{
    if ($Platform -eq "android" -or $Platform -eq "all") {
        New-AndroidTrustedRootPolicy
        New-AndroidDeviceConfigurationPolicy
        New-AndroidAppProtectionPolicy
        New-AndroidAppConfigurationPolicy
    }
}
#endregion Profile Functions

#region ADFS Functions
Function New-ADFSEnvironment {
    Write-Header "Creating ADFS Environment"

    Write-Header "Creating VM '$VmName-dc'..."
    $AdminPassword = New-RandomPassword
    $windowsVmData = az vm create --location $location --resource-group $resourceGroup --name "$VmName-dc" --image $WindowsServerImage --size $WindowsVmSize --admin-username $Username --admin-password $AdminPassword --only-show-errors | ConvertFrom-Json
`
    # Install AD DS role on the first VM and promote it to a domain controller
    az vm run-command invoke `
    -g $ResourceGroupName `
    -n "$($VmName)-dc" `
    -c RunPowerShellScript `
    -s @'
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
Import-Module ADDSDeployment
Install-ADDSForest -CreateDnsDelegation:$false -DatabasePath "F:\NTDS" -DomainMode Win2012R2 -DomainName "$DomainName" -DomainNetbiosName "$($DomainName.Split('.')[0])" -ForestMode Win2012R2 -InstallDns:$true -LogPath "F:\NTDS" -NoRebootOnCompletion:$false -SysvolPath "F:\SYSVOL" -Force:$true
Install-ADDSDomainController -CreateDnsDelegation:$false -Credential (New-Object System.Management.Automation.PSCredential("$Username", (ConvertTo-SecureString "$AdminPassword" -AsPlainText -Force))) -DatabasePath "F:\NTDS" -DomainName "$DomainName" -InstallDns:$true -LogPath "F:\NTDS" -NoGlobalCatalog:$false -SiteName "Default-First-Site-Name" -NoRebootOnCompletion:$false -SysvolPath "F:\SYSVOL" -Force:$true
Install-WindowsFeature ADFS-Federation
'@
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
    
    New-ProxyVM
    Initialize-Proxy
    Invoke-ProxyScript
    
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

    Remove-IosDeviceConfigurationPolicy
    Remove-IosAppConfigurationPolicy
    Remove-IosAppProtectionPolicy
    Remove-IosTrustedRootPolicy
    Remove-AndroidAppProtectionPolicy
    Remove-AndroidAppConfigurationPolicy
    Remove-AndroidTrustedRootPolicy
    Remove-AndroidDeviceConfigurationPolicy

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
} else {
    New-TunnelEnvironment
}
#endregion Main Functions
