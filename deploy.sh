#!/bin/bash

# Get helper functions
source ./func.sh

# Check if running as root, exit if not
check_root

# Get Django project GitHub repository information
echo 'Getting repo information...'
read -p 'Enter GitHub repository owner: ' REPO_OWNER
read -p 'Enter GitHub Repository name: ' REPO_NAME

# Get git config information
echo 'Getting git config info...'
read -p 'Enter git user.name: ' GIT_USER
read -p 'Enter git user.email: ' GIT_EMAIL

# Get Django admin user info
read -p 'Enter username for superuser: ' ADMIN_USER
read -p 'Enter email for superuser: ' ADMIN_EMAIL
read -s -p 'Enter password for superuser: ' ADMIN_PASSWORD

# Validate that inputs are not blank
if [ -z "$GIT_USER" ] || [ -z "$GIT_EMAIL" ] || [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ] || [ -z "$ADMIN_USER" ] || [ -z "$ADMIN_EMAIL" ] || [ -z "$ADMIN_PASSWORD" ]
then 
    echo 'No fields can be blank, please try again' 
    exit 0 
fi


# Validate email address format
EMAIL_REGEX="^(([-a-zA-Z0-9\!#\$%\&\'*+/=?^_\`{\|}~]+|(\"([][,:;<>\&@a-zA-Z0-9\!#\$%\&\'*+/=?^_\`{\|}~-]|(\\\\[\\ \"]))+\"))\.)*([-a-zA-Z0-9\!#\$%\&\'*+/=?^_\`{\|}~]+|(\"([][,:;<>\&@a-zA-Z0-9\!#\$%\&\'*+/=?^_\`{\|}~-]|(\\\\[\\ \"]))+\"))@\w((-|\w)*\w)*\.(\w((-|\w)*\w)*\.)*\w{2,4}$"
if [[ $ADMIN_EMAIL =~ $EMAIL_REGEX ]]; then
    echo 'Setting superuser info...'
else
    echo 'Admin email address is invalid, please try again'
    exit 0
fi

if [[ $GIT_EMAIL =~ $EMAIL_REGEX ]]; then
    echo 'Setting up git user info...'
else
    echo 'Git user email invalid, please try again'
    exit 0
fi

LINUX_PREREQ=('git' 'build-essential' 'python3-dev' 'python3-pip' 'nginx' 'postgresql' 'libpq-dev' )

PYTHON_PREREQ=('virtualenv')

# Test prerequisites
echo "Checking if required packages are installed..."
declare -a MISSING
for pkg in "${LINUX_PREREQ[@]}"
    do
        echo "Installing '$pkg'..."
        apt-get -y install $pkg
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

# Setup git
echo 'Setting up git...'
git config --global user.name "$GIT_USER"
git config --global user.email "$GIT_EMAIL"

# Clone selected repository
echo 'Cloning repository...'
git clone https://github.com/$REPO_OWNER/$REPO_NAME.git
cd $REPO_NAME

GROUPNAME=$REPO_OWNER
APPNAME=$REPO_NAME
APPFOLDERPATH=/$GROUPNAME/$APPNAME

# Create App Folder
echo "Creating app folder '$APPFOLDERPATH'..."
mkdir -p /$GROUPNAME/$APPNAME || error_exit "Could not create app folder"

# Test the group exists, and if it doesn't create it
getent group $GROUPNAME
if [ $? -ne 0 ]; then
    echo "Creating group '$GROUPNAME' for automation accounts..."
    groupadd --system $GROUPNAME || error_exit "Could not create group 'webapps'"
fi

# Create the app user account, same name as the appname
grep "$APPNAME:" /etc/passwd
if [ $? -ne 0 ]; then
    echo "Creating automation user account '$APPNAME'..."
    useradd --system --gid $GROUPNAME --shell /bin/bash --home $APPFOLDERPATH $APPNAME|| error_exit "Could not create automation user account '$APPNAME'"
fi

# change ownership of the app folder to the newly created user account
echo "Setting ownership of $APPFOLDERPATH and its descendents to $APPNAME:$GROUPNAME..."
chown -R $APPNAME:$GROUPNAME $APPFOLDERPATH || error_exit "Error setting ownership"

# install python virtualenv in the APPFOLDER
echo "Creating environment setup for django app..."
su -l $APPNAME << 'EOF'
pwd
echo "Setting up python virtualenv..."
virtualenv -p python3 . || error_exit "Error installing Python 3 virtual environment to app folder"

EOF

# Copy files to app directory
cp -r . $APPFOLDERPATH

cd $APPFOLDERPATH

# Generate Config
echo "Generating Django Config..."
DJANGO_SECRET_KEY=`openssl rand -base64 48`
if [ $? -ne 0 ]; then
    error_exit "Error creating secret key."
fi

# Generate DB password
echo "Creating secure password for database role..."
DBPASSWORD=`openssl rand -base64 32`
if [ $? -ne 0 ]; then
    error_exit "Error creating secure password for database role."
fi

# Set up database
echo "Creating PostgreSQL database '$APPNAME'..."
su postgres -c "psql -c \"CREATE DATABASE $APPNAME;\""
echo "Creating PostgreSQL user..."
su postgres -c "psql -c \"CREATE USER $APPNAME WITH PASSWORD '$DBPASSWORD';\""
echo "Apply settings to user..."
su postgres -c "psql -c \"ALTER ROLE $APPNAME SET client_encoding TO 'utf8';\""
su postgres -c "psql -c \"ALTER ROLE $APPNAME SET default_transaction_isolation TO 'read committed';\""
su postgres -c "psql -c \"ALTER ROLE $APPNAME SET timezone TO 'UTC';\""
echo "Granting user privileges..."
su postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE $APPNAME TO $APPNAME;\""

# Get all IP addresses

# Write config file
echo "Writing configuration file..."
cat > /tmp/$APPNAME.cfg << EOF
[db]
name = $APPNAME
user = $APPNAME
password = $DBPASSWORD
host = localhost
port = 5432

[django]
secret = $DJANGO_SECRET_KEY
hosts = 127.0.0.1,localhost,0.0.0.0,$(tr -s ' ' ',' <<< $(hostname -I | xargs))
EOF
mv /tmp/$APPNAME.cfg $APPFOLDERPATH
chown $APPNAME:$GROUPNAME $APPFOLDERPATH/$APPNAME.cfg

# Install requirements and create super user
su -l $APPNAME << EOF
# Enter virtual environment
echo "Activating virtual environment..."
source ./bin/activate
# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip || error_exist "Error upgrading pip to the latest version"
# Install prerequisite python packages for application using pip
echo "Installing application requirements..."
pip install -r ./requirements.txt
# Setup database
echo "Running databse migrations..."
./manage.py makemigrations
./manage.py migrate
# Create superuser
echo "Creating superuser $ADMIN_USER..."
DJANGO_SUPERUSER_USERNAME=$ADMIN_USER DJANGO_SUPERUSER_EMAIL=$ADMIN_EMAIL DJANGO_SUPERUSER_PASSWORD=$ADMIN_PASSWORD ./manage.py createsuperuser --noinput
# Exit virtual environment
echo "Deactivating virtual environment..."
deactivate
EOF

# Write service file for application
echo "Creating service..."
cat > /tmp/$APPNAME.service << EOF
[Unit]
Description=$APPNAME daemon
Requires=$APPNAME.socket
After=network.target

[Service]
User=root
Group=root
WorkingDirectory=$APPFOLDERPATH
ExecStart=$APPFOLDERPATH/bin/gunicorn \\
          --access-logfile - \\
          --workers 3 \\
          --bind unix:/run/$APPNAME.sock \\
          $APPNAME.wsgi:application

[Install]
WantedBy=multi-user.target
EOF
mv /tmp/$APPNAME.service /etc/systemd/system

# Write socket file for service
echo "Creating socket..."
cat > /tmp/$APPNAME.socket << EOF
[Unit]
Description=$APPNAME socket

[Socket]
ListenStream=/run/$APPNAME.sock

[Install]
WantedBy=sockets.target
EOF
mv /tmp/$APPNAME.socket /etc/systemd/system


# Disable default nginx site
echo "Disabling default nginx site..."
rm -f /etc/nginx/sites-enabled/default

# Write app nginx config
echo "Writing nginx config..."
cat > /tmp/$APPNAME << EOF
server {
        listen 80;

        server_name localhost $(hostname -I | xargs);

        location / {
                proxy_set_header Host \$host;
                proxy_pass http://unix:/run/$APPNAME.sock;
                proxy_redirect off;
        }
        location /static/ {
                root $APPFOLDERPATH;
        }
}
EOF
mv /tmp/$APPNAME /etc/nginx/sites-available

# Enable site
echo "Enabling site..."
ln -sf /etc/nginx/sites-available/$APPNAME /etc/nginx/sites-enabled/$APPNAME

# Add www-data to group
echo "Fixing permissions for nginx..."
usermod -a -G $GROUPNAME www-data

# Start and enable service
echo "Starting and enabling service..."
systemctl start $APPNAME.socket
systemctl enable $APPNAME.socket

# Restart nginx
echo "Restarting nginx..."
systemctl restart nginx
