#!/usr/bin/env bash
set -euo pipefail

#========================
# iStoreOS Image URLs
#========================
IMAGE_URL_EFI="https://fw0.koolcenter.com/iStoreOS/x86_64_efi/istoreos-24.10.5-2025123110-x86-64-squashfs-combined-efi.img.gz"
IMAGE_URL_BIOS="https://fw.d4ctech.com/iStoreOS/x86_64/istoreos-24.10.5-2025123110-x86-64-squashfs-combined.img.gz"

IMAGE_URL=""
IMAGE_FILE=""
BS="16M"

#========================
# Color Output
#========================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

err() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

#========================
# Root Check
#========================
check_root() {
    if [[ $EUID -ne 0 ]]; then
        err "请使用 root 执行此脚本。"
        exit 1
    fi
}

#========================
# Command Check
#========================
check_cmds() {
    local cmds=("lsblk" "findmnt" "readlink" "wget" "gzip" "dd" "sync" "ip" "awk" "grep" "sleep" "basename")
    local c
    for c in "${cmds[@]}"; do
        if ! command -v "$c" >/dev/null 2>&1; then
            err "缺少命令: $c"
            exit 1
        fi
    done
}

#========================
# Detect Firmware Type
#========================
detect_firmware_and_set_image() {
    if [[ -d /sys/firmware/efi ]] && [[ -f /sys/firmware/efi/fw_platform_size || -d /sys/firmware/efi/efivars ]]; then
        IMAGE_URL="$IMAGE_URL_EFI"
        log "检测到当前系统为 UEFI 启动模式，将使用 EFI 镜像。"
    else
        IMAGE_URL="$IMAGE_URL_BIOS"
        log "未检测到 UEFI，当前系统视为 BIOS/Legacy 模式，将使用非 EFI 镜像。"
    fi

    IMAGE_FILE="$(basename "$IMAGE_URL")"
    log "选用镜像: $IMAGE_FILE"
}

#========================
# CIDR -> Mask
#========================
cidr_to_mask() {
    local cidr=$1
    local mask=""
    local full_octets=$((cidr / 8))
    local partial_octet=$((cidr % 8))
    local i

    for ((i=0; i<4; i++)); do
        if (( i < full_octets )); then
            mask+="255"
        elif (( i == full_octets && partial_octet > 0 )); then
            mask+="$((256 - 2**(8 - partial_octet)))"
        else
            mask+="0"
        fi

        if (( i < 3 )); then
            mask+="."
        fi
    done

    echo "$mask"
}

#========================
# Show Current Network Info
#========================
show_network_info() {
    local default_if gateway ip_cidr ip_addr subnet_mask cidr

    default_if="$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')"
    gateway="$(ip route show default 2>/dev/null | awk '/default/ {print $3; exit}')"

    if [[ -n "${default_if:-}" ]]; then
        ip_cidr="$(ip -4 -o addr show dev "$default_if" scope global 2>/dev/null | awk '{print $4; exit}')"
    else
        ip_cidr=""
    fi

    ip_addr=""
    cidr=""
    subnet_mask=""

    if [[ -n "${ip_cidr:-}" ]]; then
        ip_addr="${ip_cidr%/*}"
        cidr="${ip_cidr#*/}"
        subnet_mask="$(cidr_to_mask "$cidr")"
    fi

    echo
    echo -e "${BLUE}========== 当前网络信息 ==========${NC}"
    echo "默认网卡   : ${default_if:-未检测到}"
    echo "当前 IP    : ${ip_addr:-未检测到}"
    echo "子网掩码   : ${subnet_mask:-未检测到}"
    echo "CIDR       : ${cidr:-未检测到}"
    echo "默认网关   : ${gateway:-未检测到}"
    echo -e "${BLUE}=================================${NC}"
    echo
}

#========================
# Confirm Network Info
#========================
confirm_network_info() {
    show_network_info
    read -rp "请确认以上 IP / 子网 / 网关是否正确，输入 Y 继续: " answer

    if [[ "$answer" != "Y" && "$answer" != "y" ]]; then
        warn "用户取消操作。"
        exit 0
    fi
}

#========================
# Show Disk Info
#========================
show_disks() {
    echo
    echo -e "${BLUE}========== 当前磁盘信息 ==========${NC}"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL
    echo -e "${BLUE}=================================${NC}"
    echo
}

#========================
# Get Top-level Disk
#========================
get_parent_disk() {
    local dev="$1"
    local current name pk

    current="$(readlink -f "$dev")"
    name="$(basename "$current")"

    while true; do
        pk="$(lsblk -ndo PKNAME "/dev/$name" 2>/dev/null || true)"
        if [[ -z "$pk" ]]; then
            echo "/dev/$name"
            return 0
        fi
        name="$pk"
    done
}

#========================
# Detect Boot Disk
#========================
detect_boot_disk() {
    local mountpoint src disk

    for mountpoint in /boot/efi /boot /; do
        if findmnt -rn -o SOURCE "$mountpoint" >/dev/null 2>&1; then
            src="$(findmnt -rn -o SOURCE "$mountpoint")"
            [[ -n "$src" ]] || continue

            if [[ "$src" == /dev/* ]]; then
                disk="$(get_parent_disk "$src")"
                if [[ -b "$disk" ]]; then
                    echo "$disk"
                    return 0
                fi
            fi
        fi
    done

    return 1
}

#========================
# Get Target Disk
#========================
get_target_disk() {
    local target="${1:-}"

    if [[ -n "$target" ]]; then
        if [[ ! -b "$target" ]]; then
            err "你指定的目标盘不存在: $target"
            exit 1
        fi
        echo "$target"
        return 0
    fi

    if target="$(detect_boot_disk)"; then
        echo "$target"
        return 0
    fi

    return 1
}

#========================
# Download Image
#========================
download_image() {
    if [[ -f "$IMAGE_FILE" ]]; then
        warn "检测到镜像文件已存在: $IMAGE_FILE"
        log "校验已有镜像完整性..."

        local out rc
        rc=0
        out="$(gzip -t "$IMAGE_FILE" 2>&1)" || rc=$?

        if [[ "$rc" -eq 0 ]]; then
            log "镜像文件完整，跳过下载。"
            ls -lh "$IMAGE_FILE"
            return 0
        fi

        echo "$out"

        if echo "$out" | grep -qi "trailing garbage ignored"; then
            warn "检测到 trailing garbage ignored，主体镜像可用，跳过重新下载。"
            ls -lh "$IMAGE_FILE"
            return 0
        fi

        warn "已有镜像损坏，删除后重新下载..."
        rm -f "$IMAGE_FILE"
    fi

    log "开始下载镜像..."
    wget -c -O "$IMAGE_FILE" "$IMAGE_URL"

    log "下载完成:"
    ls -lh "$IMAGE_FILE"
}

#========================
# Verify Image
#========================
verify_image() {
    log "校验 gzip 文件完整性..."

    local out rc
    rc=0
    out="$(gzip -t "$IMAGE_FILE" 2>&1)" || rc=$?

    if [[ "$rc" -eq 0 ]]; then
        log "gzip 校验通过。"
        return 0
    fi

    echo "$out"

    if echo "$out" | grep -qi "trailing garbage ignored"; then
        warn "检测到 trailing garbage ignored，主体镜像可用，允许继续。"
        return 0
    fi

    err "gzip 校验失败。"
    exit 1
}

#========================
# Write Image
#========================
write_image() {
    local disk="$1"

    warn "即将自动把镜像写入: $disk"
    warn "该磁盘上的数据将被清空"
    sleep 3

    log "开始写入镜像到 $disk ..."

    rm -f /tmp/istoreos_gzip.err

    set +e
    gzip -dc "$IMAGE_FILE" 2>/tmp/istoreos_gzip.err | dd of="$disk" bs="$BS" status=progress conv=fsync
    local rc=$?
    set -e

    if [[ "$rc" -ne 0 ]]; then
        if grep -qi "trailing garbage ignored" /tmp/istoreos_gzip.err 2>/dev/null; then
            warn "检测到 trailing garbage ignored，按可接受警告处理。"
        else
            err "镜像写入失败。"
            cat /tmp/istoreos_gzip.err 2>/dev/null || true
            exit 1
        fi
    fi

    log "镜像写入完成。"
    log "执行 sync ..."
    sync
    sleep 3
}

#========================
# Reboot
#========================
do_reboot() {
    log "准备重启系统..."

    if command -v systemctl >/dev/null 2>&1; then
        log "尝试 systemctl reboot ..."
        systemctl reboot || true
        sleep 5
    fi

    log "尝试 reboot ..."
    reboot || true
    sleep 5

    warn "普通重启未生效，尝试强制重启 ..."
    echo 1 > /proc/sys/kernel/sysrq || true
    echo b > /proc/sysrq-trigger || true
}

#========================
# Main
#========================
main() {
    check_root
    check_cmds
    detect_firmware_and_set_image
    confirm_network_info
    show_disks

    local target_disk
    if ! target_disk="$(get_target_disk "${1:-}")"; then
        err "无法自动检测系统启动盘。"
        err "请手动指定目标盘，例如: ./install_iStoreOS.sh /dev/sda"
        exit 1
    fi

    log "检测到目标磁盘: $target_disk"

    download_image
    verify_image
    write_image "$target_disk"
    do_reboot
}

main "$@"