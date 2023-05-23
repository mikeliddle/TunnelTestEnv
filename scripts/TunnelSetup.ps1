#region Setup Script
Function Initialize-TunnelServer {
    param(
        [String] $FQDN,
        [String] $SiteId,
        [string] $SSHKeyPath,
        [string] $Username = "azureuser"
    )

    Write-Header "Generating setup script..."

    scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" ./scripts/createTunnel.sh "$($Username)@$($FQDN):~/" > $null
    scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" ./scripts/setup-expect.sh "$($Username)@$($FQDN):~/" > $null


    $Content = Get-Content ./scripts/setup.exp
    $Content = $Content -replace "##SITE_ID##", "$SiteId"
    $Content = $Content -replace "##ARGS##", "-c ./fullchain.pem -k ./fullchain.key"
    Set-Content -Path ./scripts/setup.exp -Value $Content -Force
    scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" ./setup.exp "$($Username)@$($FQDN):~/" > $null
}

Function Initialize-SetupScript {
    param(
        [String] $FQDN,
        [String] $Environment,
        [Switch] $NoProxy,
        [String] $Email,
        [Microsoft.Graph.PowerShell.Models.IMicrosoftGraphMicrosoftTunnelSite] $Site,
        [string] $Username = "azureuser"
    )

    try{
        Write-Header "Generating setup script..."
        $Content = @"
        export intune_env=$Environment;

        ./setup-expect.sh
        
        expect -f ./setup.exp
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
        scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" ./Setup.sh "$($Username)@$($FQDN):~/" > $null
        scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" ./agent.p12 "$($Username)@$($FQDN):~/" > $null
        scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" ./agent-info.json "$($Username)@$($FQDN):~/" > $null

        Write-Header "Marking setup scripts as executable..."
        ssh -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$($FQDN)" "chmod +x ~/Setup.sh"
    }
    finally {
        Remove-Item "./Setup.sh"
    }
}

Function Invoke-SetupScript {
    param(
        [string] $SSHKeyPath,
        [string] $Username,
        [string] $FQDN
    )
    Write-Header "Connecting into remote server..."
    ssh -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$($FQDN)" "sudo su -c './Setup.sh'"
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
        $JWT = Invoke-Expression "mstunnel-utils/mstunnel-$RunningOS.exe Agent $($Site.Id) $($TenantCredential.Username) $($TenantCredential.GetNetworkCredential().Password)"
    }

    return $JWT
}
#endregion Setup Script