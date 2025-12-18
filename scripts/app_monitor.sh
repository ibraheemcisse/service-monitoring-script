#!/bin/bash

# Application Service Monitor
# Monitors multi-tier application stack

# Services to monitor
SERVICES=("postgresql" "flask-demo" "nginx")

#retry command function
retry_command() {
local max_attempts=3
    local attempt=1
    local wait_time=2
    local command="$@"
    
    while [ $attempt -le $max_attempts ]; do

        echo "  [Attempt $attempt/$max_attempts]" >&2 

        if eval "$command" > /dev/null 2>&1; then
            return 0  # Success
        fi
        
        if [ $attempt -lt $max_attempts ]; then
        
        echo "  [Waiting ${wait_time}s before retry...]" >&2  # Add this

            sleep $wait_time
        fi
        ((attempt++))
    done
    
    return 1  # Failed after all retries
}

# Check if a service is active
check_service_status() {
    local service="$1"

    if retry_command systemctl is-active "$service"; then
        echo -e "\e[32m✓ $service is running\e[0m"  # Fixed: removed extra ]
        return 0
    else 
        echo -e "\e[31m✗ $service is NOT running\e[0m"
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
    
    if retry_command "curl -s -f -m 5 "$url""; then
        echo -e "  Health: \e[32m✓ Endpoint responding\e[0m"
    else
        echo -e "  Health: \e[31m✗ Endpoint not responding\e[0m"
    fi
}

# Get resource usage (CPU and Memory)
get_resource_usage() {
    local service="$1"
    local pid=$(systemctl show "$service" --property=MainPID --value)

    # Check if PID is valid
    if [ -z "$pid" ] || [ "$pid" -eq 0 ]; then
        echo "  Resource Usage: N/A (no valid PID)"
        return
    fi
    
    # Get CPU and Memory
    local cpu=$(ps -p $pid -o %cpu --no-headers 2>/dev/null)
    local memory=$(ps -p $pid -o %mem --no-headers 2>/dev/null)
    
    echo "  CPU: ${cpu}%"
    echo "  Memory: ${memory}%"
}

# Count errors in logs
count_errors() {
    local service="$1"
    local error_count=$(journalctl -u "$service" --since "1 hour ago" 2>/dev/null | grep -ic "error")
    
    echo "  Errors (last hour): $error_count"
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