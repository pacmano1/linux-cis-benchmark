#!/usr/bin/env bash
# scripts/install-prerequisites.sh — Install required packages for CIS benchmark
# Usage: sudo ./scripts/install-prerequisites.sh [OPTIONS]
#
# Options:
#   --force           Skip all interactive prompts
#   --help            Show this help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

FORCE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force) FORCE=true; shift ;;
        --help|-h) head -10 "${BASH_SOURCE[0]}" | tail -6; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# Minimal bootstrap (can't use full init.sh yet — may not have jq)
source "${REPO_ROOT}/lib/core/log.sh"
LOG_LEVEL="INFO"
log_init

echo ""
echo "  CIS Linux Benchmark — Prerequisites Installer"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Detect distro
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    DETECTED_ID="${ID:-}"
    DETECTED_VERSION="${VERSION_ID:-}"
else
    log_error "Cannot detect distro (/etc/os-release not found)"
    exit 1
fi

log_info "Detected: ${DETECTED_ID} ${DETECTED_VERSION}"

# Check root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (or with sudo)"
    exit 1
fi

# Define required packages per distro
case "${DETECTED_ID}" in
    rhel|centos|almalinux|rocky|ol)
        PACKAGES=(jq aide audit)
        INSTALL_CMD="dnf install -y"
        ;;
    ubuntu|debian)
        PACKAGES=(jq aide auditd)
        INSTALL_CMD="DEBIAN_FRONTEND=noninteractive apt-get install -y"
        ;;
    *)
        log_error "Unsupported distro: ${DETECTED_ID}"
        exit 1
        ;;
esac

# Check what's already installed
TO_INSTALL=()
for pkg in "${PACKAGES[@]}"; do
    case "${DETECTED_ID}" in
        rhel|centos|almalinux|rocky|ol)
            if ! rpm -q "$pkg" &>/dev/null; then
                TO_INSTALL+=("$pkg")
            else
                log_info "Already installed: $pkg"
            fi
            ;;
        ubuntu|debian)
            if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
                TO_INSTALL+=("$pkg")
            else
                log_info "Already installed: $pkg"
            fi
            ;;
    esac
done

if [[ ${#TO_INSTALL[@]} -eq 0 ]]; then
    log_info "All prerequisites are already installed."
    exit 0
fi

log_info "Packages to install: ${TO_INSTALL[*]}"

if [[ "$FORCE" != true ]]; then
    printf '  ? Install %d package(s)? [Y/n]: ' "${#TO_INSTALL[@]}"
    read -r REPLY
    REPLY="${REPLY:-y}"
    if [[ "${REPLY,,}" != "y" ]]; then
        log_info "Installation cancelled."
        exit 0
    fi
fi

# Install
log_info "Installing packages..."
eval "$INSTALL_CMD ${TO_INSTALL[*]}"

log_info "Prerequisites installed successfully."
