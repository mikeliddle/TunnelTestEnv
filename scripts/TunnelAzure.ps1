#region Azure Functions
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
    } else {
        Write-Host "Group '$resourceGroup' does not exist"
    }
}

Function New-TunnelVM {
    param(
        [string] $VmName,
        [string] $Username = "azureuser",
        [string] $Image = "Canonical:0001-com-ubuntu-server-focal:20_04-lts:latest",
        [string] $Size = "Standard_B2s",
        [string] $SSHKeyPath = "$HOME/.ssh/$VmName",
        [string] $location = "westus",
        [string] $resourceGroup = "$VmName-group"
    )
    
    Write-Header "Creating VM '$VmName'..."
    $vmdata = az vm create --location $location --resource-group $resourceGroup --name $VmName --image $Image --size $Size --ssh-key-values "$SSHKeyPath.pub" --public-ip-address-dns-name $VmName --admin-username $Username --only-show-errors | ConvertFrom-Json

    Write-Host "DNS is '$vmdata.fqdns'"
    return $vmdata
}

Function New-NetworkRules {
    param(
        [string] $resourceGroup,
        [string] $VmName,
        [bool] $WithSSHOpen = $false
    )
    Write-Header "Creating network rules..."
    
    if ($WithSSHOpen)
    {
        az network nsg rule create --resource-group $resourceGroup --nsg-name "$($VmName)NSG" -n SSHIN --priority 100 --source-address-prefixes '*' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 22 --access Allow --protocol Tcp --description "Allow SSH" > $null
    }
    
    az network nsg rule create --resource-group $resourceGroup --nsg-name "$($VmName)NSG" -n HTTPIN --priority 101 --source-address-prefixes 'Internet' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 443 --access Allow --protocol '*' --description "Allow HTTP" > $null
}

Export-ModuleMember -Function New-ResourceGroup, Remove-ResourceGroup, New-TunnelVM, New-NetworkRules
#endregion Azure Functions