# How To run

## Automate everything

1. Clone this repo to your local machine.
2. Ensure powershell is installed on your machine.
3. Run `./CreateServer.ps1` with the necessary parameters.
4. Clean up the environment by running `./CreateServer.ps1 -Delete`

## Automate just the Environment

1. Clone this repo onto the VM that you want to run this code on.
2. Switch to root (needed for some of these commands)
3. Setup your environment variables (run `./envSetup.sh -h` for more information)
4. Run `chmod +x envSetup.sh exportCert.sh`
5. Setup the environment with `./envSetup.sh` 
   1. You can use the `-i` flag to have it install the prereqs of docker and acme.sh, and disable systemd-resolved.
   2. You can use the `-p` flag to install and configure a squid proxy on port 3128
6. Clean up the environment by running `./envSetup.sh -r`. You will need to re-set the vars file after this. 

# Environment explanation

1. Trusted - An NGINX server with a TLS certificate issued by our generated CA.
2. Untrusted - An NGINX server with a self signed TLS certificate.
3. Unbound - A DNS resolver that will allow requests coming into our server to use the local IP address instead of the public IP address for the specified domain name. This uses port 53 on UDP and TCP.
4. letsEncrypt - An NGINX server with a publicly trusted TLS certificate.
5. webService - A docker container serving up a sample web project using the above internally-trusted CA
