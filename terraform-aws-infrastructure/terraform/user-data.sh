#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "=== [1/6] apt-get update ==="
apt-get update -y

echo "=== [2/6] install docker.io, nginx, curl ==="
apt-get install -y docker.io nginx curl

echo "=== [3/6] enable and start docker + nginx ==="
systemctl enable --now docker
systemctl enable --now nginx

echo "=== [4/6] pull and run the app container ==="
# Maps host port ${app_port} to the container's ${app_internal_port}.
# Default: nginx:latest (internal port 80). If you swap in your own image
# listening on 3000, set app_internal_port = 3000.
docker run -d --name app --restart unless-stopped -p ${app_port}:${app_internal_port} ${app_image}

echo "=== [5/6] configure nginx reverse proxy to localhost:${app_port} ==="
cat > /etc/nginx/sites-available/app <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    server_tokens off;

    location / {
        proxy_pass http://127.0.0.1:${app_port};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 5s;
        proxy_read_timeout 30s;
    }
}
EOF

# Disable the default site so ours is the only one on port 80
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/app /etc/nginx/sites-enabled/app

# Validate config before reloading
nginx -t
systemctl reload nginx

echo "=== [6/6] marker ==="
echo "USER DATA COMPLETE $(date -u)" | tee /tmp/user-data-complete.log
