#!/bin/bash

#service monitoring script
SERVICES=("postgresql" "flask-demo" "nginx" "docker")

# Check if postgresql is active
check_service_status() {
    local service="$1"

    if systemctl is-active "$service" > /dev/null 2>&1; then 
        echo "✓ $service is running"
        return 0
    else 
        echo "✗ $service is NOT running"
        return 1
    fi
}

get_service_details() {
    local service="$1"
    
    # Get the Main PID
    local pid=$(systemctl show "$service" --property=MainPID --value)
    
    # Get uptime (how long service has been running)
    local uptime=$(systemctl show "$service" --property=ActiveEnterTimestamp --value)
    
    echo "  PID: $pid"
    echo "  Started: $uptime"
}

check_health_endpoint() {
    local service="$1"
    local url="$2"
    
    # Try to curl the health endpoint
    if curl -s -f "$url" > /dev/null 2>&1; then
        echo "  Health: ✓ Endpoint responding"
    else
        echo "  Health: ✗ Endpoint not responding"
    fi
}

get_resource_usage() {
    local service="$1"
    
    # Get PID
    local pid=$(systemctl show "$service" --property=MainPID --value)

    #check of pid is valid
    if [ -z "$pid" ] || [ "$pid" -eq 0 ]; then
        echo "  Resource Usage: N/A (no valid PID)"
        return
    fi
    
    #get cpu 
    local cpu=$(ps -p $pid -o %cpu --no-headers)
    
    echo "  CPU: ${cpu}%"

    #get memory
    local memory=$(ps -p $pid -o %mem --no-headers)
    
    echo "  Memory Usage: ${memory}%"

}

check_service_logs() {
    local service="$1"
    
    echo "  Recent Logs:"
    journalctl -u "$service" -n 10 --no-pager
}

count_errors_in_logs() {
    local service="$1"
    
    local error_count=$(journalctl -u "$service" --since "1 hour ago" | grep -i "error" | wc -l)
    
    echo "  Errors in last hour: $error_count"
}

# Main function
main() {
    echo "=== Application Service Monitor ==="
    echo "Starting checks at $(date)"
    echo ""

    for service in "${SERVICES[@]}"; do
        check_service_status "$service"
    
        # If service is running, show details
        if systemctl is-active "$service" > /dev/null 2>&1; then
            get_service_details "$service"
            
            # Check health endpoint for flask-demo
            if [ "$service" = "flask-demo" ]; then
                check_health_endpoint "$service" "http://localhost:5000/health"
            fi
            
            get_resource_usage "$service"
            count_errors_in_logs "$service"

            echo ""
            check_service_logs "$service"
            echo "-----------------------------------"
        fi
    done
}

# Run main
main