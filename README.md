# Application Service Monitor

A Bash monitoring script for multi-tier application stacks with intelligent alerting and threshold-based warnings.

## 🎯 Overview

This monitoring solution provides comprehensive health checks for service-based architectures. Built to monitor a 3-tier stack (Database → Application → Web Server), it features retry logic, threshold monitoring, and Slack integration for real-time alerts.

## ✨ Features

### Core Monitoring
- **Service Status Checks** - Real-time monitoring of systemd services
- **Health Endpoint Validation** - HTTP endpoint health checks with retry logic
- **Resource Tracking** - CPU and memory usage per service  
- **Multi-Channel Alerts** - Service failures, resource warnings, health check failures, high latency
- **Log Analysis** - Error detection and counting from journald logs
- **Process Information** - PID tracking and uptime monitoring

### Intelligence
- **Retry Logic** - 3-attempt verification before alerting (prevents false positives)
- **Alert Deduplication** - Smart alert suppression to prevent notification spam
- **Threshold-Based Warnings** - Configurable CPU, Memory, and Error thresholds
- **Auto-Recovery Detection** - Automatic alert clearing when issues resolve

### Alerting
- **Slack Integration** - Real-time notifications via webhook
- **Multi-Channel Alerts** - Service failures, resource warnings, health check failures
- **Alert State Tracking** - Persistent alert state management
- **Configurable Intervals** - Control alert frequency

### Output
- **Color-Coded Display** - Visual status indicators (Green/Red/Yellow)
- **Summary Dashboard** - At-a-glance health overview
- **Detailed Reports** - Per-service breakdown with logs
- **Clean Formatting** - Professional, easy-to-read output

## 🏗️ Architecture

This project demonstrates monitoring a complete 3-tier application stack:
```
┌─────────────────────────────────────┐
│  nginx (Web Server) - Port 80       │
│  Reverse proxy to Flask             │
└──────────────┬──────────────────────┘
               │
               ↓
┌─────────────────────────────────────┐
│  Flask (Application) - Port 5000    │
│  Python web application             │
└──────────────┬──────────────────────┘
               │
               ↓
┌─────────────────────────────────────┐
│  PostgreSQL (Database) - Port 5432  │
│  Data persistence layer             │
└─────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites
```bash
# Required packages
sudo apt install curl systemd

# Services to monitor (example)
sudo apt install postgresql nginx python3-venv
```

### Installation
```bash
# Clone the repository
git clone https://github.com/ibraheemcisse/service-monitoring-script.git
cd service-monitoring-script

# Make script executable
chmod +x scripts/app_monitor.sh

# Run the monitor
./scripts/app_monitor.sh
```

### Configuration
```bash
# Set environment variables (optional)
export CPU_THRESHOLD=80
export MEMORY_THRESHOLD=90
export ERROR_THRESHOLD=10
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

# Run with custom config
./scripts/app_monitor.sh
```

## 📖 Usage

### Basic Monitoring
```bash
# Monitor all configured services
./scripts/app_monitor.sh
```

### Custom Thresholds
```bash
# Lower thresholds for testing
CPU_THRESHOLD=50 MEMORY_THRESHOLD=70 ./scripts/app_monitor.sh

# Disable verbose retry output
VERBOSE=0 ./scripts/app_monitor.sh
```

### Continuous Monitoring
```bash
# Run every 5 minutes via cron
*/5 * * * * /path/to/scripts/app_monitor.sh

# Or use watch for live monitoring
watch -n 30 ./scripts/app_monitor.sh
```

## 🎨 Sample Output
```
=== APPLICATION STACK HEALTH ===
Status: ✓ HEALTHY
Services Running: 3/3
Checked at: Thu Dec 18 11:30:45 AM +08 2025
=====================================

=== Detailed Service Monitor ===
Started at Thu Dec 18 11:30:45 AM +08 2025

✓ postgresql is running
  PID: 1234
  Started: Thu 2025-12-18 10:00:00 +08
  Resource Usage: N/A (no PID)
  Errors (last hour): 0

✓ flask-demo is running
  PID: 5678
  Started: Thu 2025-12-18 10:00:15 +08
  Health: ✓ Endpoint responding
  CPU: 2.3%
  Memory: 1.2%
  Errors (last hour): 0

✓ nginx is running
  PID: 9012
  Started: Thu 2025-12-18 10:00:30 +08
  CPU: 0.1%
  Memory: 0.3%
  Errors (last hour): 0
```

## ⚙️ Configuration Options

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CPU_THRESHOLD` | 80 | CPU usage warning threshold (%) |
| `MEMORY_THRESHOLD` | 80 | Memory usage warning threshold (%) |
| `ERROR_THRESHOLD` | 10 | Error count threshold (per hour) |
| `ALERT_REPEAT_SECONDS` | 3 | Minimum time between repeat alerts |
| `SLACK_WEBHOOK_URL` | - | Slack webhook URL for alerts |
| `VERBOSE` | 1 | Show retry attempt messages (0/1) |

### Services Configuration

Edit the `SERVICES` array in the script:
```bash
SERVICES=("postgresql" "flask-demo" "nginx" "your-service")
```

### Health Endpoint

Configure health check URL:
```bash
FLASK_HEALTH_URL="http://localhost:5000/health"
```

## 🔔 Slack Alerts

### Setup

1. Create a Slack webhook: https://api.slack.com/messaging/webhooks
2. Set the webhook URL:
```bash
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/T00000000/B00000000/XXXX"
```

### Alert Types

The script sends alerts for:
- 🚨 Service down/failed
- ⚠️ CPU threshold exceeded
- ⚠️ Memory threshold exceeded
- ⚠️ High error rate detected
- ❌ Health endpoint failures

### Alert Message Format
```
🚨 SERVICE ALERT
Service: flask-demo
Host: your-hostname
CPU usage: 85% (threshold: 80%)
Time: Thu Dec 18 11:30:45 AM +08 2025
```

## 🧪 Testing

### Test Service Failure Detection
```bash
# Stop a service
sudo systemctl stop flask-demo

# Run monitor (should detect failure)
./scripts/app_monitor.sh

# Restart service
sudo systemctl start flask-demo
```

### Test Threshold Warnings
```bash
# Set low thresholds to trigger warnings
CPU_THRESHOLD=0 MEMORY_THRESHOLD=0 ./scripts/app_monitor.sh
```

### Test Alert Deduplication
```bash
# Run multiple times - alerts only sent once
./scripts/app_monitor.sh
./scripts/app_monitor.sh  # No duplicate alert

# Check alert state files
ls -la /tmp/*.alerted
```

## 📁 Project Structure
```
service-monitoring-script/
├── scripts/
│   └── app_monitor.sh          # Main monitoring script
├── app/
│   ├── app.py                  # Flask application (example)
│   └── venv/                   # Python virtual environment
├── services/
│   └── flask-demo.service      # systemd service file (example)
└── README.md                   # This file
```

## 🛠️ Deployment

### As a systemd Service

Create a systemd timer for automated monitoring:
```bash
# /etc/systemd/system/app-monitor.timer
[Unit]
Description=Run Application Monitor every 5 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
```
```bash
# /etc/systemd/system/app-monitor.service
[Unit]
Description=Application Service Monitor

[Service]
Type=oneshot
ExecStart=/path/to/scripts/app_monitor.sh
Environment="SLACK_WEBHOOK_URL=your-webhook-url"
```

Enable and start:
```bash
sudo systemctl enable app-monitor.timer
sudo systemctl start app-monitor.timer
```

## 📊 Monitoring Best Practices

1. **Set Realistic Thresholds** - Based on your application's normal behavior
2. **Use Alert Deduplication** - Prevent notification fatigue
3. **Monitor Health Endpoints** - Not just process existence
4. **Review Logs Regularly** - Error patterns indicate deeper issues
5. **Test Failure Scenarios** - Ensure monitoring catches real problems

## 🤝 Contributing

Contributions welcome! Please feel free to submit a Pull Request.

## 📝 License

MIT License - feel free to use this in your own projects!

## 👤 Author

**Ibrahim Cisse**
- GitHub: [@ibraheemcisse](https://github.com/ibraheemcisse)
- LinkedIn: [Ibrahim Cisse](https://linkedin.com/in/ibraheemcisse)

---

**⭐ If you find this useful, please star the repo!**
