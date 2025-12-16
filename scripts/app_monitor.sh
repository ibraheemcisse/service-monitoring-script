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

# Main function
main() {
    echo "=== Application Service Monitor ==="
    echo "Starting checks at $(date)"
    echo ""

    for service in "${SERVICES[@]}"; do
        check_service_status "$service"
    done
}

# Run main
main