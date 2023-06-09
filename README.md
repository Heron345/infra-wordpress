
# Wordpress Compose installation

## Pre-install checklist

1. Install Ubuntu 20.04 as basic host OS

 * You require Docker, docker-compose and systemd,
   it may be found for any distro

 * Make sure there is enough space in `/opt` and `/var` directories

 | PATH | Minimal space required | Recommented space |
 |:-----|------------------------|-------------------|
 | `/opt` (persistent data and backups)     | 500 Mib | 20+ Gib |
 | `/var` (default docker storage and logs) | 1 Gib   | 5+ Gib  |

2. _(Optional)_ Add admin user
 * Add user **admin** and primary group **admin**: `sudo adduser admin`
 * Add user **admin** to the **sudo** group: `sudo usermod -aG sudo admin`

3. Install packages with apt
 * Do not forget to update and maybe upgrade: `sudo apt update && sudo apt upgrade`
 * Install **required** packages: `sudo apt install curl git docker docker-compose`
 * Install _additional_ packages: `sudo apt install screen mc pwgen`

## Installation process

1. Get installation files from this repo

 * Use git to clone this repo or download them manually to `/opt/infra-wordpress`:
```
sudo mkdir -vp /opt/infra-wordpress
sudo chown -v $(id -u):$(id -g)
git clone https://github.com/Heron345/infra-wordpress.git /opt/infra-wordpress
```

 | FILE or mask | Usage while installation |
 |:-------------|--------------------------|
 | `./docker-compose.yaml`, `./.env`, `./nginx` | Main installation |
 | `./scripts` , `./watchdog`    | Watchdog and maintenance files   |
 | `./docker-compose@.service`   | Systemd setup                    |
 | `./docker-compose.*.yml`      | Additional services              |

 _INFO: Anoter files are not required, but you can keep them_

2. Edit the configuration for first run

 * Edit main settings file: `.env`

 | Environment Variable | How to change Value |
 |:---------------------|:--------------------|
 | `MARIADB_*`          | Database credentinals. **MUST** be changed. |
 | `NGINX_TEMPLATE`     | Nginx template for default.conf. <br /> You should use default HTTP template for first run to obtain ssl cert data. You should not run with HTTPS protocol enabled before obtaining ssl cert. So **do not change now**. |
 | `NGINX_SERVER_NAME*` | Set one main primary domain FQDN value to the `NGINX_SERVER_NAME`. <br /> Set domain aliases list separated by space to the `NGINX_SERVER_NAMES`. |
 | `CERTBOT_COMMAND`    | Edit according to [Certbot documentation](https://eff-certbot.readthedocs.io/en/stable/using.html). <br /> Fill all domains using `-d example.com`. |

 _INFO: You can add more Environment Variables in `.env` file,
  some of them are hidden in `docker-compose.yaml` with default values.
  Or you can tune and code Variables in both `docker-compose.yaml` and `.env` file._

 * _(Optional)_ Run `./options-ssl-nginx.conf-update` in `nginx` directory

## First manual run and check

1. Start service with `docker-compose up -d`

 _INFO: Change directory to `/opt/infra-wordpress`.
  You may need run `docker-compose down` before `docker-compose up -d`
  to erase created containers and volumes.
  You may need run `docker-compose up` without `-d` option
  to watch out the log interactively._

2. Check if software is running well by reading log messages

 _INFO: Get specific service log with `docker-compose logs service_name`
  or all services logs at once with `docker-compose logs`_

 | Service   | Good/OK status in the log |
 |:----------|:--------------------------|
 | db        | `* 0 [Note] Starting MariaDB * as process *` |
 | webserver | `* [notice] 1#1: start worker processes`     |
 | wordpress | `* NOTICE: fpm is running, pid 1`            |
 | wordpress | `* NOTICE: ready to handle connections`      |
 | certbot   | `Successfully received certificate.`, `exited with code 0` |

 _Watch all the log and error messages, fix errors!_

3. Check if containers are running well by querying their status

`docker ps -a --filter name=infra-wordpres` should return something like:

```
  Name                 Command               State           Ports
  -------------------------------------------------------------------------
  certbot     certbot certonly --webroot ...   Exit 0
  db          docker-entrypoint.sh --def ...   Up       3306/tcp, 33060/tcp
  webserver   nginx -g daemon off;             Up       0.0.0.0:80->80/tcp
  wordpress   docker-entrypoint.sh php-fpm     Up       9000/tcp
```

4. Interact with started services

 * Do MariaDB and other suggestions from the log by executing commands inside containers

 | Service and description | Example command |
 |:------------------------|:----------------|
 | Run mariadb-secure-installation for the db service | `docker exec -it infra-wordpress_db_1 /usr/bin/mariadb-secure-installation` |
 | Force certbot renew  | `docker-compose run certbot renew --force-recreate` |
 | MariaDB dump restore | `docker exec -it infra-wordpress_db_1 sh -c 'mysql -u example-user -pmy_cool_secret wordpress < /var/lib/mysql/dump.sql` |
 | Run `sh` inside nginx container | `docker exec -it infra-wordpress_webserver_1 sh` |

 _INFO: Run command in container
 with `docker exec -it infra-wordpress_${service}_1 command`._

 * Finally open the Wordpress installation panel in web-browser
 using `NGINX_SERVER_NAME` value as host name

## Swith to HTTPS and install systemd service

1. Edit `.env` once again

 | Environment Variable | How to change Value |
 |:---------------------|:--------------------|
 | `MARIADB_ROOT_PASSWORD` | Disable or delete the db root password line. <br /> Please save the password somewhere. |
 | `NGINX_TEMPLATE`        | Enable HTTPS Nginx template. E.g.: delete first `#` letter. |
 | `CERTBOT_COMMAND`       | Disable the certbot command line. |

 _Leave all other settings as they are_

2. Try the configuration by restarting services
```
cd /opt/infra-wordpress
docker-compose down
docker-compose up -d
```

3. Finally set Systemd services
```
sudo cp -v /opt/infra-wordpress/docker-compose@.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable docker-compose@infra-wordpress.service
sudo systemctl start docker-compose@infra-wordpress.service
```

 _INFO: Starting the systemd service will do `docker-compose down`
  and `docker-compose up`. **This means services restarting**_

# Run additional services

_Additional admin services deployments
 are configured in `docker-compose.override.yml`_

Using the `docker-compose.override.yml` file
 [is documented by Docker](https://docs.docker.com/compose/extends/)

* _Example_: Disable **all** additional services

```
docker-compose down
mv -v docker-compose.override.yml docker-compose.override.yml-disabled
```

_INFO: move `docker-compose.override.yml` back to enable services

* _Example_: Disable **phpmyadmin** additional service

Stop the service: `docker-compose stop phpmyadmin`

Delete or comment phpmyadmin section in docker-compose.override.yml

_INFO: Uncomment phpmyadmin section and use `docker-compose up phpmyadmin -d`
 to enable phpmyadmin back_
