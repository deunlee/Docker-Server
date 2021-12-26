#!/bin/bash

VER_WORDPRESS="5.8.2"
VER_PHP_MY_ADMIN="5.1.1"

PATH_ASSET="./asset"
PATH_BACKUP="./backup"
PATH_LOG="./log"
PATH_SVC="./service"
PATH_HTML="./www/html"

mkdir -p "$PATH_ASSET"
mkdir -p "$PATH_LOG/nginx"
mkdir -p "$PATH_LOG/php"
mkdir -p "$PATH_SVC/mariadb/database"
mkdir -p "$PATH_SVC/mariadb/init"
mkdir -p "$PATH_HTML"


NC='\033[0m' # No Color
RED='\033[0;31m'
DGRAY='\033[1;30m'


confirm() {
    # $1 for prompt string, $2 for default answer
    prompt="${1:-Are you sure?} "
    case $2 in
        [Yy]) prompt="$prompt[Y/n] " ;;
        [Nn]) prompt="$prompt[y/N] " ;;
        *)    prompt="$prompt[y/n] " ;;
    esac
    while true; do
        read -r -p "$prompt" response
        case $response in
            [Yy]|[Yy][Ee][Ss]) echo 'y'; break ;;
            [Nn]|[Nn][Oo])     echo 'n'; break ;;
            "") 
                case $2 in
                    [Yy]) echo 'y'; break ;;
                    [Nn]) echo 'n'; break ;;
                esac ;;
        esac
    done
}


get_random_string() {
    echo "$(tr -dc A-Za-z0-9 </dev/urandom | head -c 32 ; echo '')"
}


install_php_my_admin() {
    PMA_URL="https://files.phpmyadmin.net/phpMyAdmin/$VER_PHP_MY_ADMIN/phpMyAdmin-$VER_PHP_MY_ADMIN-all-languages.zip"
    PMA_FILE="$PATH_ASSET/${PMA_URL##*/}"
    PMA_DIR="${PMA_FILE%.zip}"
    PMA_PATH="$PATH_HTML/pma"

    # Confirm reinstallation if already installed.
    if [ -d "$PMA_PATH" ]; then
        echo ">>> phpMyAdmin is already installed."
        if [ $(confirm ">>> Do you want to reinstall?" "n") = "n" ]; then
            return 0
        fi
    fi

    # Download the file.
    if [ ! -e "$PMA_FILE" ]; then
        echo -e "${DGRAY}\c"
        wget "$PMA_URL" -O "$PMA_FILE"
        echo -e "${NC}\c"
    fi

    # Unzip and move it.
    rm -rf "$PMA_DIR"
    rm -rf "$PMA_PATH"
    unzip -q "$PMA_FILE" -d "$PATH_ASSET"
    mv "$PMA_DIR" "$PMA_PATH"

    # Update the config file.
    cp "$PMA_PATH/config.sample.inc.php" "$PMA_PATH/config.inc.php"
    sed -i -e "s/cfg\['blowfish_secret'\] = ''/cfg['blowfish_secret'] = '$(get_random_string)'/" "$PMA_PATH/config.inc.php"
    sed -i -e "s/\['host'\] = 'localhost'/\['host'\] = 'mariadb'/" "$PMA_PATH/config.inc.php"

    # Create temporary directory.
    mkdir "$PMA_PATH/tmp"
    chmod 777 "$PMA_PATH/tmp"
    echo ">>> phpMyAdmin has been successfully installed."
}


install_wordpress() {
    # https://wordpress.org/download/releases/
    WP_URL="https://wordpress.org/wordpress-$VER_WORDPRESS.tar.gz"
    WP_FILE="$PATH_ASSET/${WP_URL##*/}"
    WP_PATH="$PATH_HTML/wp"
    WP_PATH_OLD="$PATH_HTML/wp-old"

    # Confirm reinstallation if already installed.
    if [ -d "$WP_PATH" ]; then
        echo ">>> WordPress is already installed."
        if [ $(confirm ">>> Do you want to reinstall?" "n") = "n" ]; then
            return 0
        fi
        rm -rf "$WP_PATH_OLD"
        mv "$WP_PATH" "$WP_PATH_OLD"
    fi

    # Download the file.
    if [ ! -e "$WP_FILE" ]; then
        echo -e "${DGRAY}\c"
        wget "$WP_URL" -O "$WP_FILE"
        echo -e "${NC}\c"
    fi

    # Unzip and move it.
    rm -rf "$PATH_ASSET/wordpress"
    tar zxf "$WP_FILE" -C "$PATH_ASSET"
    mv "$PATH_ASSET/wordpress" "$WP_PATH"

    # Update the config file.
    DB_CONFIG="$PATH_SVC/mariadb/config.env"
    WP_CONFIG="$WP_PATH/wp-config.php"
    cp "$WP_PATH/wp-config-sample.php" "$WP_CONFIG"
    sed -i "s/database_name_here/$(. $DB_CONFIG; echo $MYSQL_DATABASE)/" "$WP_CONFIG"
    sed -i "s/username_here/$(. $DB_CONFIG; echo $MYSQL_USER)/" "$WP_CONFIG"
    sed -i "s/password_here/$(. $DB_CONFIG; echo $MYSQL_PASSWORD)/" "$WP_CONFIG"
    sed -i "s/localhost/mariadb/" "$WP_CONFIG"
    get_wp_random() {
        echo "$(cat /dev/urandom | tr -dc 'a-zA-Z0-9!@#\%+=' | fold -w 64 | sed 1q)"
    }
    sed -i "s/define( 'AUTH_KEY',         'put your unique phrase here' );/define( 'AUTH_KEY',         '$(get_wp_random)' );/g" "$WP_CONFIG"
    sed -i "s/define( 'SECURE_AUTH_KEY',  'put your unique phrase here' );/define( 'SECURE_AUTH_KEY',  '$(get_wp_random)' );/g" "$WP_CONFIG"
    sed -i "s/define( 'LOGGED_IN_KEY',    'put your unique phrase here' );/define( 'LOGGED_IN_KEY',    '$(get_wp_random)' );/g" "$WP_CONFIG"
    sed -i "s/define( 'NONCE_KEY',        'put your unique phrase here' );/define( 'NONCE_KEY',        '$(get_wp_random)' );/g" "$WP_CONFIG"
    sed -i "s/define( 'AUTH_SALT',        'put your unique phrase here' );/define( 'AUTH_SALT',        '$(get_wp_random)' );/g" "$WP_CONFIG"
    sed -i "s/define( 'SECURE_AUTH_SALT', 'put your unique phrase here' );/define( 'SECURE_AUTH_SALT', '$(get_wp_random)' );/g" "$WP_CONFIG"
    sed -i "s/define( 'LOGGED_IN_SALT',   'put your unique phrase here' );/define( 'LOGGED_IN_SALT',   '$(get_wp_random)' );/g" "$WP_CONFIG"
    sed -i "s/define( 'NONCE_SALT',       'put your unique phrase here' );/define( 'NONCE_SALT',       '$(get_wp_random)' );/g" "$WP_CONFIG"

    if [ $(confirm ">>> Do you want to add NGINX config file for WordPress?" "y") = "y" ]; then
        read -p ">>> Enter your domain name (test.lan): " NG_DOMAIN
        NG_DOMAIN=${NG_DOMAIN:-test.lan}
        NG_DEFAULT="$PATH_SVC/nginx/sites-available/your.domain.com.conf"
        NG_CONFIG="$PATH_SVC/nginx/sites-enabled/$NG_DOMAIN.conf"
        cp "$NG_DEFAULT" "$NG_CONFIG"
        sed -i "s/private\/your.domain.com/private\/default/" "$NG_CONFIG"
        sed -i "s/your.domain.com/$NG_DOMAIN/" "$NG_CONFIG"
    fi

    echo ">>> WordPress has been successfully installed."
}


init_mariadb() {
    DB_CONFIG="$PATH_SVC/mariadb/config.env"
    if [ ! -e "$DB_CONFIG" ]; then
        echo ">>> Creating MariaDB config file..."
        cp "$PATH_SVC/mariadb/config-sample.env" "$DB_CONFIG"
        sed -i -e "s/MYSQL_ROOT_PASSWORD=.*/MYSQL_ROOT_PASSWORD=$(get_random_string)/" "$DB_CONFIG"
        sed -i -e "s/MYSQL_PASSWORD=.*/MYSQL_PASSWORD=$(get_random_string)/" "$DB_CONFIG"
    fi
}


init_nginx() {
    # Generate default certificate.
    CERT_PATH="$PATH_SVC/nginx/private"
    CERT_FILE="$CERT_PATH/default.pem"
    CERT_KEY="$CERT_PATH/default.key"
    mkdir -p "$CERT_PATH"
    if [ ! -e "$CERT_FILE" ] || [ ! -e "$CERT_KEY" ]; then
        echo ">>> Generating a default certificate for NGINX..."
        echo -e "${DGRAY}\c"
        openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
            -subj   "/C=US/ST=Test/L=Test/O=Test/CN=test.com" \
            -keyout "$CERT_KEY" \
            -out    "$CERT_FILE"
        # openssl x509 -text -noout -in "$CERT_FILE"
        echo -e "${NC}"
        chmod 600 "$CERT_KEY"
        chmod 600 "$CERT_FILE"
    fi
}


main() {
    echo "========================================"
    echo ">>> Docker Server Init Script (V.1.2.1)"
    echo "========================================"
    echo

    if [ ! -e "$(pwd)/docker-compose.yml" ]; then
        echo
        echo ">>> The 'docker-compose.yml' file does not exist in current working directory."
        echo ">>> Change working directory to the path it is in and run this script again."
        echo
        exit
    fi

    if [ $(confirm ">>> Do you want to install WordPress?" "y") = "y" ]; then
        install_wordpress
        echo
    fi

    if [ $(confirm ">>> Do you want to install phpMyAdmin?" "n") = "y" ]; then
        install_php_my_admin
        echo
    fi

    init_mariadb
    init_nginx


    echo ">>> Finished!"
}

main
