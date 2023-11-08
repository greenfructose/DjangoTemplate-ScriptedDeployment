#!/bin/bash

# Get helper functions
source ./func.sh

# Check if running as root, exit if true
check_not_root

# Get project name
while true; do
    read -p 'Enter name for project: ' PROJECT_NAME
    echo
    [ ! -z "$PROJECT_NAME" ] && break || echo "Project name cannot be blank. Please try again."
done

# Get Django admin user info
while true; do
    read -p 'Enter username for superuser: ' ADMIN_USER
    echo
    [ ! -z "$ADMIN_USER" ] && break || echo "Username cannot be blank. Please try again."
done

while true; do
    read -p 'Enter email for superuser: ' ADMIN_EMAIL
    echo
    [[ $ADMIN_EMAIL =~ $EMAIL_REGEX ]] && break || echo 'Please enter a valid email address.' 
done

while true; do
    read -s -p 'Enter password for superuser: ' ADMIN_PASSWORD
    echo
    [ ! -z "$ADMIN_PASSWORD" ] && break || echo "Password can't be blank. Please try again."
done

while true; do
    read -s -p 'Enter password again: ' ADMIN_PASSWORD_CONF
    echo
    [ "$ADMIN_PASSWORD" == "$ADMIN_PASSWORD_CONF" ] && break || echo "Passwords don't match, try again"
done

# Set OS prerequisites
LINUX_PREREQ=('build-essential' 'python3-dev' 'python3-pip' 'python3-virtualenv')

# Test prerequisites
echo "Checking if required packages are installed..."
declare -a MISSING
for pkg in "${LINUX_PREREQ[@]}"
    do
        echo "Installing '$pkg'..."
        sudo apt-get -y install $pkg
        if [ $? -ne 0 ]; then
            echo "Error installing system package '$pkg'"
            exit 1
        fi
    done

if [ ${#MISSING[@]} -ne 0 ]; then
    echo "Following required packages are missing, please install them first."
    echo ${MISSING[*]}
    exit 1
fi

echo 'All required packages have been installed!'


# Set up dev environment
echo "Setting up virtual environment..."
virtualenv -p python3 .
source ./bin/activate
# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip || error_exist "Error upgrading pip to the latest version"
pip install -r ./requirements.dev.txt
django-admin startproject $PROJECT_NAME .
python ./deployment/scripts/dev_allowed_hosts.py -p $PROJECT_NAME -l "$(tr -s ' ' ',' <<< $(hostname -I | xargs))"
./manage.py makemigrations
./manage.py migrate
DJANGO_SUPERUSER_USERNAME=$ADMIN_USER DJANGO_SUPERUSER_EMAIL=$ADMIN_EMAIL DJANGO_SUPERUSER_PASSWORD=$ADMIN_PASSWORD ./manage.py createsuperuser --noinput
./manage.py runserver 0.0.0.0:8000
deactivate
echo "Complete. Development site running at http://localhost:8000 or $HOSTNAMES at port 8000"