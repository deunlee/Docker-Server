#!/bin/bash

# Colors
# Black        0;30     Dark Gray     1;30
# Red          0;31     Light Red     1;31
# Green        0;32     Light Green   1;32
# Brown/Orange 0;33     Yellow        1;33
# Blue         0;34     Light Blue    1;34
# Purple       0;35     Light Purple  1;35
# Cyan         0;36     Light Cyan    1;36
# Light Gray   0;37     White         1;37

log_info()  { echo -e "\033[1;32m[INFO]\033[0m $*" ; }
log_warn()  { echo -e "\033[1;33m[WARN]\033[0m $*" ; }
log_error() { echo -e "\033[1;31m[ERROR]\033[0m $*" ; }
log_debug() { echo -e "\033[1;35m[DEBUG]\033[0m $*" ; }
# $@ is array, $* is string, $# is param count, $? is return value

confirm() {
    # $1 for prompt string, $2 for default answer
    prompt="${1:-Are you sure?} "
    case $2 in
        [Yy]) prompt="$prompt[Y/n] " ;;
        [Nn]) prompt="$prompt[y/N] " ;;
        *)    prompt="$prompt[y/n] " ;;
    esac
    while true; do
        echo -en "\033[1;36m[CHECK]\033[0m " 1>&2
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

get_distribution() {
	DIST_ID=""
	if [ -r /etc/os-release ]; then
		DIST_ID="$(. /etc/os-release && echo "$ID")"
	fi
	echo "$DIST_ID"
}

run_command() {
    echo -en "\033[1;30m"
    $@
    RET=$?
    echo -en "\033[0m"
    return $RET
}


check() {
    which $1 > /dev/null 2>&1
}

update() {
    if check apt ; then
        run_command sudo apt 
    elif check yum ; then
        run_command sudo yum update
    fi
    # yum update -y
}

install() {
    if check apt ; then
        run_command sudo apt install -y $@ | cat
    elif check yum ; then
        run_command sudo yum -y install $@ | cat
    else
        log_error "This script only supports apt and yum package managers."
        exit
    fi

    RET=$?
    # T="is"; if [ $# -gt 1 ]; then T="are"; fi
    if [ $RET -eq 0 ]; then
        # log_info "$* $T installed!"
        return 0
    else
        # log_error "$* $T not installed."
        return 1
    fi
}

install_package() { # install a package
    PACKAGE="$1"
    RECOMMEND="${2:-y}"
    INSTALL_FUNC="${3:-install}"

    T=""
    if check "$PACKAGE" ; then
        T=" already"
    elif [ $(confirm "Do you want to install $PACKAGE?" "$RECOMMEND") = "y" ]; then
        $INSTALL_FUNC "$PACKAGE"
        if [ $? -ne 0 ]; then # failed to install
            log_error "The package is NOT installed: $PACKAGE"
            return 1
        fi
    else
        return 0 # user pressed "n"
    fi
    
    VERSION="$($PACKAGE --version | head -n 1)"
    log_info "The package is$T installed: $PACKAGE \033[1;30m($VERSION)\033[0m"
    if [ "$T" = "" ]; then echo ; fi
}

################################################################################

install_htop() {
    echo -en "\033[1;30m"
    case $(get_distribution) in
        centos) install epel-release; install htop ;;
        *)      install htop ;;
    esac
}

################################################################################

zsh_install_oh_my_zsh() {
    check zsh; if [ $? -ne 0 ]; then return 1; fi # zsh is not installed

    if [ -e ~/.oh-my-zsh ]; then
        log_info "The plugin  is already installed: oh-my-zsh"
    elif [ $(confirm "Do you want to install oh-my-zsh?" "y") = "y" ]; then
        # https://github.com/ohmyzsh/ohmyzsh
        echo -en "\033[1;30m"
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" --skip-chsh --unattended | cat
        if [ $? -eq 0 ]; then
            log_info "The plugin is installed: oh-my-zsh"
        else
            log_error "The plugin is NOT installed: oh-my-zsh"
            return 1
        fi

        run_command git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
        log_info "The plugin is installed: zsh-syntax-highlighting"

        run_command git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
        log_info "The plugin is installed: zsh-autosuggestions"
        echo

        sed -i 's/ZSH_THEME="[A-Za-z]*"/ZSH_THEME="agnoster"/' ~/.zshrc
        sed -i 's/plugins=([A-Za-z]*)/plugins=(git zsh-syntax-highlighting zsh-autosuggestions)/' ~/.zshrc
        # source ~/.zshrc
    fi
}

zsh_set_default_shell() {
    check zsh; if [ $? -ne 0 ]; then return 1; fi # zsh is not installed

    if [ "$SHELL" != "$(which zsh)" ]; then
        if [ $(confirm "Do you want to change default shell to zsh?" "y") = "y" ]; then
            # sudo chsh -s $(which zsh)
            run_command sudo usermod --shell $(which zsh) $USER
            log_info "The default shell changed to zsh."
            log_info "This setting will not take effect until you log in again."
        fi
        echo
    fi
}

################################################################################

install_docker() {
    echo -en "\033[1;30m"
    case $(get_distribution) in
        amzn) sudo yum -y install docker              ;;
        *)    curl -fsSL https://get.docker.com/ | sh ;;
    esac
    if [ $? -ne 0 ]; then return 1; fi

    run_command sudo systemctl start docker
    run_command sudo systemctl enable docker
    echo

    if [ $(confirm "Do you want to add the current user ($USER) to the docker group?" "y") = "y" ]; then
        sudo usermod -aG docker $USER
        cat /etc/group | grep docker > /dev/null
        if [ $? -eq 0 ]; then
            log_info "The current user has been added to the docker group."
            log_info "This setting will not take effect until you log in again."
        fi
    fi
}

docker_install_compose() {
    check docker; if [ $? -ne 0 ]; then return 1; fi

    T=""
    if [ -e ~/.docker/cli-plugins ]; then
        T=" already"
    elif [ $(confirm "Do you want to install docker-compose(v.2)?" "y") = "y" ]; then
        # https://github.com/docker/compose/releases
        mkdir -p ~/.docker/cli-plugins/
        run_command curl -SL "https://github.com/docker/compose/releases/download/v2.2.2/docker-compose-linux-$(uname -m)" -o ~/.docker/cli-plugins/docker-compose
        if [ $? -ne 0 ]; then
            log_error "The plugin is NOT installed: docker-compose"
            return 1
        fi
        chmod +x ~/.docker/cli-plugins/docker-compose
    fi

    VERSION="$(docker compose version)"
    log_info "The plugin  is$T installed: docker-compose \033[1;30m($VERSION)\033[0m"
    if [ "$T" = "" ]; then echo ; fi
}

################################################################################

install_code_server() {
    CONFIG_FILE=~/.config/code-server/config.yaml

    echo -en "\033[1;30m"
    curl -fsSL https://code-server.dev/install.sh | sh
    if [ $? -ne 0 ]; then return 1; fi

    run_command sudo systemctl start code-server@$USER
    run_command sudo systemctl enable code-server@$USER
    echo
    
    if [ $(confirm "Do you want to change the bind address to allow external access to code-server?" "y") = "y" ]; then
        sed -i 's/bind-addr: 127.0.0.1/bind-addr: 0.0.0.0/' $CONFIG_FILE
        run_command sudo systemctl restart code-server@$USER
    fi
    run_command sudo systemctl status code-server@$USER | cat
    run_command cat "$CONFIG_FILE"
}

################################################################################

main() {
    echo "========================================"
    echo ">>> DeunLee's Init Script (v.1.0.0)"
    echo "========================================"
    echo
    
    run_command uname -mrs
    run_command id
    echo

    if [ "$USER" = "root" ]; then
        log_warn "Current user is root."
        log_warn "It is recommended to change to another user."
        if [ $(confirm "Do you want to continue?" "n") = "n" ]; then
            exit
        fi
    fi

    # update

    install_package "htop" "" "install_htop"
    install_package "git"
    install_package "gcc"
    install_package "zsh"
    zsh_install_oh_my_zsh
    zsh_set_default_shell
    # sudo apt install fonts-powerline
    install_package "docker" "" "install_docker"
    docker_install_compose
    install_package "code-server" "" "install_code_server"

    #TODO vim
    
    log_info "Finished!"
}

main
