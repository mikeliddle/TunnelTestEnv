Function New-BasicPki {
    Write-Header "Generating PKI..."
    scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" ./scripts/createCerts.sh "$($Context.Username)@$($Context.ServiceFQDN):~/" > $null
    scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" -r ./openssl.conf.d "$($Context.Username)@$($Context.ServiceFQDN):~/" > $null
    scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" ./scripts/exportCert.sh "$($Context.Username)@$($Context.ServiceFQDN):~/" > $null

    ssh -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$($Context.Username)@$($Context.ServiceFQDN)" "chmod +x ~/createCerts.sh ~/exportCert.sh"
    
    if ($Context.WithIPv6) {
        ssh -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$($Context.Username)@$($Context.ServiceFQDN)" "sudo ./createCerts.sh -risux -c `"$($Context.TunnelFQDN)`" -a `"DNS.1\=$($Context.TunnelFQDN)\nDNS.2\=*.$($Context.TunnelFQDN)\nDNS.3\=trusted\nDNS.4\=webapp\nDNS.5\=excluded\nDNS.6\=cert\nDNS.7\=optionalcert\nDNS.8\=$($Context.TunnelFQDNIpv6)\nDNS.9\=*.$($Context.TunnelFQDNIpv6)\nIP.1\=$($Context.TunnelGatewayIPv6Address.ipAddress)`""   
    } else { 
        ssh -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$($Context.Username)@$($Context.ServiceFQDN)" "sudo ./createCerts.sh -risux -c `"$($Context.TunnelFQDN)`" -a `"DNS.1\=$($Context.TunnelFQDN)\nDNS.2\=*.$($Context.TunnelFQDN)\nDNS.3\=trusted\nDNS.4\=webapp\nDNS.5\=excluded\nDNS.6\=cert\nDNS.7\=optionalcert`""
    }
    ssh -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$($Context.Username)@$($Context.ServiceFQDN)" "sudo ./exportCert.sh"

    scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$($Context.Username)@$($Context.ServiceFQDN):~/serverchain.pem" ./scripts/serverchain.pem.tmp > $null
    scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$($Context.Username)@$($Context.ServiceFQDN):~/cacert.pem" ./cacert.pem.tmp > $null
    scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$($Context.Username)@$($Context.ServiceFQDN):~/server.key" ./scripts/server.key.tmp > $null

}

Function New-NginxSetup {
    Write-Header "Configuring Nginx..."
    $Content = Get-Content ./nginx.conf.d/nginx.conf
    $Content = $Content -replace "##DOMAIN_NAME##", "$($Context.TunnelFQDN)"
    $Content = $Content -replace "##SERVER_NAME##", "$($Context.TunnelFQDN.split('.')[0])"
    $Content = $Content -replace "##SERVER_IP##", "$($Context.ProxyIP)"
    Set-Content -Path ./nginx.conf.d/nginx.conf.tmp -Value $Content -Force

    Write-Header "Copying files over"
    scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" ./scripts/createWebservers.sh "$($Context.Username)@$($Context.ServiceFQDN):~/" > $null
    scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" -r ./nginx.conf.d "$($Context.Username)@$($Context.ServiceFQDN):~/" > $null
    scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" -r ./nginx_data "$($Context.Username)@$($Context.ServiceFQDN):~/" > $null
    scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" -r context.json "$($Context.Username)@$($Context.ServiceFQDN):~/nginx_data/context.json" > $null
    scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" ./scripts/getPublicCert.sh "$($Context.Username)@$($Context.TunnelFQDN):~/" > $null

    Write-Header "Getting public certificate"
    ssh -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$($Context.Username)@$($Context.TunnelFQDN)" "chmod +x ~/getPublicCert.sh"
    ssh -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$($Context.Username)@$($Context.TunnelFQDN)" "sudo ./getPublicCert.sh -e $($Context.Email) -d $($Context.TunnelFQDN)"
    scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$($Context.Username)@$($Context.TunnelFQDN):~/letsencrypt.pem" ./letsencrypt.pem.tmp > $null
    scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$($Context.Username)@$($Context.TunnelFQDN):~/letsencrypt.key" ./letsencrypt.key.tmp > $null
    scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" ./letsencrypt.pem.tmp "$($Context.Username)@$($Context.ServiceFQDN):~/letsencrypt.pem" > $null
    scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" ./letsencrypt.key.tmp "$($Context.Username)@$($Context.ServiceFQDN):~/letsencrypt.key" > $null
    
    Write-Header "Install and run Containers"
    ssh -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$($Context.Username)@$($Context.ServiceFQDN)" "chmod +x ~/createWebservers.sh"
    ssh -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$($Context.Username)@$($Context.ServiceFQDN)" "sudo ./createWebservers.sh -a -p $($Context.ProxyIP)"
}

Function New-DnsServer {
    Write-Header "Creating DNS server..."

    scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" ./scripts/configureDNS.sh "$($Context.Username)@$($Context.ServiceFQDN):~/" > $null
    scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" -r ./unbound.conf.d/a-records.conf "$($Context.Username)@$($Context.ServiceFQDN):~/" > $null
    scp -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" -r ./unbound.conf.d/unbound.conf "$($Context.Username)@$($Context.ServiceFQDN):~/" > $null

    ssh -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$($Context.Username)@$($Context.ServiceFQDN)" "chmod +x ~/configureDNS.sh"
    ssh -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$($Context.Username)@$($Context.ServiceFQDN)" "sudo ./configureDNS.sh"

    ssh -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$($Context.Username)@$($Context.ServiceFQDN)" "sudo ./configureDNS.sh -u -i $($Context.ProxyIP) -d $($Context.TunnelFQDN)"
    ssh -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$($Context.Username)@$($Context.ServiceFQDN)" "sudo ./configureDNS.sh -u -i $($Context.ProxyIP) -d proxy.$($Context.TunnelFQDN)"
    ssh -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$($Context.Username)@$($Context.ServiceFQDN)" "sudo ./configureDNS.sh -u -i $($Context.ProxyIP) -d trusted.$($Context.TunnelFQDN)"
    ssh -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$($Context.Username)@$($Context.ServiceFQDN)" "sudo ./configureDNS.sh -u -i $($Context.ProxyIP) -d untrusted.$($Context.TunnelFQDN)"
    ssh -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$($Context.Username)@$($Context.ServiceFQDN)" "sudo ./configureDNS.sh -u -i $($Context.ProxyIP) -d webapp.$($Context.TunnelFQDN)"
    ssh -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$($Context.Username)@$($Context.ServiceFQDN)" "sudo ./configureDNS.sh -u -i $($Context.ProxyIP) -d excluded.$($Context.TunnelFQDN)"
    ssh -i $Context.SSHKeyPath -o "StrictHostKeyChecking=no" "$($Context.Username)@$($Context.ServiceFQDN)" "sudo ./configureDNS.sh -u -i $($Context.ProxyIP) -d cert.$($Context.TunnelFQDN)"
}