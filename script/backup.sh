#!/usr/bin/env bash

START_TIME="$(date '+%y%m%d_%H%M%S')"
UNIT_NAME="$(basename "$(pwd)")"

BACKUP_DIR="./backup"
BACKUP_FILE="$BACKUP_DIR/${UNIT_NAME}_${START_TIME}.tgz"
mkdir -p "$BACKUP_DIR"

log_info()  { echo -e "\033[1;32m[INFO]\033[0m $*"  ; }
log_warn()  { echo -e "\033[1;33m[WARN]\033[0m $*"  ; }
log_error() { echo -e "\033[1;31m[ERROR]\033[0m $*" ; }
log_debug() { echo -e "\033[1;35m[DEBUG]\033[0m $*" ; }

################################################################################

run_command() {
    echo -en "\033[1;30m"
    $@
    RET=$?
    echo -en "\033[0m"
    return $RET
}

# check() {
#     which $1 > /dev/null 2>&1
# }

check_docker() {
    VER_DOCKER="$(docker --version)"
    if [ $? -ne 0 ]; then
        log_error "Docker is NOT installed. Please install docker first."
        exit
    else
        log_info "Docker is installed. \033[1;30m($VER_DOCKER)\033[0m"
    fi

    VER_COMPOSE="$(docker compose version)"
    if [ $? -ne 0 ]; then
        log_error "Compose plugin is NOT installed. Please install docker-compose(v2) first."
        exit
    else
        log_info "Compose plugin is installed. \033[1;30m($VER_COMPOSE)\033[0m"
    fi
}

is_service_enabled() {
    docker compose config --services | grep -x "$1" > /dev/null 2>&1
}

################################################################################

dump_mariadb() {
    DB_DIR="./service/mariadb/init"
    DB_FILE="$DB_DIR/backup_$START_TIME.sql"
    mkdir -p "$DB_DIR"
    rm -f "$DB_DIR"/backup*.sql

    log_info "Dumping the mariadb database..."
    docker compose exec mariadb \
        sh -c 'exec mysqldump --databases "$MYSQL_DATABASE" -uroot -p"$MYSQL_ROOT_PASSWORD" --skip-extended-insert' \
        > "$DB_FILE"

    if [ $? -ne 0 ]; then
        rm "$DB_FILE"
        log_error "Failed to dump the database."
        log_error "Make sure the mariadb container is running."
        echo
        exit
    fi
}

################################################################################

main() {
    echo "========================================"
    echo ">>> Docker Backup Script (v.1.1.0)"
    echo "========================================"
    echo

    if [ ! -e "$(pwd)/docker-compose.yml" ]; then
        log_error "The 'docker-compose.yml' file does not exist in current working directory."
        log_error "Change working directory to the path it is in and run this script again."
        echo
        exit
    fi

    log_info "Started full backup at $(date)."
    log_info "Output Path : $BACKUP_FILE"
    echo

    if is_service_enabled "mariadb"; then 
        dump_mariadb
    fi

    log_info "Compressing all files..."
    tar --exclude='./backup' \
        --exclude='./service/mariadb/database' \
        -cf "$BACKUP_FILE" .
        # -zcf "$BACKUP_FILE" .

    log_info "Backup completed at $(date)."
    echo

    ls "$BACKUP_DIR" -lh | grep "$START_TIME"
}

main
