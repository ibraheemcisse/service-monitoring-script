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
            echo "" 
        fi
    done

}

# Run maingit branch -M main

main