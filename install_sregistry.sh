#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

ROOT_DIR=$PWD
BUILD_DIR=$ROOT_DIR/build
SREGISTRY_DIR=$BUILD_DIR/sregistry
SINGULARITY_DIR=$BUILD_DIR/singularity
SINGULARITY_PYTHON_DIR=$BUILD_DIR/singularity-python
EXTERNAL_IP=$(/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')
LOCALHOST_IP="127.0.0.1"

mkdir -p $ROOT_DIR $BUILD_DIR

echo ""
echo "Updating Ubuntu repositories. Please wait ..."
apt-get update &> /dev/null
echo ""
echo "Installing sofware requirements. Please wait ..."
apt-get install -y gcc make libtool automake git &> /dev/null
#apt-get install -y gcc make python python-pip libtool automake git &> /dev/null
apt-get install -y docker.io docker-compose &> /dev/null
wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh &> /dev/null
bash Miniconda3-latest-Linux-x86_64.sh -b -f -u -p /usr/local &> /dev/null

# Not working yet
#bash -x generate_certs.sh $BUILD_DIR 
#if [ $? -ne 0 ]; then
#    echo "[ERROR] Cert generation failed!"
#    echo "Aborting ..."
#    exit 1
#fi


#############################################################################
# Singularity-python: sregistry executable command
#############################################################################

echo ""
echo "[INSTALL] Singularity-python"
echo ""

# Singularity-python requeriments
git clone -b development https://github.com/vsoch/singularity-python.git $SINGULARITY_PYTHON_DIR
cd $SINGULARITY_PYTHON_DIR

PYTHON_VERSION=`python -c "import sys;t='{v[0]}'.format(v=list(sys.version_info[:2]));sys.stdout.write(t)";`
if [ ! $PYTHON_VERSION == 3 ] 
then 
    echo "[ERROR] Python > 3 required"
    echo "Aborting ..."
    exit 1
fi

conda install -y numpy scikit-learn cython pandas &> /dev/null
pip install setuptools &> /dev/null
pip install -r requirements.txt &> /dev/null
pip install pyasn1==0.3.4 &> /dev/null
python setup.py sdist 
python setup.py install

## Next commit does not work with python 2.7(updating timestamp function to specify timezone utc)
## ImportError: cannot import name timezone
## This commit works
#git checkout c46d0956a4e7581f9ebcbef122743aca94f90258
#
#pip install numpy scikit-learn cython pandas setuptools pyasn1==0.3.4
#pip install -r requirements.txt 
#
## Installation
#python setup.py sdist
#python setup.py install

#############################################################################
# Singularity: sregistry executable command
#############################################################################

echo ""
echo "[INSTALL] Singularity"
echo ""

## Singularity Master branch
#git clone https://github.com/singularityware/singularity.git $SINGULARITY_DIR
#cd $SINGULARITY_DIR
#./autogen.sh
#./configure --prefix=/usr/local
#make
#make install

# Singularity 2.4
cd $BUILD_DIR
VERSION=2.4
wget https://github.com/singularityware/singularity/releases/download/$VERSION/singularity-$VERSION.tar.gz
tar xvf singularity-$VERSION.tar.gz
cd singularity-$VERSION
./configure --prefix=/usr/local
make
sudo make install


#############################################################################
# SRegistry: web service
#############################################################################

echo ""
echo "[INSTALL] SRegistry"
echo ""

#if false; then
git clone https://github.com/singularityhub/sregistry.git $SREGISTRY_DIR
cd $SREGISTRY_DIR
## Commit message: adjusting urls to prevent 301 redirect, and appending to delete function
#git checkout 8d2a8c02f726d474dad05d4bcb32b65947f61745

# Configure
SREGISTRY_CONFIG_DIR=$SREGISTRY_DIR/shub/settings
SREGISTRY_AUTH_FILE=$SREGISTRY_CONFIG_DIR/auth.py
SREGISTRY_CONFIG_FILE=$SREGISTRY_CONFIG_DIR/config.py
SREGISTRY_SECRETS_FILE=$SREGISTRY_CONFIG_DIR/secrets.py

sed -i 's/'$LOCALHOST_IP'\b/'$EXTERNAL_IP'/g' $SREGISTRY_AUTH_FILE
sed -i 's/'$LOCALHOST_IP'\b/'$EXTERNAL_IP'/g' $SREGISTRY_CONFIG_FILE

## HTTPS configuration
#mkdir -p $SREGISTRY_DIR/http
#cp nginx.conf $REGISTRY_DIR/http/nginx.conf
#cp docker-compose.yml $SREGISTRY_DIR/http/docker-compose.yml
#
#cp $SREGISTRY_DIR/https/docker-compose.yml $SREGISTRY_DIR/docker-compose.yml
#cp $SREGISTRY_DIR/https/nginx.conf.https $SREGISTRY_DIR/nginx.conf


echo ""
echo "Please follow this steps to enable Oauth2 login with twitter:"
echo "============================================================="
echo "1. Register the app in https://apps.twitter.com/ and press [ENTER]"
echo "       Website: http://$EXTERNAL_IP"
echo "       Callback URL: http://$EXTERNAL_IP/complete/twitter"
read NULL
echo "2. Write a Django secret key and press [ENTER]"
echo "       You can generate it in https://www.miniwebtool.com/django-secret-key-generator/"
read -p "  Secret Key: " SECRET_KEY
echo "3. Write the Twitter 'Consumer Key' and press [ENTER]"
read -p "  API Key: " TWITTER_KEY
echo "4. Write the Twitter 'Consumer Secret' and press [ENTER]"
read -p "  API Secret: " TWITTER_SECRET



echo "
SECRET_KEY = '$SECRET_KEY'
SOCIAL_AUTH_TWITTER_KEY = '$TWITTER_KEY'
SOCIAL_AUTH_TWITTER_SECRET = '$TWITTER_SECRET'
" > $SREGISTRY_SECRETS_FILE

# Deploy

echo ""
echo -e " > Waiting for the nginx server to be up \c"
docker-compose stop  &>/dev/null
docker-compose rm -f &>/dev/null
docker-compose up -d &>/dev/null
# wait for sregistry_nginx_1 to request username
while [[ ! $(curl -sL -w "%{http_code}\\n" "http://$EXTERNAL_IP" -o /dev/null --connect-timeout 3 --max-time 5) == "200" ]];  do echo -e ".\c"; sleep 1; done
echo -e " Done!\c"
echo ""


echo "5. Open and sign-in into the SRegistry web service (http://$EXTERNAL_IP) and press [ENTER]"
read NULL
echo "6. Write the username used to sign-in and press [ENTER]"
read -p "Username: " USERNAME
echo ""

# wait for sregistry_uwsgi_1 to add superuser and admin
while [[ ! $(docker inspect -f {{.State.Running}} sregistry_uwsgi_1) == "true" ]];  do sleep 1; done

NAME=$(docker ps -aqf "name=sregistry_uwsgi_1")

# Configure superuser username
docker exec ${NAME} python manage.py add_superuser --username $USERNAME
if [ $? -ne 0 ]; then
    echo "[ERROR] Add superuser fail!"
    echo "        Please check that you are logged in http://$EXTERNAL_IP"
    echo "Aborting ..."
    exit 1
fi

# Configure admin username
docker exec ${NAME} python manage.py add_admin --username $USERNAME
if [ $? -ne 0 ]; then
    echo "[ERROR] Add superuser fail!"
    echo "        Please check that you are logged in http://$EXTERNAL_IP"
    echo "Aborting ..."
    exit 1
fi

# Generate register file
docker exec ${NAME} python manage.py register

echo ""
echo "Please, write the full token (http://$EXTERNAL_IP/token) and press [ENTER]:"
read -p "Token: " TOKEN
echo ""

echo $TOKEN > $HOME/.sregistry


#fi
