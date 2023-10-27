
# Welcome to TunnelTestEnv
The TunnelTestEnv Powershell script creates a full test environment for Microsoft Tunnel. The environment includes a Linux VM tunnel gateway server, and a second Linux VM that runs containers for a proxy server, a DNS server, and a web server. By default, an Intune tenant is also configured with tunnel profiles.

TunnelTestEnv has been tested on MacOS and Windows. It can probably be made to run on Linux as well. The main script is named CreateServer.ps1.

The TunnelTestEnv scripts were written by Mike Liddle, based on previous scripts written by Yasir Ibrahim and Todd Bohman, with input for others.

# How To run

## Automate everything
To quicky download and run the scripts:
1. Clone this repo to your local machine.
2. Ensure powershell core and az cli are installed on your machine.
3. Run `./CreateServer.ps1` with the necessary parameters.
   - Example: ./CreateServer.ps1 -VmName mstunnel-test -BundleIds com.microsoft.scmx -GroupName myusergroup
   - You will be prompted first to sign-in with an Azure account to create the VMs, then twice to authenticate to your Intune tenant for setting up the Tunnel configuration and profiles.
4. Clean up the environment by running `./CreateServer.ps1 -Delete -VmName <name>`. Note that deleting an Azure resource group takes a few minutes, so if you create again after deleting, you may need to wait or change the VmName.

## Automate just the services (No profiles or Tunnel)
To create a test environment ready for running the sprint signoff tests:
1. Clone this repo to your local machine.
2. Ensure powershell core and az cli are installed on your machine.
3. Run `./CreateServer.ps1 -SprintSignoff` with the necessary parameters.
   - Example: ./CreateServer.ps1 -SprintSignoff -VmName mstunnel-test
   - You will only be prompted to sign-in with an Azure account to create the VMs.
   - You also don't need BundleIds or GroupName since no profiles will be created.
4. Clean up the environment by running `./CreateServer.ps1 -DeleteSprintSignoff -VmName <name>`

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
- `-Image`: The image to use for the VM. Default is `Canonical:0001-com-ubuntu-server-jammy:22_04-lts:latest`.
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

- `-Delete` - Deletes the VM and all associated resources. Also deletes all created profiles.
- `-DeleteSprintSignoff` - Deletes the VM and all associated resources.
- `-ProfilesOnly` - Only creates the profiles for Tunnel.
- `-NoProxy` - Skip configuring the proxy.
- `-Simple` - Skip configuring the proxy and advanced settings.
- `-NoPki` - Use the publicly trusted certificate instead of an enterprise certificate for Tunnel.
- `-WithSSHOpen` - Open the SSH port on the VM.
- `-StayLoggedIn` - Stay logged in to the accounts after the script finishes.
- `-UseInspection` - Configures proxy to use TLS inspection (Break and Inspect).
- `-UseAllowList` - Configures proxy to use an allow list.
- `-SprintSignoff` - Sets up the services on a VM, and sets up a linux VM ready for tunnel installation, but doesn't create profiles or install Tunnel.
- `-NoPACUrl` - Doesn't configure a PAC file when used with ProfilesOnly.
- `-WithADFS` - Configure ADFS in the environment. This is a WIP and is not fully functional yet.
- `-RHEL8` - Uses the RHEL 8 lvm image for the Tunnel VM.
- `-RHEL7` - Uses the RHEL 7 lvm image for the Tunnel VM.
- `-Centos7` - Uses the Centos 7.9 image from OpenLogic for the Tunnel VM.
- `-BootDiagnostics` - Turn on boot diagnostics on the Tunnel VM.
- `-WithIPv6` - Create IPv6 address for the VMs, in addition to the IPv4 addresses.

## Environment explanation
The test environment will consist of the following components:
1. Trusted - An NGINX server with a TLS certificate issued by our generated CA.
2. Untrusted - An NGINX server with a self signed TLS certificate.
3. LetsEncrypt - An NGINX server with a publicly trusted TLS certificate (uses the VM FQDN for it's server name).
4. WebApp - A docker container serving up a sample web project using the above internally-trusted CA
5. Unbound - A DNS resolver that will allow requests coming into our server to use the local IP address instead of the public IP address for the specified domain name. This uses port 53 on UDP and TCP.
6. Proxy - A squid proxy listening on port 3128.
7. Excluded - A server that will be bypassed by the proxy when using a PAC file.

All these servers are available at the address `https://\<hostname\>.\<fqdn\>`. The webApp container will show you your origin IP, which will either be the proxy IP or the Tunnel Gateway IP depending on if you are using the proxy or not.

Since we are using a DNS server to override public entries, we also have default search domains available. This means you can access all of the resources by hostname instead of needing the FQDN. As a note, you will need to specify the protocol (https), otherwise, your browser will try to search for the hostname instead of lookup and navigate. For example, `https://webapp` will work, but `webapp` will likely not. 

## Debugging the scripts
You can debug the PowerShell scripts in Visual Studio Code.

### First-time Setup
1. Install Visual Studio Code.
2. Clone the TunnelTestEnv scripts as explained above.
3. Launch Visual Studio Code.
4. If the Code PowerShell Extension is not installed, install it by clicking View > Extensions then type "Powershell" in the search box, and select the PowerShell extension. More info is at https://code.visualstudio.com/docs/languages/powershell.

### Debug Configurations
Debugging a PowerShell script with command-line parameters is done with Configurations. The Configurations are stored in the ...\TunnelTestEnv\.vscode\launch.json file. The four configurations in that file are customized for TunnelTestEnv.
To update the Configurations:
1. In Visual Studio Code, select File > Open Folder..., browse to and select the TunnelTestEnv folder, then click "Select Folder". 
2. If the Solution Explorer window is not open, in the top menu click View > Explorer.
3. Open .vscode\launch.json.
4. Note the TunnelTestEnv custom configurations: 
   1.   Create TunnelTestEnv: This configuration creates a complete test environment and configures a tenant.
   2.   Delete TunnelTestEnv: This configuration deletes the test environment.
   3.   Create Signoff TunnelTestEnv: This configuration creates a test environment without configuring a tenant, and without mstunnel-setup being run on the server VM.
   4.   Delete Signoff TunnelTestEnv: This configuration deletes the signoff test environment.
5. Modify an existing configuration, or if you want, you can create new configurations. It is recommended that you provide at least a subscription ID and a VM name, but you may also want to add other command-line parameters.

### Select a Configuration
1. In Visual Studio Code, open the Run and Debug view (View > Run).
2. Find the Configuration dropdown at the top of the Run and Debug view, to the right of the "RUN AND DEBUG" title.
3. Click the Configuration dropdown and select one of the custom configurations. 
 
### Debugging the scripts
1. In Visual Studio Code, if the Solution Explorer window is not open, in the top menu click View > Explorer.
2. Open CreateServer.ps1 or one of the scripts in the scripts folder. 
3. Set breakpoints by pressing F9. A good place for a starting breakpoint is at Initialize command at around line 600 in CreateServer.ps1.
4. Press F5 to start debugging, then use F10 to step over, F11 to step into, and the other standard Visual Studio debugging commands.