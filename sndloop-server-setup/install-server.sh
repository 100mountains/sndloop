#!/bin/bash
# LEMP Server installation script for Ubuntu 24.04 - For Flutter/SNDLOOP
# Based on your WordPress script but without WordPress installation

# Check if running as root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ "$EUID" -ne 0 ]; then
   echo "Please run as root (use sudo)"
   exit 1
fi

# Check if we're in the right directory with our templates
if [ ! -f "configs/nginx/nginx-sndloop.template" ] || [ ! -f "configs/nginx/nginx.conf.template" ]; then
    echo "Error: Missing template files. Make sure you're running this from the server-setup directory."
    exit 1
fi

# Load environment variables from .env file
if [ -f .env ]; then
  set -a  # automatically export all variables
  source .env
  set +a  # disable automatic export
fi

# Check for required env variables
if [ -z "$DOMAIN_NAME" ] || [ -z "$EMAIL" ]; then
    echo "Error: DOMAIN_NAME and EMAIL must be set in .env file"
    exit 1
fi

echo "Installing LEMP stack on Ubuntu 24.04 (For Flutter/SNDLOOP)..."
echo "Domain: $DOMAIN_NAME"
echo "Email: $EMAIL"

# Generate random credentials for database
MYSQL_ROOT_PASS=$(openssl rand -base64 12 | tr -d "=+/'\"")
SNDLOOP_DB_NAME="sndloop"
SNDLOOP_DB_USER="sndloop_user"
SNDLOOP_DB_PASS=$(openssl rand -base64 12 | tr -d "=+/'\"")

# Update system
apt update && apt upgrade -y

# Install LEMP stack with PHP extensions (keeping PHP for potential API needs)
apt install -y nginx certbot python3-certbot-nginx mariadb-server \
    php8.3-fpm php8.3-mysql php8.3-curl php8.3-gd php8.3-mbstring \
    php8.3-xml php8.3-zip php8.3-imagick php8.3-intl php8.3-bcmath

# Install Node.js for potential API backend
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt install -y nodejs

# Install optional software
apt install -y sshfs git

# Apply MariaDB configuration template BEFORE starting
echo "Applying MariaDB configuration template..."
if [ -d "$SCRIPT_DIR/configs/mariadb/conf.d/" ]; then
    cp "$SCRIPT_DIR/configs/mariadb/conf.d/"* /etc/mysql/mariadb.conf.d/
fi

# Fix debian-start script access BEFORE starting  
echo "Configuring MariaDB debian-start script..."
if [ -f "$SCRIPT_DIR/configs/mariadb-conf/debian.cnf" ]; then
    cp "$SCRIPT_DIR/configs/mariadb-conf/debian.cnf" /etc/mysql/debian.cnf
    chmod 600 /etc/mysql/debian.cnf
fi

# Start and enable services
systemctl enable nginx mariadb php8.3-fpm
systemctl start nginx mariadb php8.3-fpm

# Configure systemd service dependencies for proper boot order
echo "Configuring systemd service dependencies..."
mkdir -p /etc/systemd/system/nginx.service.d
mkdir -p /etc/systemd/system/php8.3-fpm.service.d
if [ -f "$SCRIPT_DIR/configs/systemd/overrides/nginx-mariadb-dependency.conf" ]; then
    cp "$SCRIPT_DIR/configs/systemd/overrides/nginx-mariadb-dependency.conf" /etc/systemd/system/nginx.service.d/mariadb-dependency.conf
fi
if [ -f "$SCRIPT_DIR/configs/systemd/overrides/php-fpm-mariadb-dependency.conf" ]; then
    cp "$SCRIPT_DIR/configs/systemd/overrides/php-fpm-mariadb-dependency.conf" /etc/systemd/system/php8.3-fpm.service.d/mariadb-dependency.conf
fi
systemctl daemon-reload

# Secure MySQL and set root password
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS';"
mysql -u root -p"$MYSQL_ROOT_PASS" -e "DELETE FROM mysql.user WHERE User='';"
mysql -u root -p"$MYSQL_ROOT_PASS" -e "DROP DATABASE IF EXISTS test;"
mysql -u root -p"$MYSQL_ROOT_PASS" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -u root -p"$MYSQL_ROOT_PASS" -e "FLUSH PRIVILEGES;"

# Create SNDLOOP database and user
mysql -u root -p"$MYSQL_ROOT_PASS" -e "CREATE DATABASE $SNDLOOP_DB_NAME DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -u root -p"$MYSQL_ROOT_PASS" -e "CREATE USER '$SNDLOOP_DB_USER'@'localhost' IDENTIFIED BY '$SNDLOOP_DB_PASS';"
mysql -u root -p"$MYSQL_ROOT_PASS" -e "GRANT ALL PRIVILEGES ON $SNDLOOP_DB_NAME.* TO '$SNDLOOP_DB_USER'@'localhost';"
mysql -u root -p"$MYSQL_ROOT_PASS" -e "FLUSH PRIVILEGES;"

# Create web root for Flutter app
mkdir -p /var/www/sndloop
echo "<h1>SNDLOOP - Coming Soon</h1>" > /var/www/sndloop/index.html

# Setup PHP configuration from templates (if you have APIs)
if [ -f "$SCRIPT_DIR/configs/php/8.3/fpm/php.ini.template" ]; then
    echo "Configuring PHP from templates..."
    cp "$SCRIPT_DIR/configs/php/8.3/fpm/php.ini.template" /etc/php/8.3/fpm/php.ini
fi
if [ -f "$SCRIPT_DIR/configs/php/8.3/fpm/pool.d/www.conf.template" ]; then
    cp "$SCRIPT_DIR/configs/php/8.3/fpm/pool.d/www.conf.template" /etc/php/8.3/fpm/pool.d/www.conf
fi

# Restart PHP-FPM to apply new configuration
systemctl restart php8.3-fpm

# Set proper permissions
chown -R www-data:www-data /var/www/sndloop
find /var/www/sndloop -type d -exec chmod 755 {} \;
find /var/www/sndloop -type f -exec chmod 644 {} \;

# Setup nginx from template
echo "Configuring Nginx from template..."
cp "$SCRIPT_DIR/configs/nginx/nginx-sndloop.template" /etc/nginx/sites-available/sndloop

# Replace domain placeholder
sed -i "s/%%DOMAIN_NAME%%/$DOMAIN_NAME/g" /etc/nginx/sites-available/sndloop

# Configure main nginx.conf from template (if you have one)
if [ -f "$SCRIPT_DIR/configs/nginx/nginx.conf.template" ]; then
    cp "$SCRIPT_DIR/configs/nginx/nginx.conf.template" /etc/nginx/nginx.conf
fi

# Enable site and remove default
ln -sf /etc/nginx/sites-available/sndloop /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test nginx config and restart services
nginx -t && systemctl restart nginx php8.3-fpm

# Get SSL cert
echo "Getting SSL certificate..."
certbot --nginx --non-interactive --agree-tos -m "$EMAIL" -d "$DOMAIN_NAME"

# Create directory for Node.js apps
mkdir -p /var/www/nodejs
chown -R www-data:www-data /var/www/nodejs

# Save credentials
cat > /root/sndloop-credentials.txt << EOF
MYSQL_ROOT_PASS="$MYSQL_ROOT_PASS"
SNDLOOP_DB_NAME="$SNDLOOP_DB_NAME"
SNDLOOP_DB_USER="$SNDLOOP_DB_USER"
SNDLOOP_DB_PASS="$SNDLOOP_DB_PASS"
DOMAIN_NAME="$DOMAIN_NAME"
EMAIL="$EMAIL"
WEB_ROOT="/var/www/sndloop"
NODEJS_ROOT="/var/www/nodejs"
EOF

chmod 600 /root/sndloop-credentials.txt

# Display completion message
echo "=========================="
echo "LEMP Stack Installation Complete!"
echo "Optimized for SNDLOOP/Flutter"
echo "=========================="
echo "MySQL Root Password: $MYSQL_ROOT_PASS"
echo "SNDLOOP Database: $SNDLOOP_DB_NAME"
echo "SNDLOOP DB User: $SNDLOOP_DB_USER"
echo "SNDLOOP DB Password: $SNDLOOP_DB_PASS"
echo "Web Root: /var/www/sndloop"
echo "Node.js Apps: /var/www/nodejs"
echo "=========================="
echo "Credentials saved to: /root/sndloop-credentials.txt"
echo "SSL Certificate installed for: https://$DOMAIN_NAME"
echo ""
echo "Next steps:"
echo "1. Deploy your Flutter web build to /var/www/sndloop"
echo "2. Deploy any Node.js backend to /var/www/nodejs"
echo "3. Run ./harden.sh to secure the server"
