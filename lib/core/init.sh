#!/usr/bin/env bash
# lib/core/init.sh — Bootstrap sourcing for the CIS benchmark framework
# Source this file from any entry-point script to load the full framework.

set -euo pipefail

# Resolve REPO_ROOT (parent of lib/)
if [[ -z "${REPO_ROOT:-}" ]]; then
    REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi
export REPO_ROOT

# Source core libraries (order matters)
source "${REPO_ROOT}/lib/core/log.sh"
source "${REPO_ROOT}/lib/core/utils.sh"
source "${REPO_ROOT}/lib/core/config.sh"
source "${REPO_ROOT}/lib/core/prompt.sh"
source "${REPO_ROOT}/lib/core/report.sh"
source "${REPO_ROOT}/lib/core/backup.sh"
source "${REPO_ROOT}/lib/core/restore.sh"
source "${REPO_ROOT}/lib/core/connectivity.sh"

# Source distro detection + adapter
source "${REPO_ROOT}/lib/distro/detect.sh"

# Require jq
require_command jq

# Detect distro and load adapter
detect_distro

# Source all handler files
for handler_file in "${REPO_ROOT}"/lib/handlers/*.sh; do
    if [[ -f "$handler_file" ]]; then
        source "$handler_file"
    fi
done

# Source all module orchestrator files
for module_file in "${REPO_ROOT}"/lib/modules/*.sh; do
    if [[ -f "$module_file" ]]; then
        source "$module_file"
    fi
done

# Initialize logging
log_init

log_debug "Framework initialized (REPO_ROOT=$REPO_ROOT, DISTRO=${DISTRO_ID:-unknown})"
