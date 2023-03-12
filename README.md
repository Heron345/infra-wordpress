
# Wordpress Compose installation

## Pre-requisites

Pre-install checklist

* Install Ubuntu 20.04 as basic host OS.
 Actually the installation guide must suit another distros,
 but I tested scripts and installation guide with Ubuntu.

* Make sure there is enough space in /opt and /var directories.
 This guide uses /opt as base dir for persisent data.
 This guide uses docker, which stores data in /var/lib/docker.

* (Optional) Add your admin user.
 If you wahnt to, add user and give him administrative rights
```
adduser admin # adds user with name *admin* and with the primary group *admin*
usermod -aG sudo admin # adds user *admin* th the *sudo* group
```

* Install necessary (must) packages.
```
sudo apt update
sudo apt upgrade # you better do upgrade after install
sudo apt install curl git docker docker-compose
```

* (Optional) install additional (optional) packages.
 I usually use this packages suit, but it is not required for guide.
```
sudo apt install screen mc pwgen
```

## Copy and edit installation files

* Clone files from this repo to /opt/infra-wordpress directory:
```
mkdir -vp /opt/infra-wordpress
cd /opt/infra-wordpress
git clone https://github.com/Heron345/infra-wordpress.git .
```

Better get all files and use git to get updates in the future.
 You must have at least:
```
./docker-compose.yaml
./.env
./nginx-templates
./nginx-templates/options-ssl-nginx.conf
./nginx-templates/wordpress-http.conf.template
./nginx-templates/wordpress-https.conf.template~
```

* Edit the configuration files:

*! Please DO EDIT .env file* and change credentials in it!
 Use strong passwords and right login and database names.

Edit docker-compose.yaml webserver service ports:
 Set right public ports to server http and https connections.
 If you can run docker-proxy as root, then use 80 and 443 instead of default
 and leave internal ports as they are
```
    ports:
      - "80:8080"
      - "443:8443"
```

Edit docker-compose.yaml webserver service environment:
 Set right ```DOMAIN_NAME``` and ```DOMAIN_NAME_ALIASES```
 ```DOMAIN_NAME``` must contain one main FQDN for your site
 ```DOMAIN_NAME_ALIASES``` must contain another domains for your site

Edit docker-compose.yaml certbot service command:
 Set right ```email``` for ```--email``` option.
 Set one or more FQDNs for ```-d``` option from list set for webserver on previous step.

* (Optional) run ```./options-ssl-nginx.conf-update``` in ```nginx-templates``` directory.

* Make sure, that ```nginx-templates/wordpress-http.conf.template``` is enabled
 and ```nginx-templates/wordpress-https.conf.template~``` is not enabled.
 You should not run nginx with https enabled before obtaining ssl cert.
 E.g ```nginx-templates/wordpress-https.conf.template~``` must not suit *.template wildcard so far.


## Do first manual run

* Start services.
```
cd /opt/infra-wordpress
docker-compose down
docker-compose up -d
```

* Check if all is correct.
 You can access the log with ```docker-compose logs service_name```
 OK statuses for services are (llok for them in the log):
```
db_1         | * 0 [Note] Starting MariaDB * as process *
webserver_1  | * [notice] 1#1: start worker processes
wordpress_1  | * NOTICE: fpm is running, pid 1
wordpress_1  | * NOTICE: ready to handle connections
certbot_1    | Successfully received certificate.
infra-wordpress_certbot_1 exited with code 0
```
 Watch out all the log and error messages, fix it!

* Check docker containers runs well:
```
docker ps -a --filter name=infra-wordpres
```
 should return something like:
```
  Name                 Command               State           Ports
  -------------------------------------------------------------------------
  certbot     certbot certonly --webroot ...   Exit 0
  db          docker-entrypoint.sh --def ...   Up       3306/tcp, 33060/tcp
  webserver   nginx -g daemon off;             Up       0.0.0.0:80->80/tcp
  wordpress   docker-entrypoint.sh php-fpm     Up       9000/tcp
```

* Do MariaDB and another suggestions from the log.
 In new terminal do run:
```
docker exec -it infra-wordpress_db_1 /usr/bin/mariadb-secure-installation
```
 use ```docker exec -it infra-wordpress_${service}_1``` to run executables in containers.

* Make sure you can access the Wordpress installation panel http://your.FQDN.example and http://www.your.FQDN.example.

* Disable ```MARIADB_ROOT_PASSWORD``` in ```.env```.
 Edit ```.env``` and either comment root password line or delete it.
 You are to save the password somewhere before deleteing it.

## Do swith to the HTTPS

* Rename (disable or even delete) ```wordpress-http.conf.template```
 and ```wordpress-https.conf.template~``` files.
```
cd nginx-templates
mv wordpress-http.conf.template wordpress-http.conf.template~disabled
mv wordpress-https.conf.template~ wordpress-https.conf.template
```

* Restart all services
```
cd /opt/infra-wordpress
docker-compose down
docker-compose up -d
```

## (Optional) Exec some commands inside containers if needed

* You can run command inside container with ```docker exec -t infra-wordpress_${service}_1 command```.
 E.g.:
```
docker exec -t infra-wordpress_db_1 sh -c 'mysql -u example-user -pmy_cool_secret wordpress < /var/lib/mysql/dimp.sql
```

* Or run container with command replaced with something:
```
docker-compose run certbot renew --force-recreate
```

