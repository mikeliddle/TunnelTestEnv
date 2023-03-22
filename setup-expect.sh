. vars

sed -i "s/##SITE_ID##/${SITE_ID}/g" setup.exp
sed -i "s/##ARGS##/${SETUP_ARGS}/g" setup.exp

apt update
apt install -y expect