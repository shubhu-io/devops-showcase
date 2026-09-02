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

## Deploy Your Own App (3 changes)

**1. Use your GitHub repo (replace the clone link everywhere):**
```bash
# fork https://github.com/shubhu-io/linux-nginx-server on GitHub, then:
git clone https://github.com/<YOUR_USERNAME>/linux-nginx-server.git
cd linux-nginx-server
# point local git to your repo (if you cloned the template):
git remote set-url origin https://github.com/<YOUR_USERNAME>/linux-nginx-server.git
git push -u origin master
```

**2. Put your app in `web/` and/or edit `nginx/hello-site.conf`:**
```bash
# edit your homepage
nano web/index.html
# change server_name / root if needed
nano nginx/hello-site.conf
# test
sudo nginx -t && sudo systemctl reload nginx
```

**3. Deploy:**
```bash
sudo bash scripts/deploy-site.sh
curl -I http://YOUR_SERVER_IP/
```
