#!/bin/bash

# Main installation script for SNDLOOP server
# Runs setup scripts in the correct order

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

# Load environment variables from .env file
if [ -f .env ]; then
  set -a  # automatically export all variables
  source .env
  set +a  # disable automatic export
fi

# Get domain and email (from .env, environment, or prompt)
if [[ -z "${DOMAIN_NAME:-}" ]]; then
    echo "Domain name not found in .env file or environment."
    read -p "Enter your domain name: " DOMAIN_NAME
fi

if [[ -z "${EMAIL:-}" ]]; then
    echo "Email not found in .env file or environment."
    read -p "Enter your admin email: " EMAIL
fi

# Create .env file with the values for child scripts
echo "DOMAIN_NAME=$DOMAIN_NAME" > .env
echo "EMAIL=$EMAIL" >> .env
log "Created .env file with domain and email configuration"

log "Starting SNDLOOP server setup for domain: $DOMAIN_NAME"
log "Admin email: $EMAIL"

# Function to run script with error handling
run_script() {
    local script_name=$1
    local description=$2
    
    log "Starting: $description"
    
    if [[ ! -f "$script_name" ]]; then
        error "Script $script_name not found!"
        exit 1
    fi
    
    if ! bash "$script_name"; then
        error "Script $script_name failed!"
        exit 1
    fi
    
    log "Completed: $description"
}

# Pre-flight checks
log "Running pre-flight checks..."

# Check if we have internet connectivity
if ! ping -c 1 google.com &> /dev/null; then
    error "No internet connectivity detected"
    exit 1
fi

# Check for SSH keys (important for hardening script)
ssh_keys_exist=false
if [[ -f ~/.ssh/authorized_keys && -s ~/.ssh/authorized_keys ]]; then
    ssh_keys_exist=true
fi

if [[ "$ssh_keys_exist" == false ]]; then
    error "No SSH keys found in ~/.ssh/authorized_keys"
    echo "SSH keys are required because the hardening script disables password authentication"
    echo "Please add your SSH public key before running this script"
    exit 1
fi

log "Pre-flight checks passed"

# Run scripts in order
log "=== Starting SNDLOOP server installation ==="

# Step 1: LEMP stack installation
run_script "install-server.sh" "LEMP stack installation (Nginx, MariaDB, PHP)"

# Step 2: Security hardening
run_script "harden.sh" "Security hardening (SSH, firewall, fail2ban)"

log "=== Installation completed successfully! ==="
log "Your SNDLOOP server is now ready at: https://$DOMAIN_NAME"
log ""
log "Next steps:"
log "1. Deploy your Flutter web build to /var/www/sndloop"
log "   scp -r build/web/* root@$DOMAIN_NAME:/var/www/sndloop/"
log "2. Deploy any Node.js backend APIs to /var/www/nodejs"
log "3. Configure your DNS to point $DOMAIN_NAME to this server"
log ""
log "Database credentials are in: /root/sndloop-credentials.txt"
log ""
log "Server services status:"
systemctl status nginx --no-pager -l
systemctl status mariadb --no-pager -l
systemctl status fail2ban --no-pager -l
