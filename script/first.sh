#!/usr/bin/env bash

SCRIPT_DIR="$(dirname $(readlink -f $0))"

# Colors
# Black        0;30     Dark Gray     1;30
# Red          0;31     Light Red     1;31
# Green        0;32     Light Green   1;32
# Brown/Orange 0;33     Yellow        1;33
# Blue         0;34     Light Blue    1;34
# Purple       0;35     Light Purple  1;35
# Cyan         0;36     Light Cyan    1;36
# Light Gray   0;37     White         1;37

log_info()  { echo -e "\033[1;32m[INFO]\033[0m $*"  ; }
log_warn()  { echo -e "\033[1;33m[WARN]\033[0m $*"  ; }
log_error() { echo -e "\033[1;31m[ERROR]\033[0m $*" ; }
log_debug() { echo -e "\033[1;35m[DEBUG]\033[0m $*" ; }
# $@ is array, $* is string, $# is param count, $? is return value

confirm() {
    # $1 for prompt string, $2 for default answer
    PROMPT="${1:-Are you sure?} "
    DEFAULT=""
    INPUT=""
    case $2 in
        [Yy]) DEFAULT="y"; PROMPT="$PROMPT[Y/n] "   ;;
        [Nn]) DEFAULT="n"; PROMPT="$PROMPT[y/N] "   ;;
        [Ii]) DEFAULT="i"; PROMPT="$PROMPT[y/n/I] " ;;
        Yi)   DEFAULT="y"; PROMPT="$PROMPT[Y/n/i] " ;;
        Ni)   DEFAULT="n"; PROMPT="$PROMPT[y/N/i] " ;;
        yni)  DEFAULT="";  PROMPT="$PROMPT[y/n/i] " ;;
        *)    DEFAULT="";  PROMPT="$PROMPT[y/n] "   ;;
    esac
    while true; do
        echo -en "\033[1;36m[CHECK]\033[0m " 1>&2
        read -r -p "$PROMPT" INPUT
        case $INPUT in
            [Yy]|[Yy][Ee][Ss]) echo 'y'; break ;;
            [Nn]|[Nn][Oo])     echo 'n'; break ;;
            [Ii]|[Ii][Nn][Tt])
                case $2 in
                    [Ii]|Yi|Ni|yni) echo 'i'; break ;;
                esac ;;
            "")
                if [ "$DEFAULT" != "" ]; then
                    echo "$DEFAULT"; break
                fi ;;
        esac
    done
}

trim() {
    # https://stackoverflow.com/questions/369758/how-to-trim-whitespace-from-a-bash-variable
    local var="$*"
    # Remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # Remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"   
    printf '%s' "$var"
}

get_distribution() {
	DIST_ID=""
	if [ -r /etc/os-release ]; then
		DIST_ID="$(. /etc/os-release && echo "$ID")"
	fi
	echo "$DIST_ID"
}

################################################################################

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

    if [ $? -ne 0 ]; then
        log_error "Failed to update"
    fi
}

################################################################################

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
        if [ $? -ne 0 ]; then
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

install_script() { # install(download) a script (/usr/local/bin)
    SCRIPT="$1"
    RECOMMEND="${2:-y}"
    DOWNLOAD_URL="$3"

    SCRIPT_PATH="/usr/local/bin/$SCRIPT"

    T=""
    if [ -e "$SCRIPT_PATH" ] ; then
        T=" already"
    elif [ $(confirm "Do you want to install $SCRIPT script?" "$RECOMMEND") = "y" ]; then
        run_command sudo curl -o "$SCRIPT_PATH" -fsSL "$DOWNLOAD_URL"
        if [ $? -ne 0 ]; then
            log_error "The script is NOT installed: $SCRIPT"
            return 1
        fi
        sudo chmod +x "$SCRIPT_PATH"
    else
        return 0 # user pressed "n"
    fi
    
    log_info "The script  is$T installed: $SCRIPT"
    if [ "$T" = "" ]; then echo ; fi
}

################################################################################

install_htop() {
    case $(get_distribution) in
        centos) install epel-release; install htop ;;
        *)      install htop ;;
    esac
}

################################################################################

install_oh_my_zsh() {
    check zsh; if [ $? -ne 0 ]; then return 1; fi # zsh is not installed

    T=""
    if [ -e ~/.oh-my-zsh ]; then
        T=" already"
    elif [ $(confirm "Do you want to install oh-my-zsh?" "y") = "y" ]; then
        # https://github.com/ohmyzsh/ohmyzsh
        echo -en "\033[1;30m"
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" --skip-chsh --unattended | cat
        if [ $? -ne 0 ]; then
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

    VERSION="$(git --git-dir ~/.oh-my-zsh/.git --no-pager log -1 --format='%ai')"
    log_info "The plugin  is$T installed: oh-my-zsh \033[1;30m($VERSION)\033[0m"
    if [ "$T" = "" ]; then echo ; fi
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

install_docker_compose() {
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

    install_code_server_extensions
}

install_code_server_extensions() {
    check code-server; if [ $? -ne 0 ]; then return 1; fi

    INPUT=$(confirm "Do you want to install some extensions for code-server?" "Yi")
    if [ "$INPUT" = "n" ]; then return 0; fi

    EXT_FILE="$SCRIPT_DIR/code_server_ext.txt"
    cat <<EOT > "$EXT_FILE"
############### Development ###############
ms-vscode.cpptools
ms-python.python
# ms-azuretools.vscode-docker

################## Tool ###################
mhutchie.git-graph
tomoki1207.pdf
tyriar.sort-lines

############### JavaScript ################
# dbaeumer.vscode-eslint
# editorconfig.editorconfig

################## Style ##################
vscode-icons-team.vscode-icons
# ms-ceintl.vscode-language-pack-ko
# ms-ceintl.vscode-language-pack-ja
EOT

    if check docker;              then sed -i 's/# ms-azuretools.vscode-docker/ms-azuretools.vscode-docker/'             "$EXT_FILE"; fi
    if [ "$(date +%Z)" = "KST" ]; then sed -i 's/# ms-ceintl.vscode-language-pack-ko/ms-ceintl.vscode-language-pack-ko/' "$EXT_FILE"; fi
    if [ "$(date +%Z)" = "JST" ]; then sed -i 's/# ms-ceintl.vscode-language-pack-ja/ms-ceintl.vscode-language-pack-ja/' "$EXT_FILE"; fi

    if [ "$INPUT" = "i" ]; then
        vi "$EXT_FILE"
    fi

    while IFS= read -r LINE || [[ -n "$LINE" ]]; do
        LINE="$(trim $LINE)"
        if [ "$LINE" != "" ] && [ "${LINE:0:1}" != "#" ]; then
            run_command code-server --install-extension "$LINE"
        fi
    done < "$EXT_FILE"
    rm "$EXT_FILE"

#     cat <<EOT > ~/.local/share/code-server/User/settings.json
# {
#     "editor.fontFamily": "Consolas, Hack, 'Malgun Gothic', monospace",
#     "workbench.colorTheme": "Default Dark+",
#     "workbench.iconTheme": "vscode-icons",
#     "workbench.tree.indent": 16,
#     "telemetry.enableTelemetry": false,
# }
# EOT
}

################################################################################

main() {
    echo "========================================"
    echo ">>> DeunLee's Init Script (v.1.1.1)"
    echo "========================================"
    echo
    
    sudo true
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

    install_package "htop"        "" "install_htop"
    install_package "git"
    install_package "gcc"
    install_package "vim"
    install_package "zsh"
    install_oh_my_zsh
    zsh_set_default_shell
    # sudo apt install fonts-powerline
    install_package "docker"      "" "install_docker"
    install_docker_compose
    install_package "code-server" "" "install_code_server"
    install_code_server_extensions
    install_script  "neofetch"    "" "https://raw.githubusercontent.com/dylanaraps/neofetch/master/neofetch"
    echo
    
    if [ ! -e ~/docker ] && [ $(confirm "Do you want to clone deunlee/Docker-Server repository to ~/docker?" "n") = "y" ]; then
        git clone https://github.com/deunlee/Docker-Server ~/docker
    fi

    log_info "Finished!"
}

main
