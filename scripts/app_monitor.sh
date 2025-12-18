#!/bin/bash
# Application Service Monitor - Best combined version
# Monitors postgresql, flask-demo, nginx stack with alerting

# ---------------- CONFIG ----------------
SERVICES=("postgresql" "flask-demo" "nginx")

#see if verbose output of retries
VERBOSE=${VERBOSE:-1}   # default to on

# Thresholds (make these configurable via env vars if needed)
CPU_THRESHOLD=${CPU_THRESHOLD:-80}          # % CPU
MEMORY_THRESHOLD=${MEMORY_THRESHOLD:-80}    # % Memory
ERROR_THRESHOLD=${ERROR_THRESHOLD:-10}      # Errors in last hour

# Alert repeat interval in seconds (default 1 hour to avoid storms)
ALERT_REPEAT_SECONDS=${ALERT_REPEAT_SECONDS:-3}

# Health endpoint for flask-demo
FLASK_HEALTH_URL="http://localhost:5000/health"

# ---------------- ALERTING ----------------
send_slack_alert() {
    local message="$1"
    [[ -z "${SLACK_WEBHOOK_URL:-}" ]] && return

    curl -s -X POST -H 'Content-type: application/json' \
        --data "{\"text\": \"🚨 SERVICE ALERT\n$message\"}" \
        "$SLACK_WEBHOOK_URL" >/dev/null
}

alert_once() {
    local key="$1"       # Unique alert identifier (e.g., "flask-demo-cpu")
    local message="$2"
    local alert_file="/tmp/${key}.alerted"

    if [[ -f "$alert_file" ]]; then
        local last=$(stat -c %Y "$alert_file" 2>/dev/null || echo 0)
        local now=$(date +%s)
        local age=$((now - last))
        (( age < ALERT_REPEAT_SECONDS )) && return
    fi

    send_slack_alert "$message"
    touch "$alert_file"
}

clear_alert() {
    local key="$1"
    rm -f "/tmp/${key}.alerted" 2>/dev/null
}

# ---------------- UTILITIES ----------------
retry_command() {
    local max_attempts=3 attempt=1 wait_time=2
    while (( attempt <= max_attempts )); do
        if "$@" >/dev/null 2>&1; then
            return 0
        fi
        # print retry lines when VERBOSE is set
        if [[ "${VERBOSE:-}" == "1" ]]; then
            echo "  [Retry attempt $attempt/$max_attempts failed]" >&2
            (( attempt < max_attempts )) && echo "  [Waiting ${wait_time}s before retry...]" >&2
        fi
        (( attempt < max_attempts )) && sleep "$wait_time"
        ((attempt++))
    done
    return 1
}

# ---------------- CHECKS ----------------
check_service_status() {
    local service="$1"

    if retry_command systemctl is-active "$service"; then
        # Service recovered → clear all related alerts
        clear_alert "$service"
        clear_alert "${service}-cpu"
        clear_alert "${service}-memory"
        clear_alert "${service}-errors"
        clear_alert "${service}-health"

        echo -e "\e[32m✓ $service is running\e[0m"
        return 0
    else
        echo -e "\e[31m✗ $service is NOT running\e[0m"
        alert_once "$service" \
"Service: $service
Host: $(hostname)
State: 🔥 FIRE IN THE BUILDING
Time: $(date)
Next step: systemctl status $service 🔭"
    return 1
    fi
}

get_service_details() {
    local service="$1"
    local pid uptime
    pid=$(systemctl show "$service" -p MainPID --value)
    uptime=$(systemctl show "$service" -p ActiveEnterTimestamp --value)

    echo "  PID: $pid"
    echo "  Started: $uptime"
}

check_health_endpoint() {
    local service="$1"
    local url="$2"

    if retry_command curl -sf -m 5 "$url"; then
        echo -e "  Health: \e[32m✓ Endpoint responding\e[0m"
        clear_alert "${service}-health"
    else
        echo -e "  Health: \e[31m✗ Endpoint not responding\e[0m"
        alert_once "${service}-health" \
"Service: $service
Host: $(hostname)
Health endpoint $url failing
Time: $(date)"
    fi
}

get_resource_usage() {
    local service="$1"
    local pid=$(systemctl show "$service" -p MainPID --value)

    if [[ -z "$pid" || "$pid" -eq 0 ]]; then
        echo "  Resource Usage: N/A (no PID)"
        return
    fi

    local cpu mem
    cpu=$(ps -p "$pid" -o %cpu= | tr -d ' ')
    mem=$(ps -p "$pid" -o %mem= | tr -d ' ')

    echo "  CPU: ${cpu:-N/A}%"
    echo "  Memory: ${mem:-N/A}%"

    # CPU threshold check
    if [[ -n "$cpu" ]] && (( $(awk "BEGIN {print ($cpu > $CPU_THRESHOLD)}") )); then
        alert_once "${service}-cpu" \
"Service: $service
Host: $(hostname)
CPU usage: ${cpu}% (threshold: ${CPU_THRESHOLD}%)
Time: $(date)"
    else
        clear_alert "${service}-cpu"
    fi

    # Memory threshold check
    if [[ -n "$mem" ]] && (( $(awk "BEGIN {print ($mem > $MEMORY_THRESHOLD)}") )); then
        alert_once "${service}-memory" \
"Service: $service
Host: $(hostname)
Memory usage: ${mem}% (threshold: ${MEMORY_THRESHOLD}%)
Time: $(date)"
    else
        clear_alert "${service}-memory"
    fi
}

count_errors() {
    local service="$1"
    local errors
    errors=$(journalctl -u "$service" --since "1 hour ago" 2>/dev/null | grep -ic "error" || echo 0)

    echo "  Errors (last hour): $errors"

    if awk -v a="$errors" -v b="$ERROR_THRESHOLD" 'BEGIN{exit !(a>b)}'; then
        echo -e "  \e[33m⚠ High error rate\e[0m"
        alert_once "${service}-errors" \
"Service: $service
Host: $(hostname)
Errors last hour: $errors (threshold: $ERROR_THRESHOLD)
Time: $(date)"
    else
        clear_alert "${service}-errors"
    fi
}

check_service_logs() {
    local service="$1"
    echo "  Recent Logs:"
    journalctl -u "$service" -n 10 --no-pager 2>/dev/null
}

# ---------------- SUMMARY ----------------
show_summary() {
    local total=${#SERVICES[@]}
    local running=0 failed=0

    for service in "${SERVICES[@]}"; do
        if systemctl is-active "$service" >/dev/null 2>&1; then
            ((running++))
        else
            ((failed++))
        fi
    done

    echo "=== APPLICATION STACK HEALTH ==="
    if (( failed == 0 )); then
        echo -e "Status: \e[32m✓ HEALTHY\e[0m"
    else
        echo -e "Status: \e[31m✗ DEGRADED ($failed failed)\e[0m"
    fi
    echo "Services Running: $running/$total"
    echo "Checked at: $(date)"
    echo "====================================="
}

# ---------------- MAIN ----------------
main() {
    clear
    show_summary
    echo
    echo "=== Detailed Service Monitor ==="
    echo "Started at $(date)"
    echo

    for service in "${SERVICES[@]}"; do
        check_service_status "$service"

        if systemctl is-active "$service" >/dev/null 2>&1; then
            get_service_details "$service"

            [[ "$service" == "flask-demo" ]] && check_health_endpoint "$service" "$FLASK_HEALTH_URL"

            get_resource_usage "$service"
            count_errors "$service"
            echo
            check_service_logs "$service"
            echo "-----------------------------------"
        fi
        echo
    done
}

main