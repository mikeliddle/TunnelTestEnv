Function New-BasicPki {
    param(
        [string] $ServiceVMDNS,
        [string] $TunnelVMDNS,
        [string] $Username,
        [string] $SSHKeyPath
    )

    Write-Header "Generating PKI..."
    scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" ./scripts/createCerts.sh "$($Username)@$($ServiceVMDNS):~/" > $null

    ssh -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$($ServiceVMDNS)" "chmod +x ~/createCerts.sh"
    ssh -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$($ServiceVMDNS)" "./createCerts.sh -risux -c `"$TunnelVMDNS`" -a `"DNS.1 = $TunnelVMDNS\nDNS.2 = *.$TunnelVMDNS\nDNS.3 = trusted\nDNS.4 = webapp\nDNS.5 = excluded`""

    scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$($ServiceVMDNS):~/serverchain.pem" ./serverchain.pem > $null
    scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$($ServiceVMDNS):~/server.key" ./server.key > $null
}

Function New-DnsServer {
    param(
        [string] $VmName
    )
}