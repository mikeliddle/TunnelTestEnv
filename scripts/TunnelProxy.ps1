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
        [string] $ResourceGroup = "$VmName-group",
        [switch] $UseInspection = $false,
        [pscredential[]] $AuthenticatedProxyCredentials = $null
    )

    try {
        if ($UseInspection) {
            Write-Header "Setting up proxy for TLS inspection..."
            $configFile = Join-Path $pwd -ChildPath "proxy" -AdditionalChildPath "BreakAndInspect.conf"
            $ExcludeDomainFile = Join-Path $pwd -ChildPath "proxy" -AdditionalChildPath "ssl_exclude_domains"
            (Get-Content $ExcludeDomainFile) -replace "##DOMAIN_NAME##", "$TunnelServer" | out-file (Join-Path $pwd -ChildPath "proxy" -AdditionalChildPath "ssl_exclude_domains.tmp")
        } else {
            $configFile = Join-Path $pwd -ChildPath "proxy" -AdditionalChildPath "squid.conf"
            $ExcludeDomainFile = Join-Path $pwd -ChildPath "proxy" -AdditionalChildPath "ssl_exclude_domains"
        }

        if ($AuthenticatedProxyCredentials) {
            $passwordsFile = Join-Path $pwd -ChildPath "proxy" -AdditionalChildPath "passwords.tmp"
            $basicAuthFile = Join-Path $pwd -ChildPath "proxy" -AdditionalChildPath "basicAuth"
            Write-Header "Creating basic authentication users for proxy..."

            # remove any old temporary passwords file
            Remove-Item $passwordsFile

            foreach ($cred in $AuthenticatedProxyCredentials) {
                "$($cred.UserName):$($cred.GetNetworkCredential().Password)" | Add-Content $passwordsFile
            }

            $basicAuthConfig = Get-Content $basicAuthFile -Raw
        } else {
            $basicAuthConfig = ""
        }

        $allowlistFile = Join-Path $pwd -ChildPath "proxy" -AdditionalChildPath "allowlist"
        $proxyScript = Join-Path $pwd -ChildPath "scripts" -AdditionalChildPath "proxySetup.sh"
        $pacFile = Join-Path $pwd -ChildPath "nginx_data" -AdditionalChildPath "tunnel.pac"

        (Get-Content $configFile) -replace "##DOMAIN_NAME##", "$TunnelServer" -replace "##BASIC_AUTH##", "$basicAuthConfig" | out-file "$configFile.tmp"
        (Get-Content $allowlistFile) -replace "##DOMAIN_NAME##", "$TunnelServer" | out-file "$allowlistFile.tmp"

        $ProxyURL = "proxy.$TunnelServer"
        (Get-Content $pacFile) -replace "##PROXY_URL##", "$ProxyURL" | out-file "$pacFile.tmp"
        $pacFile = "$pacFile.tmp"

        $proxyBypassNames = ("www.google.com", "www.ipchicken.com", "excluded.$($TunnelServer)")
        foreach ($name in $proxyBypassNames) {
            (Get-Content $pacFile) -replace "// PROXY_BYPASS_NAMES", "`nif (shExpMatch(host, '$($name)')) { return bypass; } // PROXY_BYPASS_NAMES" | out-file "$pacFile"
        }

        # Replace CR+LF and CR with LF
        $text = [IO.File]::ReadAllText($proxyScript) -replace "`r`n", "`n" -replace "`r", "`n"
        [IO.File]::WriteAllText($proxyScript, $text)

        Write-Header "Copying proxy script to remote server..."

        scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$configFile.tmp" "$($Username)@$("$($ProxyVMData.fqdns)"):~/squid.conf" > $null
        scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$allowlistFile.tmp" "$($Username)@$("$($ProxyVMData.fqdns)"):~/allowlist" > $null
        scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$proxyScript" "$($Username)@$("$($ProxyVMData.fqdns)"):~/" > $null
        scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" "proxy/ssl_error_domains" "$($Username)@$("$($ProxyVMData.fqdns)"):~/" > $null
        scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$ExcludeDomainFile.tmp" "$($Username)@$("$($ProxyVMData.fqdns)"):~/ssl_exclude_domains" > $null
        scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" "proxy/ssl_exclude_ips" "$($Username)@$("$($ProxyVMData.fqdns)"):~/" > $null

        scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$pacFile" "$($Username)@$("$ProxyVMData"):~/" > $null

        if ($AuthenticatedProxyCredentials) {
            scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$passwordsFile" "$($Username)@$("$($ProxyVMData.fqdns)"):~/passwords" > $null
        }

        Write-Header "Marking proxy scripts as executable..."
        ssh -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$($ProxyVMData.fqdns)" "chmod +x ~/proxySetup.sh"
    }
    finally {
        # Clean up any passwords file if it is present
        if (Test-Path $passwordsFile) {
            Remove-Item $passwordsFile
        }
    }
}

Function Invoke-ProxyScript {
    param(
        [Object] $ProxyVMData,
        [string] $Username = "azureuser",
        [string] $SSHKeyPath = "$HOME/.ssh/$VmName",
        [switch] $UseInspection = $false,
        [pscredential[]] $AuthenticatedProxyCredentials = $null
    )

    Write-Header "Connecting into remote server..."

    if ($UseInspection) {
        ssh -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$("$($ProxyVMData.fqdns)")" "sudo su -c './proxySetup.sh -b'"
    } elseif ($AuthenticatedProxyCredentials) {
        ssh -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$("$($ProxyVMData.fqdns)")" "sudo su -c './proxySetup.sh -a'"
    } else {
        ssh -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$("$($ProxyVMData.fqdns)")" "sudo su -c './proxySetup.sh'"
    }
}
#endregion Proxy Functions