# How To run

## Automate everything

1. Clone this repo to your local machine.
2. Ensure powershell is installed on your machine.
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

- `-Platform`: mobile platforms to create profiles for. Default is "all", valid options are `ios, android, all`.
- `-Location`: The azure region to create the VM in. Default is `westus`.
- `-Size`: The size of the VM to create. Default is `Standard_B2s`.
- `-Image`: The image to use for the VM. Default is `Canonical:0001-com-ubuntu-server-focal:20_04-lts:latest`.
- `-Environment`: The Intune cloud environment to use. Default is `PE`.
- `-Email`: The email address to use for the Let's Encrypt certificate. Default is to detect this from the VM login information.
- `-Username`: The Username to use for the VM. Default is `azureuser`.
- `-AdApplication`: The name of the AAD application to use for authentication. Default is `Generated MAM Tunnel`.
- `-VMTenantCredential`: a pscredential object used for silent authentication to the VM subscription. Default is to prompt for credentials.
- `-TenantCredential`: a pscredential object used for silent authentication to the tunnel tenant. Default is to prompt for credentials.
- `-SubscriptionId`: The subscription ID to use for the VM. Default is to detect this from the VM login information.
- `-PACUrl`: The url for the Proxy Automatic Configuration script. Default is the one setup and hosted on the nginx web server container.

Switches:

- `-Delete` - Deletes the VM and all associated resources.
- `-ProfilesOnly` - only creates the profiles for Tunnel.
- `-NoProxy` - skip configuring the proxy.
- `-WithSSHOpen` - open the SSH port on the VM.
- `-StayLoggedIn` - stay logged in to the accounts after the script finishes.
- `-NoPki` - use the publicly trusted certificate instead of an enterprise certificate for Tunnel.

## Automate just the Environment

1. Clone this repo onto the VM that you want to run this code on.
2. Switch to root (needed for some of these commands).
3. Setup your environment variables (run `./envSetup.sh -h` for more information).
4. Run `chmod +x envSetup.sh exportCert.sh`.
5. Setup the environment with `./envSetup.sh`.
   1. You can use the `-i` flag to have it install the prereqs of docker and acme.sh, and disable systemd-resolved.
   2. You can use the `-p` flag to install and configure a squid proxy on port 3128.
6. Clean up the environment by running `./envSetup.sh -r`. You will need to re-set the vars file after this.

## Environment explanation

1. Trusted - An NGINX server with a TLS certificate issued by our generated CA.
2. Untrusted - An NGINX server with a self signed TLS certificate.
3. LetsEncrypt - An NGINX server with a publicly trusted TLS certificate.
4. WebApp - A docker container serving up a sample web project using the above internally-trusted CA
5. Unbound - A DNS resolver that will allow requests coming into our server to use the local IP address instead of the public IP address for the specified domain name. This uses port 53 on UDP and TCP.
6. Proxy - A squid proxy listening on port 3128.
7. Excluded - A server that will be bypassed by the proxy when using a PAC file.

All these servers are available at the address `https://\<hostname\>.\<fqdn\>`. The webApp container will show you your origin IP, which will either be the proxy IP or the Tunnel Gateway IP depending on if you are using the proxy or not.
