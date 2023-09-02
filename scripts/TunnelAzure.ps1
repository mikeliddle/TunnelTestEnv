#region Azure Functions
Function Login-Azure {
    param(
        [string] $SubscriptionId = "",
        [PSCredential] $VmTenantCredential = $null
    )
    
    if ($VmTenantCredential) {
        az login -u $VmTenantCredential.Username -p $VmTenantCredential.GetNetworkCredential().Password --only-show-errors | Out-Null
        return
    }

    $accounts = az account show --only-show-errors | ConvertFrom-Json

    if ($accounts.Count -eq 0) {
        Write-Header "Logging into Azure..."

        az login --only-show-errors | Out-Null
        
        if (!$SubscriptionId) {
            $accounts = (az account list | ConvertFrom-Json)
            if ($accounts.Count -gt 1) {
                foreach ($account in $accounts) {
                    Write-Host "$($account.name) - $($account.id)"
                }
                $SubscriptionId = Read-Host "Please specify a subscription id: "
            } else {
                $SubscriptionId = $accounts[0].id
            }
        }

        Write-Header "Setting subscription to $SubscriptionId"
        az account set --subscription $SubscriptionId | Out-Null
    } elseif ($accounts[0].id -ne $SubscriptionId) {
        Write-Warning "Already logged into Azure CLI as $($accounts[0].user.name)"
        Write-Warning "If you don't want to use this account, please logout, then run this script again."
        Write-Header "Setting subscription to $SubscriptionId"
        az account set --subscription $SubscriptionId | Out-Null
    } else {
        Write-Warning "Already logged into Azure CLI as $($accounts[0].user.name)"
        Write-Warning "Using subscription $($accounts[0].id)"
        Write-Warning "If you don't want to use this account, please logout, then run this script again."
    }
}
Function New-ResourceGroup {
    param(
        [string] $resourceGroup,
        [string] $location = "westus"
    )

    Write-Header "Checking for resource group '$resourceGroup'..."
    if ([bool](az group show --name $resourceGroup 2> $null)) {
        Write-Error "Group '$resourceGroup' already exists"
        exit -1
    }
    
    Write-Header "Creating resource group '$resourceGroup'..."
    return az group create --location $location --name $resourceGroup --only-show-errors | ConvertFrom-Json
}

Function Remove-ResourceGroup {
    param(
        [string] $resourceGroup
    )
    Write-Header "Checking for resource group '$resourceGroup'..."
    if ([bool](az group show --name $resourceGroup 2> $null)) {
        Write-Header "Deleting resource group '$resourceGroup'..."
        az group delete --name $resourceGroup --yes --no-wait
    }
    else {
        Write-Host "Group '$resourceGroup' does not exist"
    }
}

Function New-Network {
    param (
        [string] $VmName,
        [string] $resourceGroup = "$VmName-group"
    )

    $NsgName="$VmName-VNET-NSG"
    $VnetName="$VmName-VNET"

    Write-Header "Creating network $VnetName..."

    az network nsg create --name $NsgName --resource-group $resourceGroup --only-show-errors | Out-Null
    az network nsg rule create --nsg-name $NsgName --name "AllowSSHIN" --priority 1000 --resource-group $resourceGroup --access Allow --destination-port-ranges 22 --protocol Tcp --direction Inbound
    az network nsg rule create --resource-group $resourceGroup --nsg-name $NsgName -n "AllowHTTPSIn" --priority 100 --source-address-prefixes 'Internet' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 443 --access Allow --protocol '*' --description "Allow HTTPS" > $null

    az network vnet create --name $VnetName --resource-group $resourceGroup
    az network vnet subnet create --network-security-group $NsgName --vnet-name $VnetName --name "$VnetName-subnet" --address-prefixes "10.0.0.0/24" --resource-group $resourceGroup
}

Function New-TunnelVM {
    param(
        [string] $VmName,
        [string] $Username = "azureuser",
        [string] $Image = "Canonical:0001-com-ubuntu-server-focal:20_04-lts:latest",
        [string] $Size = "Standard_B2s",
        [string] $SSHKeyPath = "$HOME/.ssh/$VmName",
        [string] $location = "westus",
        [string] $resourceGroup = "$VmName-group",
        [string] $VnetName = "$VmName-VNET"
    )
    
    Write-Header "Creating VM '$VmName'..."
    $vmdata = az vm create --location $location --resource-group $resourceGroup --name $VmName --image $Image --size $Size --ssh-key-values "$SSHKeyPath.pub" --public-ip-address-dns-name $VmName --admin-username $Username --vnet-name $VnetName --only-show-errors | ConvertFrom-Json

    Write-Host "DNS is '$($vmdata.fqdns)'"
    return $vmdata
}

Function New-NetworkRules {
    param(
        [string] $resourceGroup,
        [string] $VmName,
        [bool] $WithSSHOpen = $false
    )
    Write-Header "Creating network rules..."
    
    if ($WithSSHOpen) {
        az network nsg rule create --resource-group $resourceGroup --nsg-name "$($VmName)NSG" -n SSHIN --priority 100 --source-address-prefixes '*' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 22 --access Allow --protocol Tcp --description "Allow SSH" > $null
    }
    
    az network nsg rule create --resource-group $resourceGroup --nsg-name "$($VmName)NSG" -n HTTPIN --priority 101 --source-address-prefixes 'Internet' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 443 --access Allow --protocol '*' --description "Allow HTTP" > $null
}

Function New-AdvancedNetworkRules {
    param(
        [string] $resourceGroup,
        [string] $ProxyIP,
        [string] $VmName,
        [bool] $WithSSHOpen = $false
    )

    Write-Header "Creating network rules..."

    if ($WithSSHOpen) {
        az network nsg rule create --resource-group $resourceGroup --nsg-name "$($VmName)NSG" -n "AllowSSHIn" --priority 100 --source-address-prefixes '*' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 22 --access Allow --protocol Tcp --description "Allow SSH" > $null
        # az network nsg rule create --resource-group $resourceGroup --nsg-name "$($VmName)NSG" -n "AllowRDPIn" --priority 104 --source-address-prefixes '*' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 3389 --access Allow --protocol Tcp --description "Allow RDP" > $null
    }

    az network nsg rule create --resource-group $resourceGroup --nsg-name "$($VmName)NSG" -n "AllowHTTPSIn" --priority 101 --source-address-prefixes 'Internet' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 443 --access Allow --protocol '*' --description "Allow HTTPS" > $null
    # az network nsg rule create --resource-group $resourceGroup --nsg-name "$($VmName)NSG" -n "AllowOutboundProxy" --priority 102 --source-address-prefixes "$ProxyIP" --source-port-ranges '*' --destination-address-prefixes 'Internet' --destination-port-ranges '*' --access Allow --protocol '*' --description "Allow Proxy Outbound Traffic" > $null
    # az network nsg rule create --resource-group $resourceGroup --nsg-name "$($VmName)NSG" -n "DenyOutboundNoProxy" --priority 103 --source-address-prefixes '10.0.0.0/8' --source-port-ranges '*' --destination-address-prefixes 'Internet' --destination-port-ranges '*' --access Deny --protocol '*' --description "Deny All Outbound Traffic" > $null

    if ($WithSSHOpen) {
        az network nsg rule create --resource-group $resourceGroup --nsg-name "$($VmName)-serverNSG" -n "AllowSSHIn" --priority 100 --source-address-prefixes '*' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 22 --access Allow --protocol Tcp --description "Allow SSH" > $null
        # az network nsg rule create --resource-group $resourceGroup --nsg-name "$($VmName)-serverNSG" -n "AllowRDPIn" --priority 104 --source-address-prefixes '*' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 3389 --access Allow --protocol Tcp --description "Allow RDP" > $null
    }

    az network nsg rule create --resource-group $resourceGroup --nsg-name "$($VmName)-serverNSG" -n "AllowHTTPSIn" --priority 101 --source-address-prefixes 'Internet' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 443 --access Allow --protocol '*' --description "Allow HTTPS" > $null
}

Function New-ServiceVM {
    param(
        [string] $VmName,
        [string] $Username = "azureuser",
        [string] $Image = "Canonical:0001-com-ubuntu-server-focal:20_04-lts:latest",
        [string] $Size = "Standard_B2s",
        [string] $SSHKeyPath = "$HOME/.ssh/$VmName",
        [string] $location = "westus",
        [string] $resourceGroup = "$VmName-group",
        [string] $VnetName = "$VmName-VNET"
    )
    
    Write-Header "Creating VM '$VmName-server'..."
    $vmdata = az vm create --location $location --resource-group $resourceGroup --name "$VmName-server" --image $Image --size $Size --ssh-key-values "$SSHKeyPath.pub" --public-ip-address-dns-name "$VmName-server" --admin-username $Username --vnet-name $VnetName --only-show-errors | ConvertFrom-Json

    Write-Host "DNS is '$($vmdata.fqdns)'"
    return $vmdata
}

Function Update-RebootVM {
    param(
        [string] $VmName,
        [string] $resourceGroup = "$VmName-group"
    )

    az vm restart --resource-group $resourceGroup --name $VmName
}
#endregion Azure Functions
