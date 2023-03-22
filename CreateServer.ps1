[cmdletbinding(DefaultParameterSetName="Create")]
param(
    [Parameter(Mandatory=$true, ParameterSetName="Create")]
    [Parameter(Mandatory=$true, ParameterSetName="Delete")]
    [string]$VmName,
    [Parameter(Mandatory=$true, ParameterSetName="Create")]
    [string[]]$BundleIds,
    [Parameter(Mandatory=$true, ParameterSetName="Create")]
    [string]$GroupName,
    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [ValidateSet("eastasia","southeastasia","centralus","eastus","eastus2","westus","northcentralus","southcentralus","northeurope","westeurope","japanwest","japaneast","brazilsouth","australiaeast","australiasoutheast","southindia","centralindia","westindia","canadacentral","canadaeast","uksouth","ukwest","westcentralus","westus2","koreacentral","koreasouth","francecentral","francesouth","australiacentral","australiacentral2")]
    [string]$Location="westus",
    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [ValidateSet("PE","SelfHost","OneDF")]
    [string]$Environment="PE",
    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [string]$Email="",
    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [string]$Username="azureuser",
    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [string]$Size = "Standard_B1s",
    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [string]$Image = "Canonical:0001-com-ubuntu-server-focal:20_04-lts:latest", #"Canonical:UbuntuServer:18.04-LTS:18.04.202106220"
    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [string]$ADApplication = "Generated MAM Tunnel",
    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [switch]$NoProxy,
    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [switch]$UseEnterpriseCa,
    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="Delete")]
    [pscredential]$TenantCredential,
    [Parameter(Mandatory=$true, ParameterSetName="Delete")]
    [switch]$Delete,
    [Parameter(Mandatory=$false, ParameterSetName="Create")]
    [Parameter(Mandatory=$false, ParameterSetName="Delete")]
    [switch]$StayLoggedIn
)

$script:Account = $null
$script:Subscription = $null
$script:ResourceGroup = $null
$script:SSHKeyPath = $null
$script:FQDN = $null
$script:ServerConfiguration = $null
$script:Site = $null
$script:App = $null
$script:Group = $null
$script:AppProtectionPolicy = $null
$script:AppConfigurationPolicy = $null
$script:Platform = ""

Function Write-Header([string]$Message) {
    Write-Host $Message -ForegroundColor Cyan
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

    if ($IsLinux) {
        $script:Platform = "linux"
    } elseif ($IsMacOS) {
        $script:Platform = "osx"
    } else {
        $script:Platform = "win"
    }
}

Function Login {
    Write-Header "Select the account to manage the VM."
    az login --only-show-errors | Out-Null
    
    Write-Header "Logging into graph..."
    Write-Header "Select the account to manage the profiles."

    if (-Not $TenantCredential) {
        $script:JWT = Invoke-Expression "mstunnel-utils/mstunnel-$Platform.exe JWT"
    } else {
        $script:JWT = Invoke-Expression "mstunnel-utils/mstunnel-$Platform.exe JWT $($TenantCredential.UserName) $($TenantCredential.GetNetworkCredential().Password)"
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
    $script:Account = (az account show | ConvertFrom-Json)
    $script:Subscription = $Account.id
    if ($Email -eq "") {
        Write-Header "Email not provided. Detecting email..."
        $script:Email = $Account.user.name
        Write-Host "Detected your email as '$Email'"
    }

    $script:ResourceGroup = "$VmName-group"
    $script:SSHKeyPath = "~/.ssh/$VmName"

    if (-Not $Delete) {
        # We only need a group name for the create flow
        $script:Group = Get-MgGroup -Filter "displayName eq '$GroupName'"
        if (-Not $Group) {
            Write-Error "Could not find group named '$GroupName'"
            Exit -1
        }
    }
}

Function New-ResourceGroup {
    Write-Header "Checking for resource group '$resourceGroup'..."
    if ([bool](az group show --name $resourceGroup --subscription $Subscription 2> $null)) {
        Write-Error "Group '$resourceGroup' already exists"
        exit -1
    }
    
    Write-Header "Creating resource group '$resourceGroup'..."
    $groupData = az group create --subscription $subscription --location $location --name $resourceGroup --only-show-errors | ConvertFrom-Json
}

Function Remove-ResourceGroup {
    Write-Header "Checking for resource group '$resourceGroup'..."
    if ([bool](az group show --name $resourceGroup --subscription $Subscription 2> $null)) {
        Write-Header "Deleting resource group '$resourceGroup'..."
        az group delete --name $resourceGroup --yes --no-wait
    } else {
        Write-Host "Group '$resourceGroup' does not exist"
    }
}

Function New-VM {
    Write-Header "Creating VM '$VmName'..."
    $vmdata = az vm create --subscription $subscription --location $location --resource-group $resourceGroup --name $VmName --image $Image --size $Size --ssh-key-values "$SSHKeyPath.pub" --public-ip-address-dns-name $VmName --admin-username $Username --only-show-errors | ConvertFrom-Json
    $script:FQDN = $vmdata.fqdns
    Write-Host "DNS is '$FQDN'"
}

Function New-NetworkRules {
    Write-Header "Creating network rules..."
    az network nsg rule create --subscription $subscription --resource-group $resourceGroup --nsg-name "$($VmName)NSG" -n SSHIN --priority 100 --source-address-prefixes '*' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 22 --access Allow --protocol Tcp --description "Allow SSH" > $null
    az network nsg rule create --subscription $subscription --resource-group $resourceGroup --nsg-name "$($VmName)NSG" -n HTTPIN --priority 101 --source-address-prefixes 'Internet' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 443 --access Allow --protocol '*' --description "Allow HTTP" > $null
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

Function Initialize-SetupScript {
    try{
        Write-Header "Generating setup script..."
        $ServerName = $FQDN.Split('.')[0]
        $Content = @"
        export intune_env=$Environment;
        git clone --single-branch --branch Hackathon https://github.com/mikeliddle/TunnelTestEnv.git
        cd TunnelTestEnv

        cp ../agent.p12 .
        cp ../agent-info.json .

        git submodule update --init

        chmod +x setup.exp envSetup.sh exportCert.sh setup-expect.sh
        
        PUBLIC_IP=`$(curl ifconfig.me)
        sed -i.bak -e "s/SERVER_NAME=/SERVER_NAME=$ServerName/" -e "s/DOMAIN_NAME=/DOMAIN_NAME=$FQDN/" -e "s/SERVER_PUBLIC_IP=/SERVER_PUBLIC_IP=`$PUBLIC_IP/" -e "s/EMAIL=/EMAIL=$Email/" -e "s/SITE_ID=/SITE_ID=$($Site.Id)/" vars
        export SETUP_ARGS="-i$(if (-Not $NoProxy) {"p"})$(if ($UseEnterpriseCa) {"e"})"
        
        ./setup-expect.sh
        
        expect -f ./setup.exp
"@
        Set-Content -Path "./Setup.sh" -Value $Content -Force
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

Function New-TunnelConfiguration {
    Write-Header "Creating Server Configuration..."
    $script:ServerConfiguration = Get-MgDeviceManagementMicrosoftTunnelConfiguration -Filter "displayName eq '$VmName'" -Limit 1
    if ($ServerConfiguration) {
        Write-Header "Already found Server Configuration named '$VmName'"
    } else {
        $ListenPort = 443
        $DnsServers = @("8.8.8.8")
        $Network = "169.254.0.0/16"
        $script:ServerConfiguration = New-MgDeviceManagementMicrosoftTunnelConfiguration -DisplayName $VmName -ListenPort $ListenPort -DnsServers $DnsServers -Network $Network -AdvancedSettings @() -DefaultDomainSuffix "" -RoleScopeTagIds @("0") -RouteExcludes @() -RouteIncludes @() -SplitDns @()    
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

Function New-TunnelSite {
    Write-Header "Creating Site..."
    $script:Site = Get-MgDeviceManagementMicrosoftTunnelSite -Filter "displayName eq '$VmName'" -Limit 1
    if ($Site) {
        Write-Header "Already found Site named '$VmName'"
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

Function Update-ADApplication {
    $script:App = Get-MgApplication -Filter "displayName eq '$ADApplication'" -Limit 1
    if($App) {
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

        Write-Header "You will need to grant consent. Opening browser in 15 seconds..."
        Start-Sleep -Seconds 15
        Start-Process "https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/CallAnAPI/appId/$($App.AppId)/isMSAApp~/false"
    }
}

Function New-IosAppProtectionPolicy{
    $DisplayName = "$VmName-Protection"
    $script:AppProtectionPolicy = Get-MgDeviceAppManagementiOSManagedAppProtection -Filter "displayName eq '$DisplayName'" -Limit 1
    if ($AppProtectionPolicy) {
        Write-Header "Already found App Protection policy named '$DisplayName'"
    } else {
        Write-Header "Creating App Protection policy '$DisplayName'..."
        $script:AppProtectionPolicy = New-MgDeviceAppManagementiOSManagedAppProtection -DisplayName $DisplayName
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
        
        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceAppManagement/iosManagedAppProtections('$($AppProtectionPolicy.Id)')/targetApps" -Body $Body
        
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

        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceAppManagement/iosManagedAppProtections('$($AppProtectionPolicy.Id)')/assign" -Body $Body
    }
}

Function Remove-IosAppProtectionPolicy{
    $DisplayName = "$VmName-Protection"
    Write-Header "Deleting App Protection Policy '$DisplayName'..."
    $script:AppProtectionPolicy = Get-MgDeviceAppManagementiOSManagedAppProtection -Filter "displayName eq '$DisplayName'" -Limit 1
    if($AppProtectionPolicy) {
        Remove-MgDeviceAppManagementiOSManagedAppProtection -IosManagedAppProtectionId $AppProtectionPolicy.Id
    } else {
        Write-Host "App Protection Policy '$DisplayName' does not exist."
    }
}

Function New-IosAppConfigurationPolicy{
    $DisplayName = "$VmName-Configuration"
    $script:AppConfigurationPolicy = Get-MgDeviceAppManagementManagedAppPolicy -Filter "displayName eq '$DisplayName'" -Limit 1
    if ($script:AppConfigurationPolicy) {
        Write-Header "Already found App Configuration policy named '$DisplayName'"
    } else {
        Write-Header "Creating App Configuration policy '$DisplayName'..."
        $customSettings = @(
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
        )
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
            customSettings = $customSettings
            displayName = $DisplayName
            targetedAppManagementLevels = "unspecified"
        } | ConvertTo-Json -Depth 10

        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceAppManagement/targetedManagedAppConfigurations" -Body $Body | Out-Null
        $script:AppConfigurationPolicy = Get-MgDeviceAppManagementTargetedManagedAppConfiguration -Filter "displayName eq '$DisplayName'" -Limit 1

        Write-Header "Assigning App Configuration policy '$DisplayName' to group '$($Group.DisplayName)'..."
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

        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceAppManagement/targetedManagedAppConfigurations('$($AppConfigurationPolicy.Id)')/assign" -Body $Body
    }
}

Function Remove-IosAppConfigurationPolicy{
    $DisplayName = "$VmName-Configuration"
    Write-Header "Deleting App Configuration Policy '$DisplayName'..."
    $script:AppConfigurationPolicy = Get-MgDeviceAppManagementManagedAppPolicy -Filter "displayName eq '$DisplayName'" -Limit 1
    if($AppConfigurationPolicy) {
        Remove-MgDeviceAppManagementManagedAppPolicy -ManagedAppPolicyId $AppConfigurationPolicy.Id
    } else {
        Write-Host "App Configuration Policy '$DisplayName' does not exist."
    }
}

Function New-TunnelAgent{
    if (-Not $TenantCredential) {
        $script:JWT = Invoke-Expression "mstunnel-utils/mstunnel-$Platform.exe Agent $($Site.Id)"
    } else {
        $script:JWT = Invoke-Expression "mstunnel-utils/mstunnel-$Platform.exe Agent $($Site.Id) $($TenantCredential.UserName) $($TenantCredential.GetNetworkCredential().Password)"
    }
}

Function New-SSHKeys{
    Write-Header "Generating new RSA 4096 SSH Key"
    ssh-keygen -t rsa -b 4096 -f $SSHKeyPath -q -N ""
}

Function Create-Flow {
    Test-Prerequisites
    Login
    Initialize-Variables
    New-SSHKeys
    New-ResourceGroup
    New-VM
    New-NetworkRules
    # Move-SSHKeys

    New-TunnelConfiguration
    New-TunnelSite

    New-TunnelAgent

    Initialize-SetupScript
    Invoke-SetupScript

    Update-ADApplication

    New-IosAppProtectionPolicy
    New-IosAppConfigurationPolicy
    Logout
}

Function Delete-Flow {
    Test-Prerequisites
    Login
    Initialize-Variables
    Remove-ResourceGroup
    Remove-SSHKeys

    Remove-IosAppConfigurationPolicy
    Remove-IosAppProtectionPolicy
    Remove-TunnelSite
    Remove-TunnelConfiguration
    Logout
}

if ($Delete) {
    Delete-Flow
} else {
    Create-Flow
}