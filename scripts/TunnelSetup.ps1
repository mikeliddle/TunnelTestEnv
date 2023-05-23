#region Setup Script
Function Initialize-TunnelServer {
    param(
        [String] $FQDN,
        [String] $SiteId,
        [String] $Environment,
        [string] $sshKeyPath,
        [string] $username = "azureuser"
    )

    Write-Header "Generating setup script..."
    $ServerName = $FQDN.Split('.')[0]

    scp -i $sshKeyPath -o "StrictHostKeyChecking=no" ./scripts/createTunnel.sh "$($username)@$($FQDN):~/" > $null
    scp -i $sshKeyPath -o "StrictHostKeyChecking=no" ./scripts/setup-expect.sh "$($username)@$($FQDN):~/" > $null

    $Content = Get-Content ./scripts/setup.exp
    $Content = $Content -replace "##SITE_ID##", "$SiteId"
    Set-Content -Path ./scripts/setup.exp -Value $Content -Force

    ssh -i $sshKeyPath -o "StrictHostKeyChecking=no" "$($username)@$($FQDN)" "chmod +x ~/Setup.sh"
}

Function Initialize-SetupScript {
    param(
        [String] $FQDN,
        [String] $Environment,
        [Switch] $NoProxy,
        [Switch] $UseEnterpriseCa,
        [String] $Email,
        [Microsoft.Graph.PowerShell.Models.IMicrosoftGraphMicrosoftTunnelSite] $Site,
        [string] $username = "azureuser"
    )

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
        cp ../tunnel.pac.tmp nginx_data/tunnel.pac

        git submodule update --init >> install.log 2>&1

        chmod +x scripts/*
        
        PUBLIC_IP=`$(curl ifconfig.me)
        $(if (-Not $NoProxy) {"sed -i.bak -e 's/##PROXY_IP##/$ProxyIP/' -e's/# local-data/local-data/'  unbound.conf.d/a-records.conf"})
        sed -i.bak -e "s/SERVER_NAME=/SERVER_NAME=$ServerName/" -e "s/DOMAIN_NAME=/DOMAIN_NAME=$FQDN/" -e "s/SERVER_PUBLIC_IP=/SERVER_PUBLIC_IP=`$PUBLIC_IP/" -e "s/EMAIL=/EMAIL=$Email/" -e "s/SITE_ID=/SITE_ID=$($Site.Id)/" vars
        export SETUP_ARGS="-i$(if ($UseEnterpriseCa) {"e"})"
        
        ./scripts/setup-expect.sh
        
        expect -f ./scripts/setup.exp
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
    param(
        [string] $sshKeyPath,
        [string] $Username,
        [string] $FQDN
    )
    Write-Header "Connecting into remote server..."
    ssh -i $sshKeyPath -o "StrictHostKeyChecking=no" "$($username)@$($FQDN)" "sudo su -c './Setup.sh'"
}

Function New-TunnelAgent {
    param(
        [string] $RunningOS,
        [Microsoft.Graph.Powershell.Models.IMicrosoftGraphMicrosoftTunnelSite] $Site,
        [pscredential] $TenantCredential
    )

    if (-Not $TenantCredential) {
        $JWT = Invoke-Expression "mstunnel-utils/mstunnel-$RunningOS.exe Agent $($Site.Id)"
    }
    else {
        $JWT = Invoke-Expression "mstunnel-utils/mstunnel-$RunningOS.exe Agent $($Site.Id) $($TenantCredential.UserName) $($TenantCredential.GetNetworkCredential().Password)"
    }

    return $JWT
}

Function New-DnsServer {
    param(
        [string] $VmName
    )
}
#endregion Setup Script