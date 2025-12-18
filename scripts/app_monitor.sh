#!/bin/bash

# Application Service Monitor that Monitors multi-tier application stack

# Services to monitor
SERVICES=("postgresql" "flask-demo" "nginx")

#Thresholds
CPU_THRESHOLD=0
MEMORY_THRESHOLD=0 
ERROR_THRESHOLD=0

#alert repeat interval in seconds
ALERT_REPEAT_SECONDS=${ALERT_REPEAT_SECONDS:-3600}

# Function to send Slack alert
send_slack_alert() {
    local message="$1"

    # If webhook is not set, silently skip
    [[ -z "${SLACK_WEBHOOK_URL:-}" ]] && return

    curl -s -X POST \
        -H 'Content-type: application/json' \
        --data "{
          \"text\": \"🚨 SERVICE ALERT\n$message\"
        }" \
        "$SLACK_WEBHOOK_URL" >/dev/null
}

alert_once() {
    local name="$1"          # e.g. "${service}-cpu" or service name for down alerts
    local message="$2"
    local alert_file="/tmp/${name}.alerted"

    # If file exists, check mtime (allow repeat only after ALERT_REPEAT_SECONDS)
    if [[ -f "$alert_file" ]]; then
        local last=$(stat -c %Y "$alert_file" 2>/dev/null || echo 0)
        local now=$(date +%s)
        local age=$((now - last))
        if [ "$age" -lt "$ALERT_REPEAT_SECONDS" ]; then
            # too recent, skip
            return
        fi
    fi

    # send alert and update/refresh marker file
    send_slack_alert "$message"
    touch "$alert_file"
}


#retry command function

retry_command() {
    local max_attempts=3
    local attempt=1
    local wait_time=2
    local command="$@"
    local show_attempts=false  # Flag to track if we needed retries
    
    while [ $attempt -le $max_attempts ]; do
        if eval "$command" > /dev/null 2>&1; then
            return 0  # Success - no message needed
        fi
        
        # Only show retry messages if first attempt failed
        if [ $attempt -eq 1 ]; then
            show_attempts=true
        fi
        
        if [ "$show_attempts" = true ]; then
            echo "  [Retry attempt $attempt/$max_attempts failed]" >&2
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            if [ "$show_attempts" = true ]; then
                echo "  [Waiting ${wait_time}s before retry...]" >&2
            fi
            sleep $wait_time
        fi
        ((attempt++))
    done
    
    return 1  # All attempts failed
}

# Check if a service is active
check_service_status() {
    local service="$1"

if retry_command systemctl is-active "$service"; then
    rm -f /tmp/"${service}"*.alerted
    echo -e "\e[32m✓ $service is running\e[0m"
    return 0
else
    echo -e "\e[31m✗ $service is NOT running\e[0m"

alert_once "$service" \
"Service: $service
Host: $(hostname)
State: NOT RUNNING
Time: $(date)
Next step: systemctl status $service"


    return 1
fi

}

# Get service details (PID and start time)
get_service_details() {
    local service="$1"
    
    local pid=$(systemctl show "$service" --property=MainPID --value)
    local uptime=$(systemctl show "$service" --property=ActiveEnterTimestamp --value)
    
    echo "  PID: $pid"
    echo "  Started: $uptime"
}

# Check health endpoint
check_health_endpoint() {
    local service="$1"
    local url="$2"
    
    if retry_command "curl -s -f -m 5 $url"; then
        echo -e "  Health: \e[32m✓ Endpoint responding\e[0m"
    else
        echo -e "  Health: \e[31m✗ Endpoint not responding\e[0m"
    fi
}

# Get resource usage (CPU and Memory)
get_resource_usage() {
    local service="$1"
    local pid=$(systemctl show "$service" --property=MainPID --value)

    if [ -z "$pid" ] || [ "$pid" -eq 0 ]; then
        echo "  Resource Usage: N/A (no valid PID)"
        return
    fi

    local cpu=$(ps -p "$pid" -o %cpu --no-headers 2>/dev/null | tr -d ' ')
    local memory=$(ps -p "$pid" -o %mem --no-headers 2>/dev/null | tr -d ' ')

    echo "  CPU: ${cpu}%"
    echo "  Memory: ${memory}%"

    # Floating-point comparison with awk
if [ -n "$cpu" ] && awk -v a="$cpu" -v b="$CPU_THRESHOLD" 'BEGIN{exit !(a>b)}'; then
    echo -e "...warning..."
    alert_once "${service}-cpu" "Service: $service ... CPU ${cpu}% ..."
else
    rm -f "/tmp/${service}-cpu.alerted" 2>/dev/null || true
fi

# Memory check (same pattern)
if [ -n "$memory" ] && awk -v a="$memory" -v b="$MEMORY_THRESHOLD" 'BEGIN{exit !(a>b)}'; then
    ...
    alert_once "${service}-memory" "Service: $service ... Memory ${memory}% ..."
else
    rm -f "/tmp/${service}-memory.alerted" 2>/dev/null || true
fi
}


# Count errors in logs
count_errors() {
    local service="$1"
    local error_count
    error_count=$(journalctl -u "$service" --since "1 hour ago" 2>/dev/null | grep -ic "error" || true)

    echo "  Errors (last hour): $error_count"

    if [ "$error_count" -gt "$ERROR_THRESHOLD" ]; then
        echo -e "  \e[33m⚠ WARNING: Error count above $ERROR_THRESHOLD\e[0m"
        alert_once "${service}-errors" "Service: $service\nHost: $(hostname)\nErrors (last hour): $error_count\nThreshold: ${ERROR_THRESHOLD}\nTime: $(date)"
    fi
}

# Show recent logs
check_service_logs() {
    local service="$1"
    
    echo "  Recent Logs:"
    journalctl -u "$service" -n 10 --no-pager 2>/dev/null
}

# Show summary dashboard
show_summary() {
    local total_services=${#SERVICES[@]}
    local running_count=0
    local failed_count=0
    
    # Count running vs failed services
    for service in "${SERVICES[@]}"; do
        if systemctl is-active "$service" > /dev/null 2>&1; then 
            ((running_count++))
        else 
            ((failed_count++))
        fi
    done
    
    # Display summary
    echo "=== APPLICATION STACK HEALTH ==="
    
    if [ $failed_count -eq 0 ]; then
        echo -e "Status: \e[32m✓ HEALTHY\e[0m"
    else
        echo -e "Status: \e[31m✗ DEGRADED\e[0m"
    fi
    
    echo "Services Running: $running_count/$total_services"
    echo "Services Failed: $failed_count/$total_services"
    echo "Checked at: $(date)"
    echo "====================================="
}

# Main function
main() {
    clear
    
    show_summary
    echo ""
    
    echo "=== Detailed Service Monitor ==="
    echo "Starting checks at $(date)"
    echo ""

    for service in "${SERVICES[@]}"; do
        check_service_status "$service"
    
        if systemctl is-active "$service" > /dev/null 2>&1; then
            get_service_details "$service"
            
            # Check health endpoint for flask-demo
            if [ "$service" = "flask-demo" ]; then
                check_health_endpoint "$service" "http://localhost:5000/health"
            fi
            
            get_resource_usage "$service"
            count_errors "$service"
            echo ""
            check_service_logs "$service"
            echo "-----------------------------------"
        fi
    done
}

# Run main
main