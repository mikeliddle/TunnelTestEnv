[cmdletbinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("eastasia","southeastasia","centralus","eastus","eastus2","westus","northcentralus","southcentralus","northeurope","westeurope","japanwest","japaneast","brazilsouth","australiaeast","australiasoutheast","southindia","centralindia","westindia","canadacentral","canadaeast","uksouth","ukwest","westcentralus","westus2","koreacentral","koreasouth","francecentral","francesouth","australiacentral","australiacentral2")]
    [string]$Location="westus",
    [Parameter(Mandatory=$false)]
    [ValidateSet("PE","SelfHost","OneDF")]
    [string]$Environment="PE",
    [Parameter(Mandatory=$false)]
    [string]$Email="",
    [Parameter(Mandatory=$false)]
    [string]$Username="azureuser",
    [Parameter(Mandatory=$true)]
    [string]$VmName,
    [Parameter(Mandatory=$false)]
    [string]$Size = "Standard_B1s",
    [Parameter(Mandatory=$false)]
    [string]$Image = "Canonical:0001-com-ubuntu-server-focal:20_04-lts:latest", #"Canonical:UbuntuServer:18.04-LTS:18.04.202106220"
    [Parameter(Mandatory=$false)]
    [string]$ADApplication = "Generated MAM Tunnel",
    [Parameter(Mandatory=$false)]
    [string[]]$BundleIds = $null,
    [Parameter(Mandatory=$false)]
    [switch]$Delete
)

$script:Account = $null
$script:Subscription = $null
$script:Group = $null
$script:SSHKeyPath = $null
$script:FQDN = $null
$script:ServerConfiguration = $null
$script:Site = $null
$script:App = $null

Function Write-Header([string]$Message) {
    Write-Host $Message -ForegroundColor Cyan
}

Function Check-Prerequisites {
    if (-Not ([bool](Get-Command -ErrorAction Ignore az))) {
        Write-Error "Please install azure cli`nhttps://learn.microsoft.com/en-us/cli/azure/"
        Exit 1
    }
    
    if (-Not (Get-Module -ListAvailable -Name "Microsoft.Graph")) {
        Write-Header "Installing Microsoft.Graph..."
        Install-Module Microsoft.Graph -Force
    }
}

Function Login {
    Write-Header "Select the account to manage the VM."
    az login --only-show-errors | Out-Null
    
    Write-Header "Logging into graph..."
    Write-Header "Select the account to manage the profiles."
    Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All", "Application.ReadWrite.All" | Out-Null
    
    # Switch to beta since most of our endpoints are there
    Select-MgProfile -Name "beta"    
}

Function Logout {
    az logout
    $script:Account = Disconnect-MgGraph
}

Function Detect-Variables {
    $script:Account = (az account show | ConvertFrom-Json)
    $script:Subscription = $Account.id
    if ($Email -eq "") {
        Write-Host "Email not provided. Detecting email..."
        $script:Email = $Account.user.name
        Write-Host "Detected your email as '$Email'"
    }

    $script:Group = "$VmName-group"
    $script:SSHKeyPath = "~/.ssh/$VmName"
}

Function Create-ResourceGroup {
    Write-Header "Checking for group '$group'..."
    if ([bool](az group show --name $group --subscription $Subscription 2> $null)) {
        Write-Error "Group '$group' already exists"
        exit -1
    }
    
    Write-Header "Creating group '$group'..."
    $groupData = az group create --subscription $subscription --location $location --name $group --only-show-errors | ConvertFrom-Json
}

Function Delete-ResourceGroup {
    Write-Header "Checking for group '$group'..."
    if ([bool](az group show --name $group --subscription $Subscription 2> $null)) {
        Write-Header "Deleting group '$group'..."
        az group delete --name $group --yes --no-wait
    } else {
        Write-Host "Group '$group' does not exist"
    }
}

Function Create-VM {
    Write-Header "Creating VM '$VmName'..."
    $vmdata = az vm create --subscription $subscription --location $location --resource-group $group --name $VmName --image $Image --size $Size --generate-ssh-keys --public-ip-address-dns-name $VmName --admin-username $Username --only-show-errors | ConvertFrom-Json
    $script:FQDN = $vmdata.fqdns
    Write-Host "DNS is '$FQDN'"
}

Function Create-NetworkRules {
    Write-Header "Creating network rules..."
    az network nsg rule create --subscription $subscription --resource-group $group --nsg-name "$($VmName)NSG" -n SSHIN --priority 100 --source-address-prefixes '*' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 22 --access Allow --protocol Tcp --description "Allow SSH" > $null
    az network nsg rule create --subscription $subscription --resource-group $group --nsg-name "$($VmName)NSG" -n HTTPIN --priority 101 --source-address-prefixes '*' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 80 443 --access Allow --protocol '*' --description "Allow HTTP" > $null
}

Function Move-SSHKeys{
    Write-Header "Moving generated SSH keys..."
    Move-Item -Path ~/.ssh/id_rsa -Destination $sshKeyPath -Force
    Move-Item -Path ~/.ssh/id_rsa.pub -Destination ~/.ssh/$VmName.pub -Force    
}

Function Delete-SSHKeys{
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

Function Stage-SetupScript {
    try{
        Write-Header "Generating setup script..."
        Set-Content -Path "./Setup.sh" -Value "export intune_env=$Environment; ./InstallServer.sh --email ""$email"" --domain ""$FQDN""" -Force
        Write-Header "Copying setup script to remote server..."
        scp -i $sshKeyPath -o "StrictHostKeyChecking=no" ./InstallServer.sh ./Setup.sh "$($username)@$($FQDN):~/" > $null
    }
    finally {
        Remove-Item "./Setup.sh"
    }
}

Function Create-TunnelConfiguration {
    Write-Header "Creating Server Configuration..."
    $ListenPort = 443
    $DnsServers = @("8.8.8.8")
    $Network = "169.254.0.0/16"
    $script:ServerConfiguration = New-MgDeviceManagementMicrosoftTunnelConfiguration -DisplayName $VmName -ListenPort $ListenPort -DnsServers $DnsServers -Network $Network -AdvancedSettings @() -DefaultDomainSuffix "" -RoleScopeTagIds @("0") -RouteExcludes @() -RouteIncludes @() -SplitDns @()    
}

Function Delete-TunnelConfiguration {
    Write-Header "Deleting Server Configuration..."
    $script:ServerConfiguration = Get-MgDeviceManagementMicrosoftTunnelConfiguration -Filter "displayName eq '$VmName'" -Limit 1
    if($ServerConfiguration) {
        Remove-MgDeviceManagementMicrosoftTunnelConfiguration -MicrosoftTunnelConfigurationId $ServerConfiguration.Id
    } else {
        Write-Host "Server Configuration '$VmName' does not exist."
    }
}

Function Create-TunnelSite {
    Write-Header "Creating Site..."
    $script:Site = New-MgDeviceManagementMicrosoftTunnelSite -DisplayName $VmName -PublicAddress $FQDN -MicrosoftTunnelConfiguration @{id=$ServerConfiguration.id} -RoleScopeTagIds @("0") -UpgradeAutomatically    
}

Function Delete-TunnelSite {
    Write-Header "Deleting Site..."
    $script:Site = Get-MgDeviceManagementMicrosoftTunnelSite -Filter "displayName eq '$VmName'" -Limit 1
    if($Site) {
        Remove-MgDeviceManagementMicrosoftTunnelSite -MicrosoftTunnelSiteId $Site.Id
    } else {
        Write-Host "Site '$VmName' does not exist."
    }
}

Function CreateOrUpdate-ADApplication {
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

Function Create-Flow {
    Check-Prerequisites
    Login
    Detect-Variables
    Create-ResourceGroup
    Create-VM
    Create-NetworkRules
    Move-SSHKeys
    #Stage-SetupScript
    CreateOrUpdate-ADApplication
    Create-TunnelConfiguration
    Create-TunnelSite
    Logout
}

Function Delete-Flow {
    Check-Prerequisites
    Login
    Detect-Variables
    Delete-ResourceGroup
    Delete-SSHKeys
    Delete-TunnelSite
    Delete-TunnelConfiguration
    Logout
}

if ($Delete) {
    Delete-Flow
} else {
    Create-Flow
}

# Write-Header "Marking setup scripts as executable..."
# ssh -i $sshKeyPath -o "StrictHostKeyChecking=no" "$($username)@$($fqdns)" "chmod +x ~/InstallServer.sh"
# ssh -i $sshKeyPath -o "StrictHostKeyChecking=no" "$($username)@$($fqdns)" "chmod +x ~/Setup.sh"

# Write-Header "Connecting into remote server..."
# ssh -i $sshKeyPath -o "StrictHostKeyChecking=no" "$($username)@$($fqdns)"