#!/bin/bash

#==================================================
# Basic Settings
#==================================================
SCRIPT_VERSION="v1.0"
SCRIPT_DATE="2026.04.01"
AUTHOR="Landy.Wang"

#==================================================
# Color
#==================================================
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
RESET="\033[0m"

#==================================================
# Function: Check Root
#==================================================
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[ERROR] Please run this script as root.${RESET}"
        exit 1
    fi
}

#==================================================
# Function: Pause
#==================================================
pause() {
    read -rp "Press Enter to continue..."
}

#==================================================
# Function: Get Package Manager
#==================================================
get_pkg_manager() {
    if command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v yum >/dev/null 2>&1; then
        echo "yum"
    else
        echo ""
    fi
}

#==================================================
# Function: Check Package Manager
#==================================================
check_pkg_manager() {
    if [[ -z "$(get_pkg_manager)" ]]; then
        echo -e "${RED}[ERROR] Neither dnf nor yum was found on this system.${RESET}"
        exit 1
    fi
}

#==================================================
# Function: Install Package
#==================================================
pkg_install() {
    local pkg_manager
    pkg_manager=$(get_pkg_manager)

    if [[ -z "$pkg_manager" ]]; then
        echo -e "${RED}[ERROR] Package manager not found.${RESET}"
        return 1
    fi

    "$pkg_manager" install -y "$@"
}

#==================================================
# Function: Show Menu
#==================================================
show_menu() {
    clear
    echo -e "${BLUE}
+----------------------------------------------------------------------
| ${SCRIPT_DATE} Write By ${AUTHOR} ${SCRIPT_VERSION}
| Blog http://my-fish-it.blogspot.com
+----------------------------------------------------------------------
| Install Docker                  1
+----------------------------------------------------------------------
| Modify Docker Repository (CN)   2
+----------------------------------------------------------------------
| Modify pip Repository (CN)      3
+----------------------------------------------------------------------
| Disable SELinux                 4
+----------------------------------------------------------------------
| Docker Plane                    5
+----------------------------------------------------------------------
| Docker Next Terminal            6
+----------------------------------------------------------------------
| Docker Chaitin WAF              7
+----------------------------------------------------------------------
| Coming Soon                     8
+----------------------------------------------------------------------
| Coming Soon                     9
+----------------------------------------------------------------------
| Coming Soon                     10
+----------------------------------------------------------------------
| Coming Soon                     11
+----------------------------------------------------------------------
| Coming Soon                     12
+----------------------------------------------------------------------
| Exit                            13
+----------------------------------------------------------------------
${RESET}"
}

#==================================================
# Function: Disable SELinux
#==================================================
disable_selinux() {
    echo -e "${YELLOW}[INFO] Disabling SELinux...${RESET}"

    if [[ -f /etc/selinux/config ]]; then
        sed -i 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
        sed -i 's/^SELINUX=permissive/SELINUX=disabled/' /etc/selinux/config
        echo -e "${GREEN}[OK] /etc/selinux/config updated.${RESET}"
    else
        echo -e "${RED}[ERROR] /etc/selinux/config not found.${RESET}"
        return 1
    fi

    if command -v setenforce >/dev/null 2>&1; then
        setenforce 0 2>/dev/null || true
    fi

    echo -e "${GREEN}[OK] SELinux has been disabled temporarily. Reboot is required for permanent effect.${RESET}"
}

#==================================================
# Function: Install Docker
#==================================================
install_docker() {
    local pkg_manager
    pkg_manager=$(get_pkg_manager)

    echo -e "${YELLOW}[INFO] Installing Docker CE...${RESET}"
    check_pkg_manager

    pkg_install yum-utils device-mapper-persistent-data lvm2 || return 1

    if [[ "$pkg_manager" == "dnf" ]]; then
        dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || return 1
        dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin --allowerasing || return 1
    else
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || return 1
        yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin --allowerasing || return 1
    fi

    systemctl start docker || return 1
    systemctl enable docker || return 1

    echo -e "${GREEN}[OK] Docker installation completed.${RESET}"

    if command -v docker >/dev/null 2>&1; then
        echo -e "${BLUE}[INFO] $(docker --version 2>/dev/null)${RESET}"
    fi

    echo -e "${YELLOW}[INFO] Installing docker-compose via pip3...${RESET}"

    "$pkg_manager" install -y epel-release python3-pip || return 1
    pip3 install -U pip setuptools || return 1
    pip3 install docker-compose || return 1

    if command -v docker-compose >/dev/null 2>&1; then
        echo -e "${GREEN}[OK] $(docker-compose --version 2>/dev/null)${RESET}"
    else
        echo -e "${YELLOW}[WARN] docker-compose command not found after installation.${RESET}"
    fi
}

#==================================================
# Function: Modify pip Repository (CN)
#==================================================
modify_pip_repository_cn() {
    echo -e "${YELLOW}[INFO] Configuring pip mirror to Aliyun...${RESET}"

    mkdir -p ~/.pip || return 1

    cat > ~/.pip/pip.conf <<'EOF'
[global]
index-url=https://mirrors.aliyun.com/pypi/simple/
[install]
trusted-host=mirrors.aliyun.com
EOF

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}[OK] ~/.pip/pip.conf updated.${RESET}"
    else
        echo -e "${RED}[ERROR] Failed to update ~/.pip/pip.conf.${RESET}"
        return 1
    fi
}

#==================================================
# Function: Install docker-compose by pip
#==================================================
install_docker_compose() {
    local pkg_manager
    pkg_manager=$(get_pkg_manager)

    echo -e "${YELLOW}[INFO] Installing docker-compose via pip3...${RESET}"

    if [[ -z "$pkg_manager" ]]; then
        echo -e "${RED}[ERROR] Package manager not found.${RESET}"
        return 1
    fi

    "$pkg_manager" install -y epel-release python3-pip || return 1

    pip3 install -U pip setuptools || return 1
    pip3 install docker-compose || return 1

    if command -v docker-compose >/dev/null 2>&1; then
        echo -e "${GREEN}[OK] $(docker-compose --version 2>/dev/null)${RESET}"
    else
        echo -e "${YELLOW}[WARN] docker-compose command not found after installation.${RESET}"
    fi
}

#==================================================
# Function: Modify Docker Repository (CN)
#==================================================
modify_docker_repository_cn() {
    echo -e "${YELLOW}[INFO] Writing /etc/docker/daemon.json ...${RESET}"

    mkdir -p /etc/docker || return 1

    cat > /etc/docker/daemon.json <<'EOF'
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com",
    "https://dockerproxy.com",
    "https://docker.nju.edu.cn",
    "https://docker.mirrors.sjtug.sjtu.edu.cn",
    "https://docker.mirrors.ustc.edu.cn"
  ],
  "max-concurrent-downloads": 10,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  }
}
EOF

    systemctl daemon-reload || return 1
    systemctl restart docker || return 1

    if command -v docker >/dev/null 2>&1; then
        docker network prune -f >/dev/null 2>&1 || true
        docker info || true
    fi

    echo -e "${GREEN}[OK] Docker mirror configuration completed.${RESET}"
}

#==================================================
# Function: Install Docker Full Stack
#==================================================
install_docker_full() {
    disable_selinux || return 1
    install_docker || return 1
    modify_pip_repository_cn || return 1
    modify_docker_repository_cn || return 1
}

#==================================================
# Function: Get Primary IP
#==================================================
get_primary_ip() {
    local ip_addr

    ip_addr=$(hostname -I 2>/dev/null | awk '{print $1}')

    if [[ -z "$ip_addr" ]] && command -v ip >/dev/null 2>&1; then
        ip_addr=$(ip route get 1.1.1.1 2>/dev/null | awk '/src/ {for (i=1; i<=NF; i++) if ($i=="src") {print $(i+1); exit}}')
    fi

    if [[ -z "$ip_addr" ]]; then
        ip_addr="127.0.0.1"
    fi

    echo "$ip_addr"
}

#==================================================
# Function: Install Plane Stack
#==================================================
install_plane_stack() {
    local plane_dir archive_dir host_ip

    plane_dir="/opt/plan"
    archive_dir="${plane_dir}/archive"
    host_ip=$(get_primary_ip)

    echo -e "${YELLOW}[INFO] Creating Plane deployment files in ${plane_dir} ...${RESET}"

    mkdir -p "$archive_dir" || return 1

    cat > "${plane_dir}/docker-compose.yaml" <<'EOF'
x-db-env: &db-env
  PGHOST: ${PGHOST:-plane-db}
  PGDATABASE: ${PGDATABASE:-plane}
  POSTGRES_USER: ${POSTGRES_USER:-plane}
  POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-plane}
  POSTGRES_DB: ${POSTGRES_DB:-plane}
  POSTGRES_PORT: ${POSTGRES_PORT:-5432}
  PGDATA: ${PGDATA:-/var/lib/postgresql/data}

x-redis-env: &redis-env
  REDIS_HOST: ${REDIS_HOST:-plane-redis}
  REDIS_PORT: ${REDIS_PORT:-6379}
  REDIS_URL: ${REDIS_URL:-redis://plane-redis:6379/}

x-minio-env: &minio-env
  MINIO_ROOT_USER: ${AWS_ACCESS_KEY_ID:-access-key}
  MINIO_ROOT_PASSWORD: ${AWS_SECRET_ACCESS_KEY:-secret-key}

x-aws-s3-env: &aws-s3-env
  AWS_REGION: ${AWS_REGION:-}
  AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID:-access-key}
  AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY:-secret-key}
  AWS_S3_ENDPOINT_URL: ${AWS_S3_ENDPOINT_URL:-http://plane-minio:9000}
  AWS_S3_BUCKET_NAME: ${AWS_S3_BUCKET_NAME:-uploads}

x-proxy-env: &proxy-env
  APP_DOMAIN: ${APP_DOMAIN:-localhost}
  FILE_SIZE_LIMIT: ${FILE_SIZE_LIMIT:-5242880}
  CERT_EMAIL: ${CERT_EMAIL}
  CERT_ACME_CA: ${CERT_ACME_CA}
  CERT_ACME_DNS: ${CERT_ACME_DNS}
  LISTEN_HTTP_PORT: ${LISTEN_HTTP_PORT:-80}
  LISTEN_HTTPS_PORT: ${LISTEN_HTTPS_PORT:-443}
  BUCKET_NAME: ${AWS_S3_BUCKET_NAME:-uploads}
  SITE_ADDRESS: ${SITE_ADDRESS:-:80}

x-mq-env: &mq-env # RabbitMQ Settings
  RABBITMQ_HOST: ${RABBITMQ_HOST:-plane-mq}
  RABBITMQ_PORT: ${RABBITMQ_PORT:-5672}
  RABBITMQ_DEFAULT_USER: ${RABBITMQ_USER:-plane}
  RABBITMQ_DEFAULT_PASS: ${RABBITMQ_PASSWORD:-plane}
  RABBITMQ_DEFAULT_VHOST: ${RABBITMQ_VHOST:-plane}
  RABBITMQ_VHOST: ${RABBITMQ_VHOST:-plane}

x-live-env: &live-env
  API_BASE_URL: ${API_BASE_URL:-http://api:8000}
  LIVE_SERVER_SECRET_KEY: ${LIVE_SERVER_SECRET_KEY:-2FiJk1U2aiVPEQtzLehYGlTSnTnrs7LW}

x-app-env: &app-env
  WEB_URL: ${WEB_URL:-http://localhost}
  DEBUG: ${DEBUG:-0}
  CORS_ALLOWED_ORIGINS: ${CORS_ALLOWED_ORIGINS}
  GUNICORN_WORKERS: 1
  USE_MINIO: ${USE_MINIO:-1}
  DATABASE_URL: ${DATABASE_URL:-postgresql://plane:plane@plane-db/plane}
  SECRET_KEY: ${SECRET_KEY:-60gp0byfz2dvffa45cxl20p1scy9xbpf6d8c5y0geejgkyp1b5}
  AMQP_URL: ${AMQP_URL:-amqp://plane:plane@plane-mq:5672/plane}
  API_KEY_RATE_LIMIT: ${API_KEY_RATE_LIMIT:-60/minute}
  MINIO_ENDPOINT_SSL: ${MINIO_ENDPOINT_SSL:-0}
  LIVE_SERVER_SECRET_KEY: ${LIVE_SERVER_SECRET_KEY:-2FiJk1U2aiVPEQtzLehYGlTSnTnrs7LW}

services:
  web:
    image: makeplane/plane-frontend:${APP_RELEASE:-stable}
    deploy:
      replicas: ${WEB_REPLICAS:-1}
      restart_policy:
        condition: any
    depends_on:
      - api
      - worker

  space:
    image: makeplane/plane-space:${APP_RELEASE:-stable}
    deploy:
      replicas: ${SPACE_REPLICAS:-1}
      restart_policy:
        condition: any
    depends_on:
      - api
      - worker
      - web

  admin:
    image: makeplane/plane-admin:${APP_RELEASE:-stable}
    deploy:
      replicas: ${ADMIN_REPLICAS:-1}
      restart_policy:
        condition: any
    depends_on:
      - api
      - web

  live:
    image: makeplane/plane-live:${APP_RELEASE:-stable}
    environment:
      <<: [*live-env, *redis-env]
    deploy:
      replicas: ${LIVE_REPLICAS:-1}
      restart_policy:
        condition: any
    depends_on:
      - api
      - web

  api:
    image: makeplane/plane-backend:${APP_RELEASE:-stable}
    command: ./bin/docker-entrypoint-api.sh
    deploy:
      replicas: ${API_REPLICAS:-1}
      restart_policy:
        condition: any
    volumes:
      - logs_api:/code/plane/logs
    environment:
      <<: [*app-env, *db-env, *redis-env, *minio-env, *aws-s3-env, *proxy-env]
    depends_on:
      - plane-db
      - plane-redis
      - plane-mq

  worker:
    image: makeplane/plane-backend:${APP_RELEASE:-stable}
    command: ./bin/docker-entrypoint-worker.sh
    deploy:
      replicas: ${WORKER_REPLICAS:-1}
      restart_policy:
        condition: any
    volumes:
      - logs_worker:/code/plane/logs
    environment:
      <<: [*app-env, *db-env, *redis-env, *minio-env, *aws-s3-env, *proxy-env]
    depends_on:
      - api
      - plane-db
      - plane-redis
      - plane-mq

  beat-worker:
    image: makeplane/plane-backend:${APP_RELEASE:-stable}
    command: ./bin/docker-entrypoint-beat.sh
    deploy:
      replicas: ${BEAT_WORKER_REPLICAS:-1}
      restart_policy:
        condition: any
    volumes:
      - logs_beat-worker:/code/plane/logs
    environment:
      <<: [*app-env, *db-env, *redis-env, *minio-env, *aws-s3-env, *proxy-env]
    depends_on:
      - api
      - plane-db
      - plane-redis
      - plane-mq

  migrator:
    image: makeplane/plane-backend:${APP_RELEASE:-stable}
    command: ./bin/docker-entrypoint-migrator.sh
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
    volumes:
      - logs_migrator:/code/plane/logs
    environment:
      <<: [*app-env, *db-env, *redis-env, *minio-env, *aws-s3-env, *proxy-env]
    depends_on:
      - plane-db
      - plane-redis

  # Comment this if you already have a database running
  plane-db:
    image: postgres:15.7-alpine
    command: postgres -c 'max_connections=1000'
    deploy:
      replicas: 1
      restart_policy:
        condition: any
    environment:
      <<: *db-env
    volumes:
      - pgdata:/var/lib/postgresql/data

  plane-redis:
    image: valkey/valkey:7.2.11-alpine
    deploy:
      replicas: 1
      restart_policy:
        condition: any
    volumes:
      - redisdata:/data

  plane-mq:
    image: rabbitmq:3.13.6-management-alpine
    deploy:
      replicas: 1
      restart_policy:
        condition: any
    environment:
      <<: *mq-env
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq

  # Comment this if you using any external s3 compatible storage
  plane-minio:
    image: minio/minio:latest
    command: server /export --console-address ":9090"
    deploy:
      replicas: 1
      restart_policy:
        condition: any
    environment:
      <<: *minio-env
    volumes:
      - uploads:/export

  # Comment this if you already have a reverse proxy running
  proxy:
    image: makeplane/plane-proxy:${APP_RELEASE:-stable}
    deploy:
      replicas: 1
      restart_policy:
        condition: any
    environment:
      <<: *proxy-env
    ports:
      - target: 80
        published: ${LISTEN_HTTP_PORT:-80}
        protocol: tcp
        mode: host
      - target: 443
        published: ${LISTEN_HTTPS_PORT:-443}
        protocol: tcp
        mode: host
    volumes:
      - proxy_config:/config
      - proxy_data:/data
    depends_on:
      - web
      - api
      - space
      - admin
      - live

volumes:
  pgdata:
  redisdata:
  uploads:
  logs_api:
  logs_worker:
  logs_beat-worker:
  logs_migrator:
  rabbitmq_data:
  proxy_config:
  proxy_data:
EOF

    cat > "${plane_dir}/plane.env" <<EOF
APP_DOMAIN=localhost
APP_RELEASE=stable

WEB_REPLICAS=1
SPACE_REPLICAS=1
ADMIN_REPLICAS=1
API_REPLICAS=1
WORKER_REPLICAS=1
BEAT_WORKER_REPLICAS=1
LIVE_REPLICAS=1

LISTEN_HTTP_PORT=80
LISTEN_HTTPS_PORT=443

WEB_URL=http://${host_ip}
DEBUG=0
CORS_ALLOWED_ORIGINS=http://${host_ip}
API_BASE_URL=http://api:8000

#DB SETTINGS
PGHOST=plane-db
PGDATABASE=plane
POSTGRES_USER=plane
POSTGRES_PASSWORD=plane
POSTGRES_DB=plane
POSTGRES_PORT=5432
PGDATA=/var/lib/postgresql/data
DATABASE_URL=

# REDIS SETTINGS
REDIS_HOST=plane-redis
REDIS_PORT=6379
REDIS_URL=

# RabbitMQ Settings
RABBITMQ_HOST=plane-mq
RABBITMQ_PORT=5672
RABBITMQ_USER=plane
RABBITMQ_PASSWORD=plane
RABBITMQ_VHOST=plane
AMQP_URL=

# If SSL Cert to be generated, set CERT_EMAIl="email <EMAIL_ADDRESS>"
CERT_ACME_CA=https://acme-v02.api.letsencrypt.org/directory
TRUSTED_PROXIES=0.0.0.0/0
SITE_ADDRESS=:80
CERT_EMAIL=



# For DNS Challenge based certificate generation, set the CERT_ACME_DNS, CERT_EMAIL
# CERT_ACME_DNS="acme_dns <CERT_DNS_PROVIDER> <CERT_DNS_PROVIDER_API_KEY>"
CERT_ACME_DNS=


# Secret Key
SECRET_KEY=60gp0byfz2dvffa45cxl20p1scy9xbpf6d8c5y0geejgkyp1b5

# DATA STORE SETTINGS
USE_MINIO=1
AWS_REGION=
AWS_ACCESS_KEY_ID=access-key
AWS_SECRET_ACCESS_KEY=secret-key
AWS_S3_ENDPOINT_URL=http://plane-minio:9000
AWS_S3_BUCKET_NAME=uploads
FILE_SIZE_LIMIT=5242880

# Gunicorn Workers
GUNICORN_WORKERS=1

# UNCOMMENT `DOCKER_PLATFORM` IF YOU ARE ON `ARM64` AND DOCKER IMAGE IS NOT AVAILABLE FOR RESPECTIVE `APP_RELEASE`
# DOCKER_PLATFORM=linux/amd64

# Force HTTPS for handling SSL Termination
MINIO_ENDPOINT_SSL=0

# API key rate limit
API_KEY_RATE_LIMIT=60/minute

# Live server environment variables
# WARNING: You must set a secure value for LIVE_SERVER_SECRET_KEY in production environments.
LIVE_SERVER_SECRET_KEY=
DOCKERHUB_USER=makeplane
PULL_POLICY=if_not_present
CUSTOM_BUILD=false
EOF

    echo -e "${GREEN}[OK] Plane files created.${RESET}"
    echo -e "${BLUE}[INFO] Host IP detected: ${host_ip}${RESET}"
    echo -e "${BLUE}[INFO] Created: ${plane_dir}/docker-compose.yaml${RESET}"
    echo -e "${BLUE}[INFO] Created: ${plane_dir}/plane.env${RESET}"
    echo -e "${BLUE}[INFO] Created: ${archive_dir}${RESET}"

    echo -e "${YELLOW}[INFO] Starting Plane stack with Docker Compose...${RESET}"

    (
        cd "$plane_dir" || exit 1
        docker compose --env-file plane.env -f docker-compose.yaml up -d
    ) || {
        echo -e "${RED}[ERROR] Failed to start Plane stack with Docker Compose.${RESET}"
        return 1
    }

    echo -e "${GREEN}[OK] Plane stack started.${RESET}"
    echo -e "${BLUE}[INFO] Access URL: http://${host_ip}${RESET}"
}

#==================================================
# Function: Install Next Terminal Stack
#==================================================
install_next_terminal() {
    local next_terminal_dir

    next_terminal_dir="/opt/next_terminal"

    echo -e "${YELLOW}[INFO] Creating required directories...${RESET}"
    mkdir -p /dockerfile/guacd || return 1
    mkdir -p /dockerfile/next-terminal || return 1
    mkdir -p /opt/next_terminal || return 1

    echo -e "${YELLOW}[INFO] Downloading Next Terminal compose files...${RESET}"
    mkdir -p "$next_terminal_dir" || return 1

    (
        cd "$next_terminal_dir" || exit 1
        curl -sSL https://f.typesafe.cn/next-terminal/docker-compose-aliyun.yaml > docker-compose.yaml || exit 1
        curl -sSL https://f.typesafe.cn/next-terminal/config.yaml > config.yaml || exit 1
        docker compose up -d || exit 1
    ) || {
        echo -e "${RED}[ERROR] Failed to deploy Next Terminal stack.${RESET}"
        return 1
    }

    echo -e "${GREEN}[OK] Next Terminal stack started.${RESET}"
    echo -e "${BLUE}[INFO] Compose path: ${next_terminal_dir}/docker-compose.yaml${RESET}"
    echo -e "${BLUE}[INFO] Config path: ${next_terminal_dir}/config.yaml${RESET}"
}

#==================================================
# Main Loop
#==================================================
main() {
    check_root

    while true; do
        show_menu
        read -rp "Please select an option [1-13]: " choice

        case "$choice" in
            1)
                install_docker_full
                pause
                ;;
            2)
                modify_docker_repository_cn
                pause
                ;;
            3)
                modify_pip_repository_cn
                pause
                ;;
            4)
                disable_selinux
                pause
                ;;
            5)
                install_plane_stack
                pause
                ;;
            6)
                install_next_terminal
                pause
                ;;
            7|8|9|10|11|12)
                echo -e "${YELLOW}[INFO] Coming Soon.${RESET}"
                pause
                ;;
            13)
                exit 0
                ;;
            *)
                echo -e "${RED}[ERROR] Invalid option.${RESET}"
                pause
                ;;
        esac
    done
}

main
