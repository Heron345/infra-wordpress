
# Wordpress Compose installation

## Pre-install checklist

1. Install Ubuntu 20.04 as basic host OS
 * The installation guide uses docker, docker-compose and systemd,
   and it may run on any distro
 * Make sure there is enough space in /opt and /var directories

 | PATH | Minimal space required | Recommented space |
 |:-----|------------------------|-------------------|
 | ```/opt```
   (the site, db and certbot persistent data and backups)
        | 500 Mib                | 20+ Gib           |
 | ```/var```
   (default docker storage and logs)
        | 1 Gib                  | 5+ Gib            |

2. (Optional) Add your admin user
 * Add user *admin* and primary groups *admin*: ```adduser admin```
 * Add user *admin* to the *sudo* group: ```usermod -aG sudo admin```

3. Install packages with apt
 * Do not forget to update and maybe upgrade: ```apt-get update && apt-get upgrade```
 * Install necessary (must have) packages: ```sudo apt install curl git docker docker-compose```
 * (Optional) install additional packages: ```sudo apt install screen mc pwgen```

## Installation process

1. Get installation files from this repo
 * Use git to clone this repo or download them manually to ```/opt/infra-wordpress```:
 ```git clone https://github.com/Heron345/infra-wordpress.git /opt/infra-wordpress```

 | FILE or mask | Usage while installation |
 |:-------------|--------------------------|
 | ```./docker-compose.yaml```
   ```./.env```
   ```./nginx-templates```
                | Main installation files for the guide |
 | ```./contrib/*.service```
   ```./contrib/*.timer```
                | Required to run with systemd |

 /INFO: Anoter files are not required, but you can keep them/

2. Edit the configuration for first run
 * Edit main settings file: ```.env```
 /INFO: you need to edit only ```.env``` file, backup it if needed/

 | Environment Variable | How to change Value |
 |:---------------------|:--------------------|
 | ```MARIADB_DATABASE```
   ```MARIADB_USER```
   ```MARIADB_PASSWORD```
   ```MARIADB_ROOT_PASSWORD```
                        | Database credentinals. *MUST* be changed. |
 | ```NGINX_TEMPLATE``` | Nginx template for default.conf.
                          You should use default HTTP template for first run to obtain ssl cert data.
                          You should not run with HTTPS protocol enabled before obtaining ssl cert.
                          So *do not change now*. |
 | ```NGINX_SERVER_NAME```
   ```NGINX_SERVER_NAMES```
                        | Set the main primary FQDN value to the ```NGINX_SERVER_NAME```.
                          Set aliases list separated by space to the ```NGINX_SERVER_NAMES```. |
 | ```CERTBOT_COMMANDLINE```
                        | Comment this value to get SSL cert only for ```NGINX_SERVER_NAME```,
                          Fill all domains using ```-d domain.name.example``` instead.
                          Set email for receiving information if you wahnt. |

 /INFO: You can add more Environment Variables in ```.env``` file,
  some of them already exist in ```docker-compose.yaml``` with default values.
  Or you can add new ones in both compose and env file.
  You are welcome to contribute to this repo./

 * (Optional) Run ```./options-ssl-nginx.conf-update``` in ```nginx-templates``` directory

## Do the first manual run and check if it is OK

1. Do the first run
 * Start services with ```docker-compose up -d```
 /INFO: Change directory to ```/opt/infra-wordpress``` before running docker-compose.
  You may need to run ```docker-compose down``` before ```docker-compose up -d``` to erase created containers.
  You may need to run ```docker-compose up``` without ```-d``` option to watch out the log interactively./

2. Check services are working well
 * Check if wordpress is running well by reading log messages
 /INFO: Access logs with ```docker-compose logs service_name```
  or all services logs at once with ```docker-compose logs```

 | Service   | Good/OK status in the log |
 |:----------|:--------------------------|
 | db        | ```* 0 [Note] Starting MariaDB * as process *``` |
 | webserver | ```* [notice] 1#1: start worker processes```     |
 | wordpress | ```* NOTICE: fpm is running, pid 1```            |
 | wordpress | ```* NOTICE: ready to handle connections```      |
 | certbot   | ```Successfully received certificate.```         |
               ```exited with code 0```                         |
 /Watch all the log and error messages, fix errors!/

 * Check if containers running well. Command ```docker ps -a --filter name=infra-wordpres```
 should return something like:
```
  Name                 Command               State           Ports
  -------------------------------------------------------------------------
  certbot     certbot certonly --webroot ...   Exit 0
  db          docker-entrypoint.sh --def ...   Up       3306/tcp, 33060/tcp
  webserver   nginx -g daemon off;             Up       0.0.0.0:80->80/tcp
  wordpress   docker-entrypoint.sh php-fpm     Up       9000/tcp
```

3. Interact with started services
 * Do MariaDB and other suggestions from the log by executing commands inside containers

 | Service and description | Example command |
 |:------------------------|:----------------|
 | Run mariadb-secure-installation for the db service
                           | ```docker exec -it infra-wordpress_db_1 /usr/bin/mariadb-secure-installation``` |
 | Force certbot renew     | ```docker-compose run certbot renew --force-recreate``` |
 | Restore MariaDB dump-db | ```docker exec -it infra-wordpress_db_1 sh -c 'mysql -u example-user -pmy_cool_secret wordpress < /var/lib/mysql/dimp.sql``` |
 | Run interactive shell (```/bin/sh``` inside nginx container
                           | ```docker exec -it infra-wordpress_webserver_1 sh``` |
 /INFO: use this commands for debugging.
  Run command in container with ```docker exec -it infra-wordpress_${service}_1 command```./

 * Finally open the Wordpress installation panel using web-browser
  /INFO: FQDN is set in ```NGINX_SERVER_NAME```/

## Do swith to the HTTPS and install systemd service

1. Edit ```.env``` once again

 | Environment Variable | How to change Value |
 |:---------------------|:--------------------|
 | ```MARIADB_ROOT_PASSWORD```
                        | Disable or delete the db root password line.
                          Please save the password somewhere. |
 | ```NGINX_TEMPLATE``` | Enable HTTPS Nginx template for default.conf.
                          E.g.: delete first ```#``` letter. |
 /Leave all other settings as they are/

2. Try the configuration by restarting services
```
cd /opt/infra-wordpress
docker-compose down
docker-compose up -d
```

3. Finally set Systemd services
```
cp -v /opt/infra-wordpress/*.timer /opt/infra-wordpress/*.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable docker-compose@infra-wordpress.service docker-cleanup.timer
systemctl start docker-compose@infra-wordpress.service docker-cleanup.timer
```
