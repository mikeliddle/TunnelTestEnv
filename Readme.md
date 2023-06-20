# How To run

## Automate everything

1. Clone this repo to your local machine.
2. Ensure powershell core and az cli are installed on your machine.
3. Run `./CreateServer.ps1` with the necessary parameters.
   - Example: ./CreateServer.ps1 -VmName mstunnel-test -BundleIds com.microsoft.scmx -GroupName myusergroup
   - You will be prompted first to sign-in with an Azure account to create the VM, then twice to authenticate to your Intune tenant for setting up the Tunnel configura
tion and profiles.
4. Clean up the environment by running `./CreateServer.ps1 -Delete`

### Powershell arguments

Required Parameters:

- `-VmName` - The name of the VM to create, also used for DNS entries as the hostname of the machine.
- `-BundleIds` - The bundle IDs to target MAM profiles to. This is a comma separated list of bundle IDs.
- `-GroupName` - The name of the AAD group to target profiles to.

Optional Parameters:

- `-Platform`: Mobile platforms to create profiles for. Default is "all", valid options are `ios, android, all`.
- `-Location`: The azure region to create the VM in. Default is `westus`.
- `-Size`: The size of the VM to create. Default is `Standard_B2s`.
- `-ProxySize`: The size of the proxy VM to create. Default is `Standard_B2s`.
- `-Image`: The image to use for the VM. Default is `Canonical:0001-com-ubuntu-server-focal:20_04-lts:latest`.
- `-Environment`: The Intune cloud environment to use. Default is `PE`.
- `-Email`: The email address to use for the Let's Encrypt certificate. Default is to detect this from the VM login information.
- `-Username`: The Username to use for the VM. Default is `azureuser`.
- `-AdApplication`: The name of the AAD application to use for authentication. Default is `Generated MAM Tunnel`.
- `-VMTenantCredential`: A pscredential object used for silent authentication to the VM subscription. Default is to prompt for credentials.
- `-TenantCredential`: A pscredential object used for silent authentication to the tunnel tenant. Default is to prompt for credentials.
- `-SubscriptionId`: The subscription ID to use for the VM. Default is to detect this from the VM login information.
- `-PACUrl`: The url for the Proxy Automatic Configuration script. Default is the one setup and hosted on the nginx web server container.
- `-IncludeRoutes`: The routes to include for split tunneling. Default is Empty.
- `-ExcludeRoutes`: The routes to exclude for split tunneling. Default is Empty.
- `-ListenPort`: The port for the Tunnel Server to listen on.

Switches:

- `-Delete` - Deletes the VM and all associated resources.
- `-ProfilesOnly` - Only creates the profiles for Tunnel.
- `-NoProxy` - Skip configuring the proxy.
- `-Simple` - Skip configuring the proxy and advanced settings.
- `-NoPki` - Use the publicly trusted certificate instead of an enterprise certificate for Tunnel.
- `-WithSSHOpen` - Open the SSH port on the VM.
- `-StayLoggedIn` - Stay logged in to the accounts after the script finishes.
- `-NoPki` - Use the publicly trusted certificate instead of an enterprise certificate for Tunnel.
- `-UseInspection` - Configures proxy to use TLS inspection (Break and Inspect).
- `-WithADFS` - Configure ADFS in the environment. This is a WIP and is not fully functional yet.

## Environment explanation

1. Trusted - An NGINX server with a TLS certificate issued by our generated CA.
2. Untrusted - An NGINX server with a self signed TLS certificate.
3. LetsEncrypt - An NGINX server with a publicly trusted TLS certificate.
4. WebApp - A docker container serving up a sample web project using the above internally-trusted CA
5. Unbound - A DNS resolver that will allow requests coming into our server to use the local IP address instead of the public IP address for the specified domain name. This uses port 53 on UDP and TCP.
6. Proxy - A squid proxy listening on port 3128.
7. Excluded - A server that will be bypassed by the proxy when using a PAC file.

All these servers are available at the address `https://\<hostname\>.\<fqdn\>`. The webApp container will show you your origin IP, which will either be the proxy IP or the Tunnel Gateway IP depending on if you are using the proxy or not.
