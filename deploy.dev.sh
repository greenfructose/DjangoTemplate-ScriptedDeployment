#!/bin/bash

# Get helper functions
source ./func.sh

# Check if running as root, exit if true
check_not_root

# Set OS prerequisites
LINUX_PREREQ=('build-essential' 'python3-dev' 'python3-pip' )

# Set Python prerequisites
PYTHON_PREREQ=('virtualenv')

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

for ppkg in "${PYTHON_PREREQ[@]}"
    do
        echo "Installing Python package '$ppkg'..."
        pip3 install $ppkg
        if [ $? -ne 0 ]; then
            echo "Error installing python package '$ppkg'"
            exit 1
        fi
    done

if [ ${#MISSING[@]} -ne 0 ]; then
    echo "Following required packages are missing, please install them first."
    echo ${MISSING[*]}
    exit 1
fi

echo 'All required packages have been installed!'

# Get project name
while true; do
    read -p 'Enter name for project: ' PROJECT_NAME
    echo
    [ ! -z "$PROJECT_NAME" ] && break || echo "Project name cannot be blank. Please try again."
done

# Set up dev environment
echo "Setting up virtual environment..."
virtualenv -p python3 .
source .bin/activate
# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip || error_exist "Error upgrading pip to the latest version"
pip install -r ./requirements.dev.txt
django-admin startproject $PROJECT_NAME .
./manage.py makemigrations
./manage.py migrate
deactivate
