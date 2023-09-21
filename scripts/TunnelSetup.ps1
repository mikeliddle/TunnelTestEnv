#region Setup Script
Function Initialize-TunnelServer {
    Write-Header "Generating setup script..."

    scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" ./scripts/createTunnel.sh "$($Context.Username)@$($Context.TunnelFQDN):~/" > $null
    scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" ./scripts/setup-expect.sh "$($Context.Username)@$($Context.TunnelFQDN):~/" > $null
    scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" ./scripts/serverchain.pem.tmp "$($Context.Username)@$($Context.TunnelFQDN):~/serverchain.pem" > $null
    scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" ./scripts/server.key.tmp "$($Context.Username)@$($Context.TunnelFQDN):~/server.key" > $null


    $Content = Get-Content ./scripts/setup.exp
    $Content = $Content -replace "##SITE_ID##", "$($Context.TunnelSite.Id)"

    if ($Context.NoPki) {
        $Content = $Content -replace "##ARGS##", "-c ./letsencrypt.pem -k ./letsencrypt.key"
    }
    else {
        $Content = $Content -replace "##ARGS##", "-c ./serverchain.pem -k ./server.key"
    }
    
    Set-Content -Path ./scripts/setup.exp.tmp -Value $Content -Force
    scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" ./scripts/setup.exp.tmp "$($Context.Username)@$($Context.TunnelFQDN):~/setup.exp" > $null

    ssh -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$($Context.Username)@$($Context.TunnelFQDN)" "chmod +x ~/createTunnel.sh"
    ssh -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$($Context.Username)@$($Context.TunnelFQDN)" "chmod +x ~/setup-expect.sh"
    ssh -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$($Context.Username)@$($Context.TunnelFQDN)" "chmod +x ~/setup.exp"
}

Function Initialize-SetupScript {
    try {
        Write-Header "Generating setup script..."
        $Content = @"
        export intune_env=$($Context.Environment);

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
        scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" ./Setup.sh "$($Context.Username)@$($Context.TunnelFQDN):~/" > $null
        scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" ./agent.p12 "$($Context.Username)@$($Context.TunnelFQDN):~/" > $null
        scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" ./agent-info.json "$($Context.Username)@$($Context.TunnelFQDN):~/" > $null

        Write-Header "Marking setup scripts as executable..."
        ssh -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$($Context.Username)@$($Context.TunnelFQDN)" "chmod +x ~/Setup.sh"
    }
    finally {
        Remove-Item "./Setup.sh"
    }
}

Function Invoke-SetupScript {
    Write-Header "Connecting into remote server..."
    ssh -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$($Context.Username)@$($Context.TunnelFQDN)" "sudo su -c './Setup.sh'"
}

Function New-TunnelAgent {
    param(
        [pscredential] $TenantCredential
    )

    if (-Not $TenantCredential) {
        $JWT = Invoke-Expression "mstunnel-utils/mstunnel-$($Context.RunningOS).exe Agent $($Context.TunnelSite.Id)"
    }
    else {
        $JWT = Invoke-Expression "mstunnel-utils/mstunnel-$($Context.RunningOS).exe Agent $($Context.TunnelSite.Id) '$($TenantCredential.Username)' '$($TenantCredential.GetNetworkCredential().Password)'"
    }

    

    return $JWT
}
#endregion Setup Script