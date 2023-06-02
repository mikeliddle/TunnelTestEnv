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
    scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" ./scripts/exportCert.sh "$($Username)@$($ServiceVMDNS):~/" > $null

    ssh -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$($ServiceVMDNS)" "chmod +x ~/createCerts.sh ~/exportCert.sh"
    ssh -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$($ServiceVMDNS)" "sudo ./createCerts.sh -risux -c `"$TunnelVMDNS`" -a `"DNS.1\=$TunnelVMDNS\nDNS.2\=*.$TunnelVMDNS\nDNS.3\=trusted\nDNS.4\=webapp\nDNS.5\=excluded`""
    ssh -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$($ServiceVMDNS)" "sudo ./exportCert.sh"

    scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$($ServiceVMDNS):~/serverchain.pem" ./scripts/serverchain.pem.tmp > $null
    scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$($ServiceVMDNS):~/cacert.pem" ./cacert.pem.tmp > $null
    scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$($ServiceVMDNS):~/server.key" ./scripts/server.key.tmp > $null

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
    $Content = Get-Content ./nginx.conf.d/nginx.conf
    $Content = $Content -replace "##DOMAIN_NAME##", "$ServiceVMDNS"
    $Content = $Content -replace "##SERVER_NAME##", "$($ServiceVMDNS.split('.')[0])"
    Set-Content -Path ./nginx.conf.d/nginx.conf.tmp -Value $Content -Force

    Write-Header "Copying files over"
    scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" ./scripts/createWebservers.sh "$($Username)@$($ServiceVMDNS):~/" > $null
    scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" -r ./nginx.conf.d "$($Username)@$($ServiceVMDNS):~/" > $null
    scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" -r ./nginx_data "$($Username)@$($ServiceVMDNS):~/" > $null
    scp -i $SSHKeyPath -o "StrictHostKeyChecking=no" -r ./sampleWebService "$($Username)@$($ServiceVMDNS):~/" > $null

    Write-Header "Install and run Containers"
    ssh -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$($ServiceVMDNS)" "chmod +x ~/createWebservers.sh"
    ssh -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$($ServiceVMDNS)" "sudo ./createWebservers.sh -a -d $ServiceVMDNS -e $Email"
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

    ssh -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$($ServiceVMDNS)" "sudo ./configureDNS.sh -u -i $ProxyIP -d proxy.$ServiceVMDNS"
    ssh -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$($ServiceVMDNS)" "sudo ./configureDNS.sh -u -i $ProxyIP -d trusted.$ServiceVMDNS"
    ssh -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$($ServiceVMDNS)" "sudo ./configureDNS.sh -u -i $ProxyIP -d untrusted.$ServiceVMDNS"
    ssh -i $SSHKeyPath -o "StrictHostKeyChecking=no" "$($Username)@$($ServiceVMDNS)" "sudo ./configureDNS.sh -u -i $ProxyIP -d webapp.$ServiceVMDNS"
}