# Squid

## DNS

One of the tricky pieces with a proxy is that the proxy needs to be configured with a DNS server that can resolve the endpoints just like the client devices. With docker and podman rotating IPs when the host restarts, it's possible that the proxy container will need to be destroyed and recreated with the right DNS server. This is because we are specifying the DNS IP on container creation, and docker doesn't allow for this to be modified post creation.

## Logs

Squid has two log files, a cache log, and an access log. Typically the access log is more useful for troubleshooting as it has the requests present. It will also tell if it was a cache hit or miss, which is less useful for our scenarios, but can be useful information. The log files are stored at /var/log/squid/access.log and /var/log/squid/cache.log. You can view them with `docker exec -it squid tail -f /var/log/squid/access.log` and `docker exec -it squid tail -f /var/log/squid/cache.log` respectively.

## Break and Inspect

The packaged version of squid included with most major Linux distributions does not have openssl built into it, and does not support TLS inspection via ssl_bump. As a result, we are using a third-party package source to grab a version of squid that does support this. This is meant to be a proof of concept, and should not be considered a secure environment for production use. The configuration file has a parameter to specify the cert generation tool that squid will use (most online guides don't add this information), as well as information for using the PKI previously generated on this box. In the future it would be good to add in support for trusting this PKI we have generated, but for now, we disable proxy->server TLS validation for the internal sites.

## Future tasks

Add Authentication options
Use better template for config files to allow for more shared settings. (e.g. auth and ssl_bump in the same file, or just one or the other)
