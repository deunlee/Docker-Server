#!/usr/bin/env bash

SCRIPT_DIR="$(dirname $(readlink -f $0))"

NC="\033[0m"
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
        echo -en "${LCYAN}[CHECK]${NC} " 1>&2
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

trim() { # https://stackoverflow.com/questions/369758/how-to-trim-whitespace-from-a-bash-variable
    local var="$*"
    # Remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # Remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"   
    printf '%s' "$var"
}

function_exists() { # https://stackoverflow.com/questions/85880/determine-if-a-function-exists-in-bash
    declare -f -F $1 > /dev/null
    return $?
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
    echo -en "$DGRAY"
    $@
    RET=$?
    echo -en "$NC"
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

get_version() {
    $1 --version | head -n 1
}

install() {
    sudo true

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
    name="$1"
    dname="${2:-$name}" # display name
    is_recommend="${3:-y}"

    # Functions can be overridden.
    func_check="${name}_check"
    func_install="${name}_install"
    func_version="${name}_version"
    function_exists "$func_check"   || func_check="check"
    function_exists "$func_install" || func_install="install"
    function_exists "$func_version" || func_version="get_version"

    T="Installed"
    if $func_check "$name"; then
        T="Already installed"
    elif [ $(confirm "Do you want to install $dname?" "$is_recommend") = "y" ]; then
        $func_install "$name"
        if [ $? -ne 0 ]; then
            log_error "NOT installed: $dname"
            return 1
        fi
    else
        return 0 # user pressed "n"
    fi
    
    log_info "$T: $dname ${DGRAY}($($func_version $name))${NC}"
    if [ "$T" = "Installed" ]; then echo ; fi
}

install_script() { # install(download) a script (/usr/local/bin)
    name="$1"
    download_url="$2"
    is_recommend="${3:-y}"

    script_path="/usr/local/bin/$name"

    T="Installed"
    if [ -e "$script_path" ] ; then
        T="Already installed"
    elif [ $(confirm "Do you want to install $name script?" "$is_recommend") = "y" ]; then
        run_command sudo curl -o "$script_path" -fsSL "$download_url"
        if [ $? -ne 0 ]; then
            log_error "NOT installed: $name"
            return 1
        fi
        sudo chmod +x "$script_path"
    else
        return 0 # user pressed "n"
    fi
    
    log_info "$T: $name"
    if [ "$T" = "Installed" ]; then echo ; fi
}

################################################################################

htop_install() {
    case $(get_distribution) in
        centos) install epel-release; install htop ;;
        *)      install htop ;;
    esac
}

################################################################################

omz_check()   { [ -e ~/.oh-my-zsh ]; }
omz_version() { git --git-dir ~/.oh-my-zsh/.git --no-pager log -1 --format="%ai"; }
omz_install() {
    check zsh || return 1 # zsh is not installed

    # https://github.com/ohmyzsh/ohmyzsh
    echo -en "$DGRAY"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" --skip-chsh --unattended | cat
    if [ $? -ne 0 ]; then return 1; fi

    run_command git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
    log_info "Plugin is installed: zsh-syntax-highlighting"

    run_command git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    log_info "Plugin is installed: zsh-autosuggestions"
    echo

    sed -i 's/ZSH_THEME="[A-Za-z]*"/ZSH_THEME="agnoster"/' ~/.zshrc
    sed -i 's/plugins=([A-Za-z]*)/plugins=(git zsh-syntax-highlighting zsh-autosuggestions)/' ~/.zshrc
    # source ~/.zshrc
}

zsh_set_default_shell() {
    check zsh || return 1 # zsh is not installed

    if [ "$SHELL" != "/bin/zsh" ] && [ "$SHELL" != "/usr/bin/zsh" ]; then
        if [ $(confirm "Do you want to change default shell to zsh?" "y") = "y" ]; then
            # sudo chsh -s $(which zsh)
            if [ -e /bin/zsh ]; then
                run_command sudo usermod --shell /bin/zsh $USER
            else
                run_command sudo usermod --shell $(which zsh) $USER
            fi
            log_info "The default shell changed to zsh."
            log_info "This setting will not take effect until you log in again."
        fi
        echo
    fi
}

################################################################################

docker_install() {
    echo -en "$DGRAY"
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

DOCKER_COMPOSE_VERSION="2.2.2"
compose_check()   { [ -e ~/.docker/cli-plugins ]; }
compose_version() { docker compose version; }
compose_install() {
    check docker || return 1 # docker is not installed

    # https://github.com/docker/compose/releases
    mkdir -p ~/.docker/cli-plugins/
    URL="https://github.com/docker/compose/releases/download/v$DOCKER_COMPOSE_VERSION/docker-compose-linux-$(uname -m)"
    SAVE=~/.docker/cli-plugins/docker-compose
    run_command curl -SL "$URL" -o "$SAVE"
    if [ $? -ne 0 ]; then return 1; fi
    chmod +x "$SAVE"
}

################################################################################

code_check()   { check code-server; }
code_version() { get_version code-server; }
code_install() {
    CONFIG_FILE=~/.config/code-server/config.yaml

    echo -en "$DGRAY"
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

    code_install_extensions
}

code_install_extensions() {
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
            if [ $? -eq 0 ]; then
                log_info "The extension is installed: $LINE"
            else
                log_error "The extension is NOT installed: $LINE"
            fi
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
    echo ">>> DeunLee's Init Script (v.1.3.0)"
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

    install_package "htop"
    install_package "git"
    install_package "gcc"
    install_package "vim"
    install_package "zsh"
    install_package "omz"     "oh-my-zsh"
    zsh_set_default_shell
    # sudo apt install fonts-powerline
    install_package "docker"
    install_package "compose" "docker-compose"
    install_package "code"    "code-server"


    install_script  "neofetch"                 "https://raw.githubusercontent.com/dylanaraps/neofetch/master/neofetch"
    install_script  "spectre-meltdown-checker" "https://raw.githubusercontent.com/speed47/spectre-meltdown-checker/master/spectre-meltdown-checker.sh"
    echo
    
    if [ ! -e ~/docker ] && [ $(confirm "Do you want to clone deunlee/Docker-Server repository to ~/docker?" "n") = "y" ]; then
        run_command git clone https://github.com/deunlee/Docker-Server ~/docker
    fi

    log_info "Finished!"
}

main
