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
    $NsgName = "$($Context.VmName)-VNET-NSG"
    $script:Context.VnetName = "$($Context.VmName)-VNET"
    $script:Context.SubnetName = "$($Context.VmName)-Subnet"

    Write-Header "Creating network $($Context.VnetName)..."

    az network nsg create --name $NsgName --resource-group $Context.ResourceGroup --only-show-errors | Out-Null
    $LocalIP = Invoke-WebRequest https://api.ipify.org

    $LocalIP = $LocalIP.Content
    $LocalIP = $LocalIP.Split(".") | Select -Index 0,1
    $LocalIP = $LocalIP | Join-String -Separator "."
    $LocalIP = "$LocalIP.0.0/16"
    
    az network nsg rule create --resource-group $Context.ResourceGroup --nsg-name $NsgName --name "AllowSSHIN" --priority 1000  --source-address-prefixes "$LocalIP" --source-port-ranges '*' --destination-port-ranges 22 --access Allow --protocol Tcp --direction Inbound --only-show-errors | Out-Null
    
    az network nsg rule create --resource-group $Context.ResourceGroup --nsg-name $NsgName --name "AllowHTTPSIn" --priority 100 --source-address-prefixes 'Internet' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 443 --access Allow --protocol '*' --description "Allow HTTPS" --only-show-errors | Out-Null

    az network vnet create --name $Context.VnetName --resource-group $Context.ResourceGroup --only-show-errors | Out-Null
    az network vnet subnet create --network-security-group $NsgName --vnet-name $Context.VnetName --name "$($Context.SubnetName)" --address-prefixes "10.0.0.0/24" --resource-group $Context.ResourceGroup --only-show-errors | Out-Null
}

Function Remove-SSHRule {
    if (!$Context.WithSSHOpen) {
        Write-Header "Removing SSH rule..."
        az network nsg rule delete --resource-group $Context.ResourceGroup --nsg-name "$($script:Context.VnetName)-NSG" -n "AllowSSHIN" --only-show-errors | Out-Null
    }
}

Function New-TunnelVM {    
    Write-Header "Creating VM '$($Context.VmName)'..."
    az vm create --location $Context.Location --resource-group $Context.ResourceGroup --name $Context.VmName --image $Context.Image --size $Context.Size --ssh-key-values "$($Context.SSHKeyPath).pub" --public-ip-address-dns-name $Context.VmName --admin-username $Context.Username --vnet-name $Context.VnetName --subnet $Context.SubnetName --only-show-errors | Out-Null

    if ($Context.BootDiagnostics) {
        Write-Header "Enabling boot diagnostics..."
        az vm boot-diagnostics enable --resource-group $Context.ResourceGroup --name $Context.VmName
    }
}

Function New-NetworkRules {
    Write-Header "Creating network rules..."
    
    if ($Context.WithSSHOpen) {
        az network nsg rule create --resource-group $Context.ResourceGroup --nsg-name "$($Context.VmName)NSG" -n SSHIN --priority 100 --source-address-prefixes '*' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 22 --access Allow --protocol Tcp --description "Allow SSH" > $null
    }
    
    az network nsg rule create --resource-group $Context.ResourceGroup --nsg-name "$($Context.VmName)NSG" -n HTTPIN --priority 101 --source-address-prefixes 'Internet' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 443 --access Allow --protocol '*' --description "Allow HTTP" > $null
}

Function New-AdvancedNetworkRules {
    Write-Header "Creating network rules..."

    if ($Context.WithSSHOpen) {
        az network nsg rule create --resource-group $Context.ResourceGroup --nsg-name "$($Context.VmName)NSG" -n "AllowSSHIn" --priority 101 --source-address-prefixes '*' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 22 --access Allow --protocol Tcp --description "Allow SSH" > $null
    }

    az network nsg rule create --resource-group $Context.ResourceGroup --nsg-name "$($Context.VmName)NSG" -n "AllowHTTPSIn" --priority 100 --source-address-prefixes 'Internet' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 443 --access Allow --protocol '*' --description "Allow HTTPS" > $null

    if ($Context.WithSSHOpen) {
        az network nsg rule create --resource-group $Context.ResourceGroup --nsg-name "$($Context.VmName)-serverNSG" -n "AllowSSHIn" --priority 101 --source-address-prefixes '*' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 22 --access Allow --protocol Tcp --description "Allow SSH" > $null
    }

    az network nsg rule create --resource-group $Context.ResourceGroup --nsg-name "$($Context.VmName)-serverNSG" -n "AllowHTTPSIn" --priority 100 --source-address-prefixes 'Internet' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 443 --access Allow --protocol '*' --description "Allow HTTPS" > $null
}

Function New-ServiceVM {    
    Write-Header "Creating VM '$($Context.VmName)-server'..."
    az vm create --location $Context.Location --resource-group $Context.ResourceGroup --name "$($Context.VmName)-server" --image $Context.Image --size $Context.Size --ssh-key-values "$($Context.SSHKeyPath).pub" --public-ip-address-dns-name "$($Context.VmName)-server" --admin-username $Context.Username --vnet-name $Context.VnetName --subnet $Context.SubnetName --only-show-errors | Out-Null
}

Function Update-RebootVM {
    az vm restart --resource-group $Context.ResourceGroup --name $Context.VmName
}
#endregion Azure Functions
