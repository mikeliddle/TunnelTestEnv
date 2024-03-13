#region Azure Functions
Function Login-Azure {
    param(
        [PSCredential] $VmTenantCredential = $null
    )
    
    if ($VmTenantCredential) {
        az login -u $VmTenantCredential.Username -p $VmTenantCredential.GetNetworkCredential().Password --only-show-errors | Out-Null
    }

    $accounts = az account show --only-show-errors | ConvertFrom-Json

    if ($accounts.Count -eq 0) {
        Write-Header "Logging into Azure..."

        az login --only-show-errors | Out-Null
        
        if (!$Context.SubscriptionId) {
            $accounts = (az account list | ConvertFrom-Json)
            if ($accounts.Count -gt 1) {
                foreach ($account in $accounts) {
                    Write-Host "$($account.name) - $($account.id)"
                }
                $script:Context.SubscriptionId = Read-Host "Please specify a subscription id: "
            }
            else {
                $script:Context.SubscriptionId = $accounts[0].id
            }
        }

        Write-Header "Setting subscription to $($Context.SubscriptionId)"
        az account set --subscription $Context.SubscriptionId | Out-Null
    }
    elseif ($Context.SubscriptionId -And $accounts[0].id -ne $Context.SubscriptionId) {
        Write-Warning "Already logged into Azure CLI as $($accounts[0].user.name)"
        Write-Warning "If you don't want to use this account, please run 'az logout', then run this script again."
        Write-Header "Setting subscription to $($Context.SubscriptionId)"
        az account set --subscription $Context.SubscriptionId | Out-Null
    }
    else {
        Write-Warning "Already logged into Azure CLI as $($accounts[0].user.name)"
        Write-Warning "Using subscription $($accounts[0].id)"
        Write-Warning "If you don't want to use this account, please run 'az logout', then run this script again."
    }
}
Function New-ResourceGroup {
    Write-Header "Checking for resource group '$($Context.ResourceGroup)'..."
    if ([bool](az group show --name $Context.ResourceGroup 2> $null)) {
        Write-Error "Group '$($Context.ResourceGroup)' already exists"
        exit -1
    }
    
    Write-Header "Creating resource group '$($Context.ResourceGroup)'..."
    az group create --location $Context.Location --name $Context.ResourceGroup --only-show-errors | Out-Null
}

Function Remove-ResourceGroup {
    Write-Header "Checking for resource group '$($Context.ResourceGroup)'..."
    if ([bool](az group show --name $Context.ResourceGroup 2> $null)) {
        Write-Header "Deleting resource group '$($Context.ResourceGroup)'..."
        az group delete --name $Context.ResourceGroup --yes --no-wait
    }
    else {
        Write-Host "Group '$Context.ResourceGroup' does not exist"
    }
}

Function New-Network {
    $Context.NSGName = "$($Context.VmName)-VNET-NSG"
    $Context.VnetName = "$($Context.VmName)-VNET"
    $Context.SubnetName = "$($Context.VmName)-Subnet"
    $Context.TunnelNicName = "$($Context.VmName)-NIC"
    $publicIPv4Name = "PublicIPv4"

    Write-Header "Creating network $($Context.VnetName)..."

    # Get the local IP address so we can open port 22 for machines on the same subnet.
    $LocalIP = Invoke-WebRequest https://api.ipify.org      
    $LocalIP = $LocalIP.Content
    $LocalIP = $LocalIP.Split(".") | Select -Index 0,1
    $LocalIP = $LocalIP | Join-String -Separator "."
    $LocalIP = "$LocalIP.0.0/16"

    az network nsg create --name $Context.NSGName --resource-group $Context.ResourceGroup --only-show-errors | Out-Null
    az network nsg rule create --resource-group $Context.ResourceGroup --nsg-name $Context.NSGName --name "AllowSSHIN" --priority 1000  --source-address-prefixes "$LocalIP" --source-port-ranges '*' --destination-port-ranges 22 --access Allow --protocol Tcp --direction Inbound --only-show-errors | Out-Null
    az network nsg rule create --resource-group $Context.ResourceGroup --nsg-name $Context.NSGName --name "AllowHTTPSIn" --priority 100 --source-address-prefixes 'Internet' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 443 --access Allow --protocol '*' --description "Allow HTTPS" --only-show-errors | Out-Null
    az network public-ip create --resource-group $Context.ResourceGroup --name $publicIPv4Name --sku Standard --version IPv4 --dns-name $Context.VmName --only-show-errors | Out-Null 

    if (!$Context.WithIPv6) {
        # Create IPv4 network.
        az network vnet create --name $Context.VnetName --resource-group $Context.ResourceGroup --only-show-errors | Out-Null
        az network vnet subnet create --network-security-group $Context.NSGName --vnet-name $Context.VnetName --name $Context.SubnetName --address-prefixes "10.0.0.0/24" --resource-group $Context.ResourceGroup --only-show-errors | Out-Null

        az network nic create --resource-group $Context.ResourceGroup --name $Context.TunnelNicName --vnet-name $Context.VnetName --subnet $Context.SubnetName --public-ip-address $publicIPv4Name --network-security-group $Context.NSGName | Out-Null 
    }
    else {
        # Create IPv6 network.
        # For now, hardcode the IPv6 prefix to 2404:f800:8000:122::.
        az network vnet create --name $Context.VnetName --resource-group $Context.ResourceGroup --address-prefixes 10.0.0.0/16 2404:f800:8000:122::/63 --subnet-name $Context.SubnetName --subnet-prefixes 10.0.0.0/24 2404:f800:8000:122::/64 | Out-Null 

        # Create a Network Interface Card (NIC) for the gateway server.
        $publicIPv6Name = "PublicIPv6"
        $IPv6ConfigName = "IPv6Config"
        $Context.TunnelGatewayIPv6Address = az network public-ip create --resource-group $Context.ResourceGroup --name $publicIPv6Name --sku Standard --version IPv6 --dns-name "$($Context.VmName)ipv6" --only-show-errors | ConvertFrom-Json
        $Context.TunnelGatewayIPv6Address = $Context.TunnelGatewayIPv6Address.publicIp
        az network nic create --resource-group $Context.ResourceGroup --name $Context.TunnelNicName --vnet-name $Context.VnetName --subnet $Context.SubnetName --public-ip-address $publicIPv4Name --network-security-group $Context.NSGName | Out-Null 
        az network nic ip-config create --resource-group $Context.ResourceGroup --name $IPv6ConfigName --nic-name $Context.TunnelNicName --private-ip-address-version IPv6 --vnet-name $Context.VnetName --subnet $Context.SubnetName --public-ip-address $publicIPv6Name | Out-Null  

        # Create a Network Interface Card (NIC) for the container server.
        $publicIPv4Name = "ServicePublicIPv4"
        $publicIPv6Name = "ServicePublicIPv6"
        $IPv6ConfigName = "ServiceIPv6Config"
        $nicName = "$($Context.VmName)-NIC-Server"
        az network public-ip create --resource-group $Context.ResourceGroup --name $publicIPv4Name --sku Standard --version IPv4 --dns-name "$($Context.VmName)-server" --only-show-errors | Out-Null 
        $Context.TunnelServiceIPv6Address = az network public-ip create --resource-group $Context.ResourceGroup --name $publicIPv6Name --sku Standard --version IPv6 --dns-name "$($Context.VmName)ipv6-service" --only-show-errors | ConvertFrom-Json
        $Context.TunnelServiceIPv6Address = $Context.TunnelServiceIPv6Address.publicIp
        az network nic create --resource-group $Context.ResourceGroup --name $nicName --vnet-name $Context.VnetName --subnet $Context.SubnetName --public-ip-address $publicIPv4Name --network-security-group $Context.NSGName | Out-Null 
        az network nic ip-config create --resource-group $Context.ResourceGroup --name $IPv6ConfigName --nic-name $nicName --private-ip-address-version IPv6 --vnet-name $Context.VnetName --subnet $Context.SubnetName --public-ip-address $publicIPv6Name | Out-Null  
        $script:Context.ServiceNicName = $nicName    
    }
}

Function Remove-SSHRule {
    if (!$Context.WithSSHOpen) {
        Write-Header "Removing SSH rule..."
        az network nsg rule delete --resource-group $Context.ResourceGroup --nsg-name $Context.NSGName -n "AllowSSHIN" --only-show-errors | Out-Null
    }
}

Function New-TunnelVM {    
    Write-Header "Creating VM '$($Context.VmName)'..."
    az vm create --location $Context.Location --resource-group $Context.ResourceGroup --name $Context.VmName --image $Context.Image --size $Context.Size --ssh-key-values "$($Context.SSHKeyPath).pub" --public-ip-address-dns-name $Context.VmName --admin-username $Context.Username --nics $Context.TunnelNicName --enable-auto-update --patch-mode AutomaticByPlatform --only-show-errors | Out-Null
    Update-GeneralVMProperties -vmName $vmName

    if ($Context.BootDiagnostics) {
        Write-Header "Enabling boot diagnostics..."
        az vm boot-diagnostics enable --resource-group $Context.ResourceGroup --name $Context.VmName
    }
}

Function New-ServiceVM { 
    $vmName = "$($Context.VmName)-server"  
    Write-Header "Creating VM '$vmName'..."
    if ($Context.WithIPv6) {
        # Create a VM with our NIC.
        az vm create --location $Context.Location --resource-group $Context.ResourceGroup --name $vmName --image $([Constants]::ServerVMImage) --size $Context.Size --ssh-key-values "$($Context.SSHKeyPath).pub" --only-show-errors --admin-username $Context.Username --enable-auto-update --patch-mode AutomaticByPlatform --nics $Context.ServiceNicName  | Out-Null
    } 
    else {
        # Create a VM, and let Azure create a NIC.
        az vm create --location $Context.Location --resource-group $Context.ResourceGroup --name $vmName --image $([Constants]::ServerVMImage) --size $Context.Size --ssh-key-values "$($Context.SSHKeyPath).pub" --only-show-errors --admin-username $Context.Username --enable-auto-update --patch-mode AutomaticByPlatform --public-ip-address-dns-name "$($Context.VmName)-server" --vnet-name $Context.VnetName --subnet $Context.SubnetName | Out-Null
    }
    Update-GeneralVMProperties -vmName $vmName
}

Function Update-GeneralVMProperties([string] $vmName) {
    Write-Information "Updating general properties for '$vmName'..."
    az vm update --name $vmName --resource-group $Context.ResourceGroup --set osProfile.linuxConfiguration.patchSettings.assessmentMode=AutomaticByPlatform # Set the VM to periodically check for updates (once every 24 hours).
    az vm update --name $Context.VmName --resource-group $Context.ResourceGroup --set tags.AzSecPackAutoConfigReady=true # Enable AzSecPack
}

Function Update-RebootVM {
    az vm restart --resource-group $Context.ResourceGroup --name $Context.VmName
}
#endregion Azure Functions
