#!/bin/bash

#==================================================
# Basic Settings
#==================================================
SCRIPT_VERSION="v1.0"
SCRIPT_DATE="2026.03.31"
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
# Function: Install Java 21
#==================================================
install_java_21() {
    echo -e "${YELLOW}[INFO] Checking Java version...${RESET}"

    if java -version 2>&1 | grep "21" >/dev/null; then
        echo -e "${GREEN}[OK] Java 21 already installed, skip.${RESET}"
    else
        echo -e "${YELLOW}[INFO] Java 21 not found. Removing old Java versions...${RESET}"
        dnf remove java-1.8.0-openjdk\* -y
        dnf remove java-11-openjdk\* -y
        dnf remove java-17-openjdk\* -y

        echo -e "${YELLOW}[INFO] Installing Java 21...${RESET}"
        dnf install java-21-openjdk -y || return 1

        if [[ -x /usr/lib/jvm/java-21-openjdk/bin/java ]]; then
            echo -e "${YELLOW}[INFO] Setting default Java...${RESET}"
            alternatives --set java /usr/lib/jvm/java-21-openjdk/bin/java >/dev/null 2>&1 || true
        fi
    fi

    echo -e "${BLUE}[INFO] Final Java version:${RESET}"
    java -version
}

#==================================================
# Function: Install Node.js
#==================================================
install_nodejs() {
    echo -e "${YELLOW}[INFO] Installing Node.js...${RESET}"

    pkg_install nodejs npm || return 1

    if command -v node >/dev/null 2>&1; then
        echo -e "${GREEN}[OK] Node.js installed: $(node -v)${RESET}"
    else
        echo -e "${RED}[ERROR] Node.js installation failed.${RESET}"
        return 1
    fi

    if command -v npm >/dev/null 2>&1; then
        echo -e "${BLUE}[INFO] npm version: $(npm -v)${RESET}"
    fi
}

#==================================================
# Function: Install Ruby
#==================================================
install_ruby() {
    echo -e "${YELLOW}[INFO] Installing Ruby...${RESET}"

    pkg_install ruby ruby-devel rubygems || return 1

    if command -v ruby >/dev/null 2>&1; then
        echo -e "${GREEN}[OK] Ruby installed: $(ruby -v)${RESET}"
    else
        echo -e "${RED}[ERROR] Ruby installation failed.${RESET}"
        return 1
    fi

    if command -v gem >/dev/null 2>&1; then
        echo -e "${BLUE}[INFO] gem version: $(gem -v)${RESET}"
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
| Install Java   21           1
+----------------------------------------------------------------------
| Install Nodejs xx           2
+----------------------------------------------------------------------
| Install Ruby   xx           3
+----------------------------------------------------------------------
| Install Github xx           4
+----------------------------------------------------------------------
| Exit                        5
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
        read -rp "Please Choice [1-4]: " select

        case "$select" in
            1)
                install_java_21
                pause
                ;;
            2)
                install_nodejs
                pause
                ;;
            3)
                install_ruby
                pause
                ;;
            4)
                echo -e "${GREEN}Exiting...${RESET}"
                break
                ;;
            *)
                echo -e "${RED}[ERROR] Invalid choice, please enter 1-4.${RESET}"
                pause
                ;;
        esac
    done
}

main
