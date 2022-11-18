# How To run

1. Clone this repo onto the VM that you want to run this code on.
2. Switch to root (needed for some of these commands)
3. Setup your environment variables (run `./envSetup.sh -h` for more information)
4. Setup the environment with `./envSetup.sh`
   1. You can use the `-i` flag to have it install the prereqs of docker and openssl.

# Environment explanation

1. Trusted - A docker container listening on port 9443 with a TLS certificate issued by our generated CA.
2. Untrusted - A docker container listening on port 8443 with a self signed TLS certificate.
3. Unbound - A DNS resolver that will allow requests coming into our server to use the local IP address instead of the public IP address for the specified domain name. This uses port 53 on UDP and TCP.
4. letsEncrypt - A docker container listening on port 8080 with a publicly trusted TLS certificate.

# Known limitations

* LetsEncrypt commands require some interaction, so you will need to obtain this cert out of this process and place it at /etc/pki/tls/certs/letsencrypt.pem and /etc/pki/tls/private/letsencrypt.key before running this script.
* This does not configure the firewall on the VM, so you may have additional work to allow the ports used by this environment