#!/bin/bash

#==================================================
# Basic Settings
#==================================================
SCRIPT_VERSION="v1.4"
SCRIPT_DATE="2025.03.27"
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
        echo -e "${RED}[ERROR] 请使用 root 身份执行此脚本。${RESET}"
        exit 1
    fi
}

#==================================================
# Function: Pause
#==================================================
pause() {
    read -rp "按 Enter 键继续..."
}

#==================================================
# Function: Check DNF
#==================================================
check_dnf() {
    if ! command -v dnf >/dev/null 2>&1; then
        echo -e "${RED}[ERROR] 当前系统没有 dnf，无法执行安装。${RESET}"
        exit 1
    fi
}

#==================================================
# Function: Disable SELinux
#==================================================
disable_selinux() {
    echo -e "${YELLOW}[INFO] 正在检查 SELinux 状态...${RESET}"

    local current_selinux="Unknown"

    if command -v getenforce >/dev/null 2>&1; then
        current_selinux=$(getenforce 2>/dev/null)
    fi

    echo -e "${BLUE}[INFO] 当前 SELinux 状态: ${current_selinux}${RESET}"

    if [[ "$current_selinux" == "Enforcing" ]]; then
        setenforce 0 2>/dev/null
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}[OK] 已临时关闭 SELinux。${RESET}"
        else
            echo -e "${RED}[ERROR] 临时关闭 SELinux 失败。${RESET}"
        fi
    fi

    if [[ -f /etc/selinux/config ]]; then
        if grep -q '^SELINUX=enforcing' /etc/selinux/config; then
            sed -i 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
            echo -e "${GREEN}[OK] 已修改 /etc/selinux/config 为 disabled。${RESET}"
            echo -e "${YELLOW}[INFO] 重启后永久生效。${RESET}"
        elif grep -q '^SELINUX=permissive' /etc/selinux/config; then
            sed -i 's/^SELINUX=permissive/SELINUX=disabled/' /etc/selinux/config
            echo -e "${GREEN}[OK] 已修改 /etc/selinux/config 为 disabled。${RESET}"
            echo -e "${YELLOW}[INFO] 重启后永久生效。${RESET}"
        else
            echo -e "${BLUE}[INFO] /etc/selinux/config 已经是 disabled 或无需修改。${RESET}"
        fi
    else
        echo -e "${RED}[ERROR] 找不到 /etc/selinux/config。${RESET}"
    fi
}

#==================================================
# Function: Get current Node.js major version
# return:
#   echo major version if node exists
#   echo empty if not exists
#==================================================
get_node_major_version() {
    if command -v node >/dev/null 2>&1; then
        node -v 2>/dev/null | sed -E 's/^v([0-9]+).*/\1/'
    else
        echo ""
    fi
}

#==================================================
# Function: Show current Node.js info
#==================================================
show_node_info() {
    if command -v node >/dev/null 2>&1; then
        echo -e "${BLUE}[INFO] Node.js 版本: $(node -v)${RESET}"
    else
        echo -e "${BLUE}[INFO] Node.js: 未安装${RESET}"
    fi

    if command -v npm >/dev/null 2>&1; then
        echo -e "${BLUE}[INFO] npm 版本: $(npm -v)${RESET}"
    else
        echo -e "${BLUE}[INFO] npm: 未安装${RESET}"
    fi
}

#==================================================
# Function: Install required Node.js major version
# usage:
#   ensure_nodejs_version 20
#   ensure_nodejs_version 22
#==================================================
ensure_nodejs_version() {
    local required_major="$1"
    local current_major=""

    if [[ -z "$required_major" ]]; then
        echo -e "${RED}[ERROR] 未指定所需 Node.js 主版本。${RESET}"
        return 1
    fi

    check_dnf

    echo -e "${YELLOW}[INFO] 开始检查 Node.js 环境，目标版本: ${required_major}.x${RESET}"
    show_node_info

    current_major=$(get_node_major_version)

    if [[ -n "$current_major" && "$current_major" == "$required_major" ]]; then
        echo -e "${GREEN}[OK] 已检测到 Node.js ${required_major}.x，跳过安装。${RESET}"

        if command -v npm >/dev/null 2>&1; then
            return 0
        else
            echo -e "${YELLOW}[WARN] node 存在，但 npm 未找到，准备重新安装 Node.js ${required_major}.x${RESET}"
        fi
    fi

    echo -e "${YELLOW}[INFO] 当前 Node.js 不符合需求，开始安装 Node.js ${required_major}.x ...${RESET}"

    echo -e "${YELLOW}[INFO] 重置 Node.js 模块...${RESET}"
    dnf module reset nodejs -y
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}[ERROR] Node.js 模块重置失败。${RESET}"
        return 1
    fi

    echo -e "${YELLOW}[INFO] 启用 Node.js ${required_major} 模块...${RESET}"
    dnf module enable "nodejs:${required_major}" -y
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}[ERROR] 启用 Node.js ${required_major} 模块失败。${RESET}"
        echo -e "${YELLOW}[WARN] 请先手动执行: dnf module list nodejs${RESET}"
        return 1
    fi

    echo -e "${YELLOW}[INFO] 安装 Node.js ${required_major} ...${RESET}"
    dnf install nodejs -y
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}[ERROR] Node.js ${required_major} 安装失败。${RESET}"
        return 1
    fi

    local new_major
    new_major=$(get_node_major_version)

    if [[ "$new_major" != "$required_major" ]]; then
        echo -e "${RED}[ERROR] 安装后检测到的 Node.js 版本不是 ${required_major}.x${RESET}"
        show_node_info
        return 1
    fi

    if ! command -v npm >/dev/null 2>&1; then
        echo -e "${RED}[ERROR] npm 未正确安装。${RESET}"
        return 1
    fi

    echo -e "${GREEN}[OK] Node.js ${required_major}.x 安装完成。${RESET}"
    show_node_info
    return 0
}

#==================================================
# Function: Install Gemini CLI
#==================================================
install_gemini_cli() {
    echo -e "${YELLOW}[INFO] 开始安装 Gemini CLI...${RESET}"

    ensure_nodejs_version 20 || return 1

    npm install -g @google/gemini-cli
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}[ERROR] Gemini CLI 安装失败。${RESET}"
        return 1
    fi

    if command -v gemini >/dev/null 2>&1; then
        echo -e "${GREEN}[OK] Gemini CLI 安装成功。${RESET}"
        gemini --version 2>/dev/null || true
    else
        echo -e "${YELLOW}[WARN] 已执行安装，但未找到 gemini 指令。请重新登录 shell 或检查 npm 全局 PATH。${RESET}"
    fi
}

#==================================================
# Function: Install Copilot CLI
#==================================================
install_copilot_cli() {
    echo -e "${YELLOW}[INFO] 开始安装 GitHub Copilot CLI...${RESET}"

    ensure_nodejs_version 22 || return 1

    npm install -g @github/copilot
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}[ERROR] GitHub Copilot CLI 安装失败。${RESET}"
        return 1
    fi

    if command -v copilot >/dev/null 2>&1; then
        echo -e "${GREEN}[OK] GitHub Copilot CLI 安装成功。${RESET}"
        copilot --version 2>/dev/null || true
    else
        echo -e "${YELLOW}[WARN] 已执行安装，但未找到 copilot 指令。请重新登录 shell 或检查 npm 全局 PATH。${RESET}"
    fi
}

#==================================================
# Function: Install Codex CLI
#==================================================
install_codex_cli() {
    echo -e "${YELLOW}[INFO] 开始安装 OpenAI Codex CLI...${RESET}"

    ensure_nodejs_version 20 || return 1

    npm install -g @openai/codex
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}[ERROR] OpenAI Codex CLI 安装失败。${RESET}"
        return 1
    fi

    if command -v codex >/dev/null 2>&1; then
        echo -e "${GREEN}[OK] OpenAI Codex CLI 安装成功。${RESET}"
        codex --version 2>/dev/null || true
    else
        echo -e "${YELLOW}[WARN] 已执行安装，但未找到 codex 指令。请重新登录 shell 或检查 npm 全局 PATH。${RESET}"
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
| Install Agent Gemini Cli   1
+----------------------------------------------------------------------
| Install Agent Copilot Cli  2
+----------------------------------------------------------------------
| Install Agent Codex Cli    3
+----------------------------------------------------------------------
| Disable SELinux            4
+----------------------------------------------------------------------
| Exit                       5
+----------------------------------------------------------------------
${RESET}"
}

#==================================================
# Main
#==================================================
main() {
    check_root

    while true
    do
        show_menu
        read -rp "Please Choice [1-5]: " select

        case "$select" in
            1)
                install_gemini_cli
                pause
                ;;
            2)
                install_copilot_cli
                pause
                ;;
            3)
                install_codex_cli
                pause
                ;;
            4)
                disable_selinux
                pause
                ;;
            5)
                echo -e "${GREEN}Exiting...${RESET}"
                break
                ;;
            *)
                echo -e "${RED}[ERROR] 无效选项，请输入 1-5。${RESET}"
                pause
                ;;
        esac
    done
}

main