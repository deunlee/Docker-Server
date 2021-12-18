#!/bin/bash

if [ ! -e "$(pwd)/docker-compose.yml" ]; then
    echo
    echo ">>> The 'docker-compose.yml' file does not exist in current working directory."
    echo ">>> Change working directory to the path it is in and run this script again."
    echo
    exit
fi

START_TIME="$(date '+%y%m%d_%H%M%S')"
UNIT_NAME="$(basename "$(pwd)")"

BACKUP_DIR="./backup"
BACKUP_FILE="$BACKUP_DIR/${UNIT_NAME}_${START_TIME}.tgz"
mkdir -p "$BACKUP_DIR"


is_service_enabled() {
    docker compose config --services | grep -x "$1" > /dev/null 2>&1
}

dump_mariadb() {
    DB_DIR="./service/mariadb/init"
    DB_FILE="$DB_DIR/backup_$START_TIME.sql"
    mkdir -p "$DB_DIR"
    rm -f "$DB_DIR"/backup*.sql

    echo ">>> Dumping the mariadb database..."
    docker compose exec mariadb \
        sh -c 'exec mysqldump --databases "$MYSQL_DATABASE" -uroot -p"$MYSQL_ROOT_PASSWORD" --skip-extended-insert' \
        > "$DB_FILE"

    if [ $? -ne 0 ]; then
        rm "$DB_FILE"
        echo ">>> Failed to dump the database."
        echo ">>> Make sure the mariadb container is running."
        echo
        exit
    fi
}

main() {
    echo "========================================"
    echo ">>> Docker Backup Script (V.1.0.0)"
    echo "========================================"
    echo
    echo ">>> Started full backup at $(date)."
    echo ">>> Output Path : $BACKUP_FILE"
    echo

    if is_service_enabled "mariadb"; then 
        dump_mariadb
    fi

    echo ">>> Compressing all files..."
    tar --exclude='./backup' \
        --exclude='./service/mariadb/database' \
        -cf "$BACKUP_FILE" .
        # -zcf "$BACKUP_FILE" .

    echo ">>> Backup completed at $(date)."
    echo

    ls "$BACKUP_DIR" -lh | grep "$START_TIME"
}


main

