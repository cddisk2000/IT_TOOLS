#!/bin/bash

#==================================================
# Basic Settings
#==================================================
SCRIPT_VERSION="v1.0"
SCRIPT_DATE="2026.03.30"
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
# Function: Install package
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
# Function: Install Python 3.11
#==================================================
install_python_311() {
    echo -e "${YELLOW}[INFO] Installing Python 3.11...${RESET}"

    pkg_install python3.11 python3.11-pip python3.11-devel gcc openssl-devel bzip2-devel libffi-devel zlib-devel
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}[ERROR] Python 3.11 installation failed.${RESET}"
        return 1
    fi

    if [[ -x /usr/bin/python3.11 ]]; then
        alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 311 >/dev/null 2>&1 || true
        alternatives --set python3 /usr/bin/python3.11 >/dev/null 2>&1 || true
        ln -sf /usr/bin/python3.11 /usr/bin/python
    fi

    echo -e "${GREEN}[OK] Python 3.11 installation completed.${RESET}"

    if command -v python3.11 >/dev/null 2>&1; then
        echo -e "${BLUE}[INFO] python3.11 version: $(python3.11 --version 2>/dev/null)${RESET}"
    fi

    if command -v pip3.11 >/dev/null 2>&1; then
        echo -e "${BLUE}[INFO] pip3.11 version: $(pip3.11 --version 2>/dev/null)${RESET}"
    fi
}

#==================================================
# Function: Install Python 3.12
#==================================================
install_python_312() {
    echo -e "${YELLOW}[INFO] Installing Python 3.12...${RESET}"

    pkg_install python3.12 python3.12-pip python3.12-devel gcc openssl-devel bzip2-devel libffi-devel zlib-devel
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}[ERROR] Python 3.12 installation failed.${RESET}"
        return 1
    fi

    if [[ -x /usr/bin/python3.12 ]]; then
        alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 312 >/dev/null 2>&1 || true
        alternatives --set python3 /usr/bin/python3.12 >/dev/null 2>&1 || true
        ln -sf /usr/bin/python3.12 /usr/bin/python
    fi

    echo -e "${GREEN}[OK] Python 3.12 installation completed.${RESET}"

    if command -v python3.12 >/dev/null 2>&1; then
        echo -e "${BLUE}[INFO] python3.12 version: $(python3.12 --version 2>/dev/null)${RESET}"
    fi

    if command -v pip3.12 >/dev/null 2>&1; then
        echo -e "${BLUE}[INFO] pip3.12 version: $(pip3.12 --version 2>/dev/null)${RESET}"
    fi
}

#==================================================
# Function: Install Python 3.13
#==================================================
install_python_313() {
    echo -e "${YELLOW}[INFO] Installing Python 3.13...${RESET}"

    pkg_install python3.13 python3.13-pip python3.13-devel gcc openssl-devel bzip2-devel libffi-devel zlib-devel
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}[ERROR] Python 3.13 installation failed.${RESET}"
        return 1
    fi

    if [[ -x /usr/bin/python3.13 ]]; then
        alternatives --install /usr/bin/python3 python3 /usr/bin/python3.13 313 >/dev/null 2>&1 || true
        alternatives --set python3 /usr/bin/python3.13 >/dev/null 2>&1 || true
        ln -sf /usr/bin/python3.13 /usr/bin/python
    fi

    echo -e "${GREEN}[OK] Python 3.13 installation completed.${RESET}"

    if command -v python3.13 >/dev/null 2>&1; then
        echo -e "${BLUE}[INFO] python3.13 version: $(python3.13 --version 2>/dev/null)${RESET}"
    fi

    if command -v pip3.13 >/dev/null 2>&1; then
        echo -e "${BLUE}[INFO] pip3.13 version: $(pip3.13 --version 2>/dev/null)${RESET}"
    fi
}

#==================================================
# Function: Modify pip Repository (CN)
#==================================================
modify_pip_repository_cn() {
    echo -e "${YELLOW}[INFO] Configuring pip mirror to Aliyun...${RESET}"

    mkdir -p ~/.pip
    cat > ~/.pip/pip.conf <<'EOF'
[global]
index-url = https://mirrors.aliyun.com/pypi/simple/
[install]
trusted-host = mirrors.aliyun.com
EOF

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}[OK] ~/.pip/pip.conf updated.${RESET}"
    else
        echo -e "${RED}[ERROR] Failed to update ~/.pip/pip.conf.${RESET}"
        return 1
    fi
}

#==================================================
# Function: Disable SELinux
#==================================================
disable_selinux() {
    echo -e "${YELLOW}[INFO] Checking SELinux status...${RESET}"

    local current_selinux="Unknown"

    if command -v getenforce >/dev/null 2>&1; then
        current_selinux=$(getenforce 2>/dev/null)
    fi

    echo -e "${BLUE}[INFO] Current SELinux status: ${current_selinux}${RESET}"

    if [[ "$current_selinux" == "Enforcing" ]]; then
        setenforce 0 2>/dev/null
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}[OK] SELinux has been set to permissive temporarily.${RESET}"
        else
            echo -e "${RED}[ERROR] Failed to set SELinux to permissive temporarily.${RESET}"
        fi
    fi

    if [[ -f /etc/selinux/config ]]; then
        if grep -Eq '^SELINUX=(enforcing|permissive)' /etc/selinux/config; then
            sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
            echo -e "${GREEN}[OK] /etc/selinux/config updated to disabled.${RESET}"
            echo -e "${YELLOW}[INFO] Reboot is required for the permanent change to take effect.${RESET}"
        else
            echo -e "${BLUE}[INFO] /etc/selinux/config is already disabled or does not require changes.${RESET}"
        fi
    else
        echo -e "${RED}[ERROR] /etc/selinux/config not found.${RESET}"
    fi
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
| Install Python 3.11         1
+----------------------------------------------------------------------
| Install Python 3.12         2
+----------------------------------------------------------------------
| Install Python 3.xx         3
+----------------------------------------------------------------------
| Modify  pip Repository (CN) 4
+----------------------------------------------------------------------
| Disable SELinux             5
+----------------------------------------------------------------------
| Exit                        6
+----------------------------------------------------------------------
| how pip install Refer to the following instructions
| pip3.XX install requests
+----------------------------------------------------------------------
${RESET}"
}

#==================================================
# Main
#==================================================
main() {
    check_root
    check_pkg_manager

    while true
    do
        show_menu
        read -rp "Please Choice [1-6]: " select

        case "$select" in
            1)
                install_python_311
                pause
                ;;
            2)
                install_python_312
                pause
                ;;
            3)
                echo -e "${YELLOW}[INFO] Option 3 is reserved for future Python 3.xx installation.${RESET}"
                pause
                ;;
            4)
                modify_pip_repository_cn
                pause
                ;;
            5)
                disable_selinux
                pause
                ;;
            6)
                echo -e "${GREEN}Exiting...${RESET}"
                break
                ;;
            *)
                echo -e "${RED}[ERROR] Invalid option. Please enter 1-6.${RESET}"
                pause
                ;;
        esac
    done
}

main
