# DjangoTemplate-ScriptedDeployment

Bash script to deploy Django app to production environment

## Requirements

Currentyl supports deploying Django with PostgreSQL and nginx. Requires fresh Ubuntu 22.04 server or desktop.

The project name and project folder must be the same. In ```settings.py```, configuration must be as follows:

```python
from configparser import ConfigParser

config = ConfigParser(converters={'list': lambda x: [i.strip() for i in x.split(',')]})
config.read(BASE_DIR / 'project_name.cfg')
db_config = config["db"]
django_config = config["django"]

...

SECRET_KEY = django_config["secret"]

...

ALLOWED_HOSTS = django_config.getlist('hosts')

...

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': db_config["name"],
        'USER': db_config["user"],
        'PASSWORD': db_config["password"],
        'HOST': db_config["host"],
        'PORT': db_config["port"],
    }
}

...

STATIC_URL = '/static/'
```

Your config file will end up looking like this::

```bash
[db]
name = project_name
user = project_name
password = db_user_password
host = localhost
port = 5432

[django]
secret = django_secret
hosts: localhost,127.0.0.1,0.0.0.0,host_obtained_by_script

```

Make script executable

```bash
sudo chmod +x ./deploy.sh
```

Run script as root and answer all questions

```bash
sudo ./deploy.sh
```

Your site will be available on port 80 via all IP addresses on the host, secure access as needed.
