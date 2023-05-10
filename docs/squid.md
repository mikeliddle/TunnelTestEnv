# Squid

## DNS

One of the tricky pieces with a proxy is that the proxy needs to be configured with a DNS server that can resolve the endpoints just like the client devices. With docker and podman rotating IPs when the host restarts, it's possible that the proxy container will need to be destroyed and recreated with the right DNS server. This is because we are specifying the DNS IP on container creation, and docker doesn't allow for this to be modified post creation.

## Logs

Squid has two log files, a cache log, and an access log. Typically the access log is more useful for troubleshooting as it has the requests present. It will also tell if it was a cache hit or miss, which is less useful for our scenarios, but can be useful information. The log files are stored at /var/log/squid/access.log and /var/log/squid/cache.log. You can view them with `docker exec -it squid tail -f /var/log/squid/access.log` and `docker exec -it squid tail -f /var/log/squid/cache.log` respectively.
