# Steps — linux-nginx-server

Copy-paste execution (no README needed).

## Prerequisites
- Ubuntu 22.04/24.04 VM (VPS, WSL2, or local VM)
- SSH access + sudo

## Clone
```bash
git clone https://github.com/shubhu-io/linux-nginx-server.git
cd linux-nginx-server
```

## Run (on the Ubuntu server)
```bash
sudo bash scripts/install-server.sh
sudo bash scripts/setup.sh
sudo cp systemd/hello-web.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now hello-web
```

## Verify
```bash
curl -I http://127.0.0.1/
bash tests/smoke-test.sh
bash scripts/healthcheck.sh http://127.0.0.1/
```

## Cleanup
```bash
sudo systemctl disable --now hello-web
sudo rm /etc/nginx/sites-enabled/hello-site
sudo systemctl reload nginx
```
