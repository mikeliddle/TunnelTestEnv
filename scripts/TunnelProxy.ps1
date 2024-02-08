#region Proxy Functions
Function New-ProxyVM {
    Write-Header "Creating VM '$($Context.ProxyVmName)'..."
    return az vm create --location $Context.Location --resource-group $Context.ResourceGroup --name $Context.ProxyVmName --image $Context.ProxyImage --size $Context.ProxySize --ssh-key-values "$($Context.SSHKeyPath).pub" --public-ip-address-dns-name $Context.ProxyVmName --admin-username $Context.Username --only-show-errors | ConvertFrom-Json
}

Function Get-ProxyPrivateIP {
    return az vm list-ip-addresses --resource-group $Context.ResourceGroup --name $Context.ProxyVmName --query '[0].virtualMachine.network.privateIpAddresses[0]' | ConvertFrom-Json
}

Function Get-ProxyPrivateIPv6 {
    if ($Context.WithIPv6) {
        return az vm list-ip-addresses --resource-group $Context.ResourceGroup --name $Context.ProxyVmName --query '[0].virtualMachine.network.privateIpAddresses[1]' | ConvertFrom-Json
    }
    else {
        return ""
    }
}

Function Initialize-Proxy {
    try {
        $configFile = Join-Path $pwd -ChildPath "proxy" -AdditionalChildPath "squid.conf"
        $ExcludeDomainFile = Join-Path $pwd -ChildPath "proxy" -AdditionalChildPath "ssl_exclude_domains"

        if ($Context.AuthenticatedProxyCredentials) {
            $passwordsFile = Join-Path $pwd -ChildPath "proxy" -AdditionalChildPath "passwords.tmp"
            $basicAuthFile = Join-Path $pwd -ChildPath "proxy" -AdditionalChildPath "basicAuth.conf"
            Write-Header "Creating basic authentication users for proxy..."

            foreach ($cred in $Context.AuthenticatedProxyCredentials) {
                "$($cred.UserName):$($cred.GetNetworkCredential().Password)" | Add-Content $passwordsFile
            }
            $basicAuthConfig = Get-Content $basicAuthFile -Raw
        }
        else {
            $basicAuthConfig = ""
        }

        if ($Context.UseInspection) {
            Write-Header "Setting up proxy for TLS inspection..."
            (Get-Content $ExcludeDomainFile) -replace "##DOMAIN_NAME##", "$Context.TunnelFQDN" | out-file (Join-Path $pwd -ChildPath "proxy" -AdditionalChildPath "ssl_exclude_domains.tmp")
            $breakAndInspectConfig = Join-Path $pwd -ChildPath "proxy" -AdditionalChildPath "BreakAndInspect.conf"
            $breakAndInspectConfig = Get-Content $breakAndInspectConfig -Raw
        }
        else {
            $breakAndInspectConfig = Join-Path $pwd -ChildPath "proxy" -AdditionalChildPath "vanilla.conf"
            $breakAndInspectConfig = Get-Content $breakAndInspectConfig -Raw
        }

        if ($Context.UseAllowList) {
            $allowlistConfig = Join-Path $pwd -ChildPath "proxy" -AdditionalChildPath "allowlist.conf"
            $allowlistConfig = Get-Content $allowlistConfig -Raw
        }
        else {
            $allowlistConfig = ""
        }

        $allowlistFile = Join-Path $pwd -ChildPath "proxy" -AdditionalChildPath "allowlist"
        $proxyScript = Join-Path $pwd -ChildPath "scripts" -AdditionalChildPath "proxySetup.sh"
        $pacFile = Join-Path $pwd -ChildPath "nginx_data" -AdditionalChildPath "tunnel.pac"

        (Get-Content $configFile) -replace "##DOMAIN_NAME##", "$($Context.TunnelFQDN)" -replace "##BASIC_AUTH##", "$basicAuthConfig" -replace "##BREAK_AND_INSPECT##", "$breakAndInspectConfig" -replace "##ALLOWLIST##", "$allowlistConfig" | out-file "$configFile.tmp"
        (Get-Content $allowlistFile) -replace "##DOMAIN_NAME##", "$($Context.TunnelFQDN)" | out-file "$allowlistFile.tmp"

        $ProxyURL = "proxy.$($Context.TunnelFQDN)"
        (Get-Content $pacFile) -replace "##PROXY_URL##", "$ProxyURL" | out-file "$pacFile.tmp"
        $pacFile = "$pacFile.tmp"

        $proxyBypassNames = [Constants]::DefaultBypassUrls
        foreach ($name in $proxyBypassNames) {
            (Get-Content $pacFile) -replace "// PROXY_BYPASS_NAMES", "`nif (shExpMatch(host, '$($name)')) { return bypass; } // PROXY_BYPASS_NAMES" | out-file "$pacFile"
        }

        # Replace CR+LF and CR with LF
        $text = [IO.File]::ReadAllText($proxyScript) -replace "`r`n", "`n" -replace "`r", "`n"
        [IO.File]::WriteAllText($proxyScript, $text)

        Write-Header "Copying proxy script to remote server..."

        scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$configFile.tmp" "$($Context.Username)@$("$($Context.ServiceFQDN)"):~/squid.conf" > $null
        scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$allowlistFile.tmp" "$($Context.Username)@$("$($Context.ServiceFQDN)"):~/allowlist" > $null
        scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$proxyScript" "$($Context.Username)@$("$($Context.ServiceFQDN)"):~/" > $null
        scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "proxy/ssl_error_domains" "$($Context.Username)@$("$($Context.ServiceFQDN)"):~/" > $null
        scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$ExcludeDomainFile.tmp" "$($Context.Username)@$("$($Context.ServiceFQDN)"):~/ssl_exclude_domains" > $null
        scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "proxy/ssl_exclude_ips" "$($Context.Username)@$("$($Context.ServiceFQDN)"):~/" > $null

        scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$pacFile" "$($Context.Username)@$("$($Context.ServiceFQDN)"):~/" > $null

        if ($Context.AuthenticatedProxyCredentials) {
            scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$passwordsFile" "$($Context.Username)@$("$($Context.ServiceFQDN)"):~/passwords" > $null
        }

        Write-Header "Marking proxy scripts as executable..."
        ssh -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$($Context.Username)@$($Context.ServiceFQDN)" "chmod +x ~/proxySetup.sh"
    }
    finally {
        # Clean up any passwords file if it is present
        if ($passwordsFile) {
            if (Test-Path $passwordsFile) {
                Remove-Item $passwordsFile
            }
        }
    }
}

Function Invoke-ProxyScript {
    Write-Header "Connecting into remote server..."

    $flags = ""
    if ($Context.AuthenticatedProxyCredentials) {
        $flags += " -a"
    }

    ssh -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$($Context.Username)@$("$($Context.ServiceFQDN)")" "sudo su -c './proxySetup.sh$flags'"
}
#endregion Proxy Functions