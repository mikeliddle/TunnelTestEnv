git clone https://github.com/acmesh-official/acme.sh.git
cd ./acme.sh
./acme.sh --install -m ##email##

acme.sh --upgrade
acme.sh --set-default-ca --server letsencrypt
acme.sh --register-account
acme.sh --upgrade --upgrade-account --accountemail ##email##

acme.sh --issue --alpn -d mltunnel1.westus3.cloudapp.azure.com --preferred-chain "ISRG ROOT X1"
