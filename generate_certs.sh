#! /bin/bash
#
# nginx should be installed on the host machine
#
#

INSTALL_ROOT=${1}
EMAIL=${2}
DOMAIN=${3}
STATE=${4:-California}
COUNTY=${5:-San Mateo County}

echo ""
echo "Please follow this steps to create HTTPS certs ($EXTERNAL_IP):"
echo "============================================================="
echo "1. Write the admin email and press [ENTER]"
read -p "  Admin Email (e.g. your@mail.gal): " EMAIL
echo "2. Write the domain and press [ENTER]"
read -p "  Domain (e.g. example.es): " DOMAIN
echo "3. Write the State and press [ENTER]"
read -p "  State (e.g. Spain): " STATE
echo "4. Write the County and press [ENTER]"
read -p "  County (e.g Galicia): " COUNTY

ismail=`echo $EMAIL | grep -P '^[a-zA-Z0-9]+@[a-zA-Z0-9]+\.[a-z]{2,}'`
if [[ -z "$ismail" ]]
then
    echo "[ERROR] $EMAIL is not a well formed email"
    exit 1
fi

isfqdn=`echo $DOMAIN | grep -P '(?=^.{1,254}$)(^(?>(?!\d+\.)[a-zA-Z0-9_\-]{1,63}\.?)+(?:[a-zA-Z]{2,})$)'`
if [[ -z "$isfqdn" ]]
then
    echo "[ERROR] $DOMAIN is not a well formed FQDN"
    exit 1
fi

ACME_TINY_DIR=$INSTALL_ROOT/acme-tiny
KEYS_DIR=$INSTALL_ROOT/keys

mkdir $KEYS_DIR
cd $INSTALL_ROOT

git clone https://github.com/diafygi/acme-tiny
chown $USER -R $ACME_TINY_DIR

# backup old key and cert
if [ -f "/etc/ssl/private/domain.key" ]
   then
   cp /etc/ssl/private/domain.key{,.bak.$(date +%s)}
fi

if [ -f "/etc/ssl/certs/chained.pem" ]
   then
   cp /etc/ssl/certs/chained.pem{,.bak.$(date +%s)}
fi

if [ -f "/etc/ssl/certs/domain.csr" ]
   then
   cp /etc/ssl/certs/domain.csr{,.bak.$(date +%s)}
fi

# Generate a private account key, if doesn't exist
if [ ! -f "/etc/ssl/certs/account.key" ]
   then
   openssl genrsa 4096 > account.key &&  mv account.key /etc/ssl/certs
fi

# Add extra security
if [ ! -f "/etc/ssl/certs/dhparam.pem" ]
   then
   openssl dhparam -out dhparam.pem 4096 && mv dhparam.pem /etc/ssl/certs
fi

if [ ! -f "csr_details.txt" ]
then

cat > csr_details.txt <<-EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn
 
[ dn ]
C=US
ST=$STATE
L=$COUNTY
O=End Point
OU=$DOMAIN
emailAddress=$EMAIL
CN = www.$DOMAIN
 
[ req_ext ]
subjectAltName = @alt_names
 
[ alt_names ]
DNS.1 = $DOMAIN
DNS.2 = www.$DOMAIN
EOF

fi
 
# Call openssl
openssl req -new -sha256 -nodes -out domain.csr -newkey rsa:2048 -keyout domain.key -config <( cat csr_details.txt )

# Create a CSR for $DOMAIN
#sudo openssl req -new -sha256 -key /etc/ssl/private/domain.key -subj "/CN=$DOMAIN" > domain.csr
mv domain.csr /etc/ssl/certs/domain.csr
mv domain.key /etc/ssl/private/domain.key

# Create the challenge folder in the webroot
mkdir -p /var/www/html/.well-known/acme-challenge/
chown $USER -R /var/www/html/

# Get a signed certificate with acme-tiny
#docker-compose stop nginx
python $ACME_TINY_DIR/acme_tiny.py --account-key /etc/ssl/certs/account.key --csr /etc/ssl/certs/domain.csr --acme-dir /var/www/html/.well-known/acme-challenge/ > ./signed.crt

wget -O - https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem > intermediate.pem
cat signed.crt intermediate.pem > chained.pem
mv chained.pem /etc/ssl/certs/
#rm signed.crt intermediate.pem

