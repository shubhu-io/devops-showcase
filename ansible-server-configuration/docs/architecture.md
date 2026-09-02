# Architecture — ansible-server-configuration

## Overview
Control node runs `ansible-playbook` over SSH to configure `web` hosts. Roles are applied in order `common → nginx → app`.

## Components
- **Control node:** where you run `ansible-playbook` (your laptop/WSL)
- **Inventory `inventory/hosts.ini`:** group `[web]` with `ansible_host`, `ansible_user`, `ansible_ssh_private_key_file`
- **Playbook `playbooks/site.yml`:** `hosts: web`, `become: true`, vars `web_user/web_root/server_name`, roles + handlers
- **Roles:**
  - `common` — apt update, base pkgs, user, ufw
  - `nginx` — nginx pkg, web root, templated `hello-site.conf`, `nginx -t`, service
  - `app` — templated `hello-web.service`, daemon-reload, service

## Flow
```
ansible-playbook → SSH → apt → user → ufw → nginx → template → validate → service → systemd
```

Handlers `Reload nginx` and `Restart hello-web` fire only on change, keeping runs idempotent.

## Security
- ufw default deny, allow OpenSSH + Nginx Full
- systemd hardening (`NoNewPrivileges`, `PrivateTmp`, `ProtectSystem`)
- Nginx `server_tokens off`, headers
