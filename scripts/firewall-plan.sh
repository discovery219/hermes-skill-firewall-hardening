#!/bin/bash
# Firewall Plan / Dry-Run Script
# Shows what rules will be added/removed without applying anything.
# Run after audit-firewall.sh. Requires a security profile or explicit ports.
#
# Usage:
#   bash scripts/firewall-plan.sh --profile public-web-server
#   bash scripts/firewall-plan.sh --ports 22,80,443
#   bash scripts/firewall-plan.sh --policy-file /path/to/policy.yaml

set -euo pipefail

PROFILE=""
PORTS=""
POLICY_FILE=""
OUTPUT_MODE="text"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile) PROFILE="$2"; shift 2 ;;
        --ports) PORTS="$2"; shift 2 ;;
        --policy-file) POLICY_FILE="$2"; shift 2 ;;
        --json) OUTPUT_MODE="json"; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Detect backend
BACKEND="none"
ACTIVE_FRONTEND=""
if systemctl is-active ufw &>/dev/null; then
    BACKEND="ufw"
    ACTIVE_FRONTEND="ufw"
elif systemctl is-active firewalld &>/dev/null; then
    BACKEND="firewalld"
    ACTIVE_FRONTEND="firewalld"
elif sudo nft list ruleset 2>/dev/null | grep -q "table"; then
    BACKEND="nftables"
elif sudo iptables -L -n 2>/dev/null | grep -qv "Chain\|policy"; then
    BACKEND="iptables"
fi

# Determine target ports from profile or --ports
declare -a TARGET_PORTS=()
if [[ -n "$PROFILE" ]]; then
    case "$PROFILE" in
        public-web-server) TARGET_PORTS=(22 80 443) ;;
        bastion-host) TARGET_PORTS=(22) ;;
        internal-database) TARGET_PORTS=(22 3306) ;;
        *) echo "Unknown profile: $PROFILE"; exit 1 ;;
    esac
elif [[ -n "$PORTS" ]]; then
    IFS=',' read -ra TARGET_PORTS <<< "$PORTS"
else
    TARGET_PORTS=(22 80 443)
fi

# ---- Plan for each backend ----

plan_ufw() {
    echo "=== UFW Plan ==="
    echo "Backend: ufw (active: $(sudo ufw status 2>/dev/null | head -1))"
    echo "Default policy changes:"
    echo "  incoming: allow -> deny"
    echo "  outgoing: (unchanged: allow)"
    echo ""
    echo "Rules to be added:"
    for port in "${TARGET_PORTS[@]}"; do
        if sudo ufw status | awk '{print $1}' | grep -qx "${port}/tcp"; then
            echo "  [SKIP] ${port}/tcp (already exists)"
        else
            echo "  [ADD]  ${port}/tcp"
        fi
    done
    echo ""
    echo "Rules to be removed: (none)"
    echo ""
    echo "Dry-run validation:"
    sudo ufw --dry-run default deny incoming 2>&1 | sed 's/^/  /'
}

plan_firewalld() {
    local ZONE
    ZONE=$(sudo firewall-cmd --get-default-zone 2>/dev/null || echo "public")
    echo "=== firewalld Plan ==="
    echo "Backend: firewalld (zone: $ZONE)"
    echo ""
    echo "Rules to be added:"
    for port in "${TARGET_PORTS[@]}"; do
        if sudo firewall-cmd --zone="$ZONE" --query-port="${port}/tcp" &>/dev/null; then
            echo "  [SKIP] ${port}/tcp (already in zone $ZONE)"
        else
            echo "  [ADD]  ${port}/tcp to zone $ZONE"
        fi
    done
}

plan_nftables() {
    echo "=== nftables Plan ==="
    echo "Backend: nftables"
    echo ""
    if [[ -f /etc/nftables.conf.new ]]; then
        echo "Validating /etc/nftables.conf.new..."
        sudo nft -c -f /etc/nftables.conf.new 2>&1 | sed 's/^/  /'
    else
        echo "  Would create inet filter table with ports: ${TARGET_PORTS[*]}"
    fi
    echo ""
    echo "Atomic apply command: sudo nft -f /etc/nftables.conf.new"
}

plan_iptables() {
    echo "=== iptables Plan ==="
    echo "Backend: iptables (IPv4 + IPv6)"
    echo ""
    echo "Current INPUT rules (v4):"
    sudo iptables -L INPUT -n --line-numbers 2>/dev/null | sed 's/^/  /'
    echo ""
    echo "Rules to be added (v4):"
    for port in "${TARGET_PORTS[@]}"; do
        if sudo iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null; then
            echo "  [SKIP] tcp/${port} (already exists)"
        else
            echo "  [ADD]  tcp/${port}"
        fi
    done
}

# ---- JSON output ----
plan_json() {
    local skip_list=""
    local add_list=""
    for port in "${TARGET_PORTS[@]}"; do
        if [[ "$BACKEND" == "ufw" ]] && sudo ufw status | awk '{print $1}' | grep -qx "${port}/tcp"; then
            skip_list+=""${port}/tcp","
        else
            add_list+=""${port}/tcp","
        fi
    done
    skip_list="${skip_list%,}"
    add_list="${add_list%,}"

    cat <<EOF
{
  "backend": "$BACKEND",
  "active_frontend": "$ACTIVE_FRONTEND",
  "profile": "$PROFILE",
  "target_ports": [${TARGET_PORTS[*]// /, }],
  "changes": {
    "skip": [$skip_list],
    "add": [$add_list],
    "remove": []
  }
}
EOF
}

if [[ "$OUTPUT_MODE" == "json" ]]; then
    plan_json
else
    case "$BACKEND" in
        ufw) plan_ufw ;;
        firewalld) plan_firewalld ;;
        nftables) plan_nftables ;;
        iptables) plan_iptables ;;
        *) echo "Cannot determine firewall backend. Run audit-firewall.sh first."; exit 1 ;;
    esac
fi
