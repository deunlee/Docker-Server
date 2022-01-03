#!/usr/bin/env bash

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

################################################################################

NC="\033[0m" # No Color
BLACK="\033[0;30m"  ; DGRAY="\033[1;30m"
RED="\033[0;31m"    ; LRED="\033[1;31m"
GREEN="\033[0;32m"  ; LGREEN="\033[1;32m"
YELLOW="\033[0;33m" ; LYELLOW="\033[1;33m"
BLUE="\033[0;34m"   ; LBLUE="\033[1;34m"
PURPLE="\033[0;35m" ; LPURPLE="\033[1;35m"
CYAN="\033[0;36m"   ; LCYAN="\033[1;36m"
LGRAY="\033[0;37m"  ; WHITE="\033[1;37m"

log_info()  { echo -e "${LGREEN}[INFO]${NC} $*"   ; }
log_warn()  { echo -e "${LYELLOW}[WARN]${NC} $*"  ; }
log_error() { echo -e "${LRED}[ERROR]${NC} $*"    ; }
log_debug() { echo -e "${LPURPLE}[DEBUG]${NC} $*" ; }

confirm() {
    # $1 for prompt string, $2 for default answer
    PROMPT="${1:-Are you sure?} "
    case $2 in
        [Yy]) PROMPT="$PROMPT[Y/n] " ;;
        [Nn]) PROMPT="$PROMPT[y/N] " ;;
        *)    PROMPT="$PROMPT[y/n] " ;;
    esac
    while true; do
        echo -en "\033[1;36m[CHECK]\033[0m " 1>&2
        read -r -p "$PROMPT" INPUT
        case $INPUT in
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

################################################################################

install_php_my_admin() {
    PMA_URL="https://files.phpmyadmin.net/phpMyAdmin/$VER_PHP_MY_ADMIN/phpMyAdmin-$VER_PHP_MY_ADMIN-all-languages.zip"
    PMA_FILE="$PATH_ASSET/${PMA_URL##*/}"
    PMA_DIR="${PMA_FILE%.zip}"
    PMA_PATH="$PATH_HTML/pma"

    # Confirm reinstallation if already installed.
    if [ -d "$PMA_PATH" ]; then
        log_info "phpMyAdmin is already installed."
        if [ $(confirm "Do you want to reinstall?" "n") = "n" ]; then
            return 0
        fi
    fi

    # Download the file.
    if [ ! -e "$PMA_FILE" ]; then
        run_command wget "$PMA_URL" -O "$PMA_FILE"
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
    log_info "phpMyAdmin has been successfully installed. (v.$VER_PHP_MY_ADMIN)"
}

################################################################################

install_wordpress() {
    # https://wordpress.org/download/releases/
    WP_URL="https://wordpress.org/wordpress-$VER_WORDPRESS.tar.gz"
    WP_FILE="$PATH_ASSET/${WP_URL##*/}"
    WP_PATH="$PATH_HTML/wp"
    WP_PATH_OLD="$PATH_HTML/wp-old"

    # Confirm reinstallation if already installed.
    if [ -d "$WP_PATH" ]; then
        log_info "WordPress is already installed."
        if [ $(confirm "Do you want to reinstall?" "n") = "n" ]; then
            return 0
        fi
        rm -rf "$WP_PATH_OLD"
        mv "$WP_PATH" "$WP_PATH_OLD"
    fi

    # Download the file.
    if [ ! -e "$WP_FILE" ]; then
        run_command wget "$WP_URL" -O "$WP_FILE"
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

    if [ $(confirm "Do you want to add NGINX config file for WordPress?" "y") = "y" ]; then
        echo -en "\033[1;36m[CHECK]\033[0m " 1>&2
        read -p "Enter your domain name (test.lan): " NG_DOMAIN
        NG_DOMAIN=${NG_DOMAIN:-test.lan}
        NG_DEFAULT="$PATH_SVC/nginx/sites-available/your.domain.com.conf"
        NG_CONFIG="$PATH_SVC/nginx/sites-enabled/$NG_DOMAIN.conf"
        cp "$NG_DEFAULT" "$NG_CONFIG"
        sed -i "s/private\/your.domain.com/private\/default/" "$NG_CONFIG"
        sed -i "s/your.domain.com/$NG_DOMAIN/" "$NG_CONFIG"
    fi

    log_info "WordPress has been successfully installed. (v.$VER_WORDPRESS)"
}

################################################################################

init_mariadb() {
    DB_CONFIG="$PATH_SVC/mariadb/config.env"
    if [ ! -e "$DB_CONFIG" ]; then
        log_info "Creating MariaDB config file..."
        cp "$PATH_SVC/mariadb/config-sample.env" "$DB_CONFIG"
        sed -i -e "s/MYSQL_ROOT_PASSWORD=.*/MYSQL_ROOT_PASSWORD=$(get_random_string)/" "$DB_CONFIG"
        sed -i -e "s/MYSQL_PASSWORD=.*/MYSQL_PASSWORD=$(get_random_string)/" "$DB_CONFIG"
    fi
}

################################################################################

init_nginx() {
    # Generate default certificate.
    CERT_PATH="$PATH_SVC/nginx/private"
    CERT_FILE="$CERT_PATH/default.pem"
    CERT_KEY="$CERT_PATH/default.key"
    mkdir -p "$CERT_PATH"
    if [ ! -e "$CERT_FILE" ] || [ ! -e "$CERT_KEY" ]; then
        log_info "Generating a default certificate for NGINX..."
        run_command openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
            -subj   "/C=US/ST=Test/L=Test/O=Test/CN=test.com" \
            -keyout "$CERT_KEY" \
            -out    "$CERT_FILE"
        # openssl x509 -text -noout -in "$CERT_FILE"
        chmod 600 "$CERT_KEY"
        chmod 600 "$CERT_FILE"
    fi
}

################################################################################

main() {
    echo "========================================"
    echo ">>> Docker Server Init Script (V.1.3.0)"
    echo "========================================"
    echo

    if [ ! -e "$(pwd)/docker-compose.yml" ]; then
        echo
        log_error "The 'docker-compose.yml' file does not exist in current working directory."
        log_error "Change working directory to the path it is in and run this script again."
        echo
        exit
    fi

    check_docker

    if [ $(confirm "Do you want to install WordPress?" "y") = "y" ]; then
        install_wordpress
        echo
    fi

    if [ $(confirm "Do you want to install phpMyAdmin?" "n") = "y" ]; then
        install_php_my_admin
        echo
    fi

    init_mariadb
    init_nginx


    log_info "Finished!"
}

main
