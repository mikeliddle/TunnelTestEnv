#region Proxy Functions
Function New-ProxyVM {
    param(
        [string] $VmName,
        [string] $Username = "azureuser",
        [string] $Image = "Canonical:0001-com-ubuntu-server-focal:20_04-lts:latest",
        [string] $ProxySize = "Standard_B2s",
        [string] $SSHKeyPath = "$HOME/.ssh/$VmName",
        [string] $location = "westus",
        [string] $ResourceGroup = "$VmName-group"

    )

    Write-Header "Creating VM '$VmName'..."
    return az vm create --location $location --resource-group $ResourceGroup --name $VmName --image $Image --size $ProxySize --ssh-key-values "$SSHKeyPath.pub" --public-ip-address-dns-name $VmName --admin-username $Username --only-show-errors | ConvertFrom-Json
}

Function Get-ProxyPrivateIP {
    param(
        [string] $VmName,
        [string] $ResourceGroup = "$VmName-group"
    )
    return az vm list-ip-addresses --resource-group $ResourceGroup --name $VmName --query '[0].virtualMachine.network.privateIpAddresses[0]' | ConvertFrom-Json
}

Function Initialize-Proxy {
    param(
        [string] $VmName,
        [Object] $ProxyVMData,
        [string] $Username = "azureuser",
        [string] $SSHKeyPath = "$HOME/.ssh/$VmName",
        [string] $TunnelServer = "$VmName.westus.cloudapp.azure.com",
        [string] $ResourceGroup = "$VmName-group"
    )

    $configFile = Join-Path $pwd -ChildPath "proxy" -AdditionalChildPath "squid.conf"
    $allowlistFile = Join-Path $pwd -ChildPath "proxy" -AdditionalChildPath "allowlist"
    $proxyScript = Join-Path $pwd -ChildPath "scripts" -AdditionalChildPath "proxySetup.sh"
    $pacFile = Join-Path $pwd -ChildPath "nginx_data" -AdditionalChildPath "tunnel.pac"

    (Get-Content $configFile) -replace "##DOMAIN_NAME##","$TunnelServer" | out-file "$configFile.tmp"
    (Get-Content $allowlistFile) -replace "##DOMAIN_NAME##","$TunnelServer" | out-file "$allowlistFile.tmp"

    $proxyBypassNames = ("www.google.com", "excluded.$($TunnelServer)")
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

    scp -i $sshKeyPath -o "StrictHostKeyChecking=no" "$pacFile.tmp" "$($username)@$("$TunnelServer"):~/" > $null

    Write-Header "Marking proxy scripts as executable..."
    ssh -i $sshKeyPath -o "StrictHostKeyChecking=no" "$($username)@$($ProxyVMData.fqdns)" "chmod +x ~/proxySetup.sh"
}

Function Invoke-ProxyScript {
    param(
        [Object] $ProxyVMData,
        [string] $Username = "azureuser",
        [string] $SSHKeyPath = "$HOME/.ssh/$VmName"
    )
    Write-Header "Connecting into remote server..."
    ssh -i $sshKeyPath -o "StrictHostKeyChecking=no" "$($username)@$("$($ProxyVMData.fqdns)")" "sudo su -c './proxySetup.sh'"
}

Export-ModuleMember -Function New-ProxyVM, Get-ProxyPrivateIP, Initialize-Proxy, Invoke-ProxyScript
#endregion Proxy Functions