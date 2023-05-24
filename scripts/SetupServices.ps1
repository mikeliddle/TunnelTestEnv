Function New-BasicPki {
    param(
        [string] $ServiceVMDNS,
        [string] $TunnelVMDNS,
        [string] $Username,
        [string] $SSHKeyPath
    )

    Write-Header "Generating PKI..."
    scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" ./scripts/createCerts.sh "$($Username)@$($ServiceVMDNS):~/" > $null
    scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" -r ./openssl.conf.d "$($Username)@$($ServiceVMDNS):~/" > $null

    ssh -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$($ServiceVMDNS)" "chmod +x ~/createCerts.sh"
    ssh -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$($ServiceVMDNS)" "sudo ./createCerts.sh -risux -c `"$TunnelVMDNS`" -a `"DNS.1\=$TunnelVMDNS\nDNS.2\=*.$TunnelVMDNS\nDNS.3\=trusted\nDNS.4\=webapp\nDNS.5\=excluded`""

    scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$($ServiceVMDNS):~/serverchain.pem" ./serverchain.pem > $null
    scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$($ServiceVMDNS):~/server.key" ./server.key > $null
}

Function New-NginxSetup {
    param(
        [string] $TunnelVMDNS,
        [string] $Username,
        [string] $SSHKeyPath,
        [string] $ServiceVMDNS,
        [string] $Email
    )

    Write-Header "Configuring Nginx..."
    scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" ./scripts/createWebservers.sh "$($Username)@$($ServiceVMDNS):~/" > $null
    scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" -r ./nginx.conf.d "$($Username)@$($ServiceVMDNS):~/" > $null
    scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" -r ./nginx_data "$($Username)@$($ServiceVMDNS):~/" > $null

    ssh -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$($ServiceVMDNS)" "chmod +x ~/createWebservers.sh"
    ssh -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$($ServiceVMDNS)" "sudo ./createWebservers.sh -a -d $VmName -e $Email"
}

Function New-DnsServer {
    param(
        [string] $TunnelVMDNS,
        [string] $ProxyIP,
        [string] $Username,
        [string] $SSHKeyPath,
        [string] $ServiceVMDNS
    )

    Write-Header "Creating DNS server..."

    scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" ./scripts/configureDNS.sh "$($Username)@$($ServiceVMDNS):~/" > $null
    scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" -r ./unbound.conf.d/a-records.conf "$($Username)@$($ServiceVMDNS):~/" > $null
    scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" -r ./unbound.conf.d/unbound.conf "$($Username)@$($ServiceVMDNS):~/" > $null

    ssh -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$($ServiceVMDNS)" "chmod +x ~/configureDNS.sh"
    ssh -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$($ServiceVMDNS)" "sudo ./configureDNS.sh"

    ssh -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$($ServiceVMDNS)" "sudo ./configureDNS.sh -u -i $ProxyIP -d proxy.$VmName"
    ssh -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$($ServiceVMDNS)" "sudo ./configureDNS.sh -u -i $ProxyIP -d trusted.$VmName"
    ssh -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$($ServiceVMDNS)" "sudo ./configureDNS.sh -u -i $ProxyIP -d untrusted.$VmName"
    ssh -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$($ServiceVMDNS)" "sudo ./configureDNS.sh -u -i $ProxyIP -d webapp.$VmName"
}