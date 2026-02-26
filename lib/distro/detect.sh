#!/usr/bin/env bash
# lib/distro/detect.sh — Auto-detect distro from /etc/os-release

# Detect the Linux distribution and source the appropriate adapter
detect_distro() {
    local os_release="/etc/os-release"

    if [[ ! -f "$os_release" ]]; then
        log_warn "Cannot detect distro: /etc/os-release not found"
        DISTRO_ID="unknown"
        DISTRO_LABEL="Unknown Linux"
        return 1
    fi

    local id version_id
    id="$(. "$os_release" && echo "${ID:-}")"
    version_id="$(. "$os_release" && echo "${VERSION_ID:-}")"

    log_debug "Detected OS: ID=$id VERSION_ID=$version_id"

    case "${id}" in
        rhel|centos|almalinux|rocky|ol)
            local major="${version_id%%.*}"
            case "$major" in
                9)
                    DISTRO_ID="rhel9"
                    _load_distro_adapter "rhel9"
                    ;;
                *)
                    log_warn "Unsupported RHEL-family version: $version_id (only 9.x supported)"
                    DISTRO_ID="rhel${major}"
                    DISTRO_LABEL="RHEL-family ${version_id}"
                    return 1
                    ;;
            esac
            ;;
        ubuntu)
            case "$version_id" in
                24.04)
                    DISTRO_ID="ubuntu2404"
                    _load_distro_adapter "ubuntu2404"
                    ;;
                *)
                    log_warn "Unsupported Ubuntu version: $version_id (only 24.04 supported)"
                    DISTRO_ID="ubuntu${version_id//./}"
                    DISTRO_LABEL="Ubuntu ${version_id}"
                    return 1
                    ;;
            esac
            ;;
        *)
            log_warn "Unsupported distribution: $id $version_id"
            DISTRO_ID="$id"
            DISTRO_LABEL="$id $version_id"
            return 1
            ;;
    esac

    export DISTRO_ID
    export DISTRO_LABEL
    log_info "Distribution: ${DISTRO_LABEL} (${DISTRO_ID})"
    return 0
}

# Load a distro adapter file
_load_distro_adapter() {
    local adapter_id="$1"
    local adapter_file="${REPO_ROOT}/lib/distro/${adapter_id}.sh"
    if [[ -f "$adapter_file" ]]; then
        source "$adapter_file"
        log_debug "Loaded distro adapter: $adapter_file"
    else
        log_warn "Distro adapter not found: $adapter_file"
    fi
}
