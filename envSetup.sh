#!/bin/sh

InstallPrereqs() {
	apt update
	apt remove -y docker
	apt install -y docker.io openssl
}

Help() {
	echo "before running, set the following environment variables:"

	echo "	export SERVER_NAME=example"
	echo "	export DOMAIN_NAME=example.com"
	echo "	export SERVER_PRIVATE_IP=10.x.x.x"
	echo "	export SERVER_PUBLIC_IP=20.x.x.x"
}

VerifyEnvironmentVars() {
	if [ -z $SERVER_NAME ]; then
		echo "MISSING SERVER NAME... Aborting."
		exit
	fi
	if [ -z $DOMAIN_NAME ]; then
		echo "MISSING DOMAIN NAME... Aborting."
		exit
	fi
	if [ -z $SERVER_PRIVATE_IP ]; then
		echo "MISSING PRIVATE IP... Aborting."
		exit
	fi
	if [ -z $SERVER_PUBLIC_IP ]; then
		echo "MISSING PUBLIC IP... Aborting."
		exit
	fi
}

ReplaceNames() {
	sed -i "s/##SERVER_NAME##/${SERVER_NAME}/g" *.d/*.conf
	sed -i "s/##DOMAIN_NAME##/${DOMAIN_NAME}/g" *.d/*.conf
	sed -i "s/##SERVER_PRIVATE_IP##/${SERVER_PRIVATE_IP}/g" *.d/*.conf
	sed -i "s/##SERVER_PUBLIC_IP##/${SERVER_PUBLIC_IP}/g" *.d/*.conf
}

###########################################################################################
#                                                                                         #
#                           Simple Env Setup with Docker                                  #
#                                                                                         #
###########################################################################################

ConfigureCerts() {
	# setup PKI folder structure
	mkdir /etc/pki/tls/certs
	mkdir /etc/pki/tls/req
	mkdir /etc/pki/tls/private
	
	# copy config into the tls folder structure
	cp openssl.conf.d/openssl.conf /etc/pki/tls

	# push current directory
	current_dir=$(pwd)

	cd /etc/pki/tls

	# generate self-signed root CA
	opensl genrsa -out private/cakey.pem 4096
	openssl req -new -x509 -days 3650 -extensions v3_ca -key private/cakey.pem -out certs/cacert.pem

	# generate leaf from our CA
	openssl genrsa -out private/server.key 4096
	openssl req -new -key private/server.key -out req/server.csr -config openssl.conf
	openssl x509 -req -days 365 -in req/server.csr -CA certs/cacert.pem -CAkey private/cakey.pem -CAcreateserial -out cert/server.pem -extensions req_ext -extfile openssl.conf

	# generate untrusted leaf cert
	openssl genrsa -out private/untrusted.key 4096
	openssl req -new -x509 -days 3650 -extensions req_ext -key private/untrusted.key -out certs/untrusted.pem

	cd $current_dir
	# pop current directory
}

ConfigureUnbound() {
	# create the unbound volume
	docker volume create unbound

	# run the unbound container
	docker run -d \
		--name=unbound \
		-v unbound:/opt/unbound/etc/unbound/ \
		-p 53:53/tcp \
		-p 53:53/udp \
		--restart=unless-stopped \
		mvance/unbound:latest

	# copy in necessary config files
	cp unbound.conf.d/a-records.conf /var/lib/docker/volumes/unbound/_data/a-record.conf
	# restart to apply config change
	docker restart unbound
}

ConfigureNginx() {
	# create volume
	docker volume create nginx-vol

	# copy config files, certs, and pages to serve up
	cp -r nginx.conf.d /var/lib/docker/volumes/nginx-vol/_data/nginx.conf.d
	cp -r /etc/pki/tls/certs /var/lib/docker/volumes/nginx-vol/_data/certs
	cp -r /etc/pki/tls/private /var/lib/docker/volumes/nginx-vol/_data/private
	cp -r nginx_data /var/lib/docker/volumes/nginx-vol/_data/data

	# TODO: missing letsencrypt cert.

	# run the containers
	docker run -d \
		--name=trusted \
		--mount source=nginx-vol,destination=/etc/volume \
		-p 9443:9443 \
		--restart=unless-stopped \
		-v /var/lib/docker/volumes/nginx-vol/_data/nginx.conf.d/trusted.conf:/etc/nginx/nginx.conf:ro \
		nginx

	docker run -d \
		--name=untrusted \
		--mount source=nginx-vol,destination=/etc/volume \
		-p 8443:8443 \
		--restart=unless-stopped \
		-v /var/lib/docker/volumes/nginx-vol/_data/nginx.conf.d/untrusted.conf:/etc/nginx/nginx.conf:ro \
		nginx

	docker run -d \
		--name=letsencrypt \
		--mount source=nginx-vol,destination=/etc/volume \
		-p 8080:8080 \
		--restart=unless-stopped \
		-v /var/lib/docker/volumes/nginx-vol/_data/nginx.conf.d/letsencrypt.conf:/etc/nginx/nginx.conf:ro \
		nginx
}

###########################################################################################
#                                                                                         #
#                                    JS SPA env setup                                     #
#                                                                                         #
###########################################################################################

BuildAndRunWebService() {
	docker build -t sampleWebService sampleWebService

	docker run -d \
		--name=webService \
		--restart=unless-stopped \
		-p 7152:7152
		sampleWebService
}

if [[ $1 == "-h" ]]; then
	Help
else
	if [[ $1 == "-i" ]]; then
		InstallPrereqs
	fi

	# setup server name
	VerifyEnvironmentVars
	ReplaceNames

	ConfigureCerts
	ConfigureUnbound
	ConfigureNginx
	BuildAndRunWebService
	BuildAndRunSPA
fi