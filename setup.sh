#!/bin/bash

# Exit on error
set -e

# Variables
APP_DIR="/home/ubuntu/attempt3-app"
APP_NAME="app.py"
DOMAIN="robin-davey.com"  # Your domain
EMAIL="your-email@example.com"  # Replace with your email for SSL notifications

echo "Starting Flask web app setup with Gunicorn, Nginx, and SSL..."

# Update system
echo "Updating system packages..."
sudo apt update
sudo apt upgrade -y

# Install required packages
echo "Installing required packages..."
sudo apt install -y python3 python3-pip python3-venv nginx certbot python3-certbot-nginx

# Create or navigate to the app directory
echo "Setting up application directory..."
if [ ! -d "$APP_DIR" ]; then
    mkdir -p "$APP_DIR"
fi
cd "$APP_DIR"

# Create virtual environment
echo "Creating Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Install Flask and Gunicorn
echo "Installing Flask and Gunicorn..."
pip install flask gunicorn

# Create a sample Flask app if it doesn't exist
if [ ! -f "$APP_NAME" ]; then
    echo "Creating a sample Flask application..."
    cat > "$APP_NAME" << EOF
from flask import Flask

app = Flask(__name__)

@app.route('/')
def home():
    return "Hello, World! Flask app is running with Gunicorn, Nginx, and SSL."

if __name__ == '__main__':
    app.run(debug=True)
EOF
fi

# Create a WSGI entry point
echo "Creating WSGI entry point..."
cat > wsgi.py << EOF
from app import app

if __name__ == "__main__":
    app.run()
EOF

# Create a Gunicorn systemd service
echo "Creating Gunicorn systemd service..."
sudo bash -c "cat > /etc/systemd/system/flask-app.service << EOF
[Unit]
Description=Gunicorn instance to serve flask application
After=network.target

[Service]
User=ubuntu
Group=www-data
WorkingDirectory=$APP_DIR
Environment=\"PATH=$APP_DIR/venv/bin\"
ExecStart=$APP_DIR/venv/bin/gunicorn --workers 3 --bind unix:$APP_DIR/flask-app.sock -m 007 wsgi:app

[Install]
WantedBy=multi-user.target
EOF"

# Start and enable the Gunicorn service
echo "Starting Gunicorn service..."
sudo systemctl start flask-app
sudo systemctl enable flask-app

# Configure Nginx
echo "Configuring Nginx..."
sudo bash -c "cat > /etc/nginx/sites-available/flask-app << EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        include proxy_params;
        proxy_pass http://unix:$APP_DIR/flask-app.sock;
    }
}
EOF"

# Enable the Nginx configuration
sudo ln -sf /etc/nginx/sites-available/flask-app /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

# Configure firewall if it's active
echo "Configuring firewall..."
sudo ufw allow 'Nginx Full'

# Set up SSL with Certbot
echo "Setting up SSL with Certbot..."
sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL

# Final restart of services
echo "Restarting services..."
sudo systemctl restart flask-app
sudo systemctl restart nginx

echo "Setup complete! Your Flask app should be running at https://$DOMAIN"
echo "Check status with: sudo systemctl status flask-app"
echo "View logs with: sudo journalctl -u flask-app"