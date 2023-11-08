
# DjangoTemplate-ScriptedDeployment

Project with development and production deployment scripts

## Requirements

Development deployment initilizes a Django project and performs initial migrations. Run the development deployment script as non-root user. This will install packages necessary for development environment.

```bash
./deploy.dev.sh
```

Production deployment deploys Django app with PostgreSQL and nginx. Requires fresh Ubuntu 22.04 server or desktop installation. Run the production deployment script as root.

```bash
./deploy.prod.sh
```
