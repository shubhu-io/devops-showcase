# Ansible Server Configuration

Idempotent Ansible automation to provision a secure Ubuntu + Nginx web server — ufw, web user, static site, and systemd demo backend — from a single `ansible-playbook` run.

## Overview

This repository codifies manual Ubuntu + Nginx provisioning steps into Ansible: an inventory, a playbook (`site.yml`), and three roles (`common`, `nginx`, `app`). Applied to a fresh Ubuntu 22.04/24.04 host, it opens only SSH and HTTP, creates a dedicated `webuser`, deploys the site, templates Nginx, and ensures the backend service is running — all idempotently.

**Real-world problem it solves:** shell scripts drift and are hard to audit; Ansible provides declarative, reusable, check-mode-friendly configuration.

```
ansible-playbook → common (apt, user, ufw) → nginx (site + reload) → app (systemd unit)
```

## Architecture

```mermaid
flowchart LR
    C[Control Node] -->|SSH| H[Ubuntu Hosts: web]
    H --> UFW[ufw 22,80,443]
    H --> NG[Nginx :80]
    NG --> ROOT[/var/www/hello-web]
    H --> SVC[hello-web.service :3000]
```

Roles are ordered `common → nginx → app`; handlers `Reload nginx` and `Restart hello-web` fire only on change.

## Technologies

| Technology | Purpose |
|---|---|
| Ansible | Configuration management |
| Ubuntu 22.04/24.04 | Target OS |
| Nginx | Web server / reverse proxy |
| systemd | Service supervision |
| ufw | Firewall |
| Jinja2 | Templates (`hello-site.conf.j2`) |

## Features

- **Idempotent** `apt`, `user`, `file`, `template`, `service` tasks (`changed_when` where needed)
- **Handlers** — Nginx reloads only when config changes; systemd restart only when unit changes
- **Security** — `NoNewPrivileges`, `PrivateTmp`, `ProtectSystem` in systemd template; `server_tokens off` + headers in Nginx template
- **Templated** `server_name`, `web_root`, `web_user` vars; `ansible.cfg` disables `retry_files`
- **Check mode friendly** — `nginx -t` validation before reload

## Prerequisites

- Control node: Ansible 2.14+, Python 3.10+, `community.general` collection (`ansible-galaxy collection install community.general`)
- Managed node: Ubuntu 22.04/24.04, SSH reachable, `sudo` without password (or `-K`)
- Inventory `inventory/hosts.ini` (copy from `hosts.ini.example`)

## Setup

```bash
git clone <this-repo> && cd ansible-server-configuration
cp inventory/hosts.ini.example inventory/hosts.ini
# edit hosts.ini: set ansible_host, ansible_user, ansible_ssh_private_key_file

ansible-galaxy collection install community.general
ansible --version
ansible-inventory -i inventory/hosts.ini --list | head
```

## Configuration

| File | Purpose |
|---|---|
| `ansible.cfg` | `inventory`, `host_key_checking False`, `yaml` callback |
| `inventory/hosts.ini` | `[web]` hosts; `ansible_user=ubuntu`, key path (gitignored) |
| `playbooks/site.yml` | Top play: `hosts: web`, `become: true`, vars `web_user/web_root/server_name`, roles + handlers |
| `roles/common/tasks/main.yml` | apt cache, base pkgs, user, ufw Allow + enable |
| `roles/nginx/tasks/main.yml` | Nginx install, web root, site template, `nginx -t`, service |
| `roles/app/tasks/main.yml` | Systemd unit template, daemon-reload, enable/start |

Vars can be overridden: `ansible-playbook -i inventory/hosts.ini playbooks/site.yml -e web_user=appuser`.

## Deployment

```bash
# Dry-run
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --check --diff

# Apply
ansible-playbook -i inventory/hosts.ini playbooks/site.yml

# Limit to one host/role for testing
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --limit web1 --tags nginx
```

Verify on target:

```bash
ssh ubuntu@$(awk '/ansible_host/ {print $2}' inventory/hosts.ini | cut -d= -f2)
curl -I http://127.0.0.1/   # 200
systemctl status nginx hello-web --no-pager
sudo ufw status verbose
```

## Testing

```bash
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --syntax-check
ansible-lint playbooks/site.yml  # if installed
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --check  # idempotence second run should show 0 changed
```

## Monitoring / Logging

- Ansible verbose: `-v` / `-vvv`, `stdout_callback = yaml`
- On host: `journalctl -u hello-web`, `/var/log/nginx/*`

## Security

- `inventory/hosts.ini` gitignored; only `hosts.ini.example` with placeholder IP committed
- No secrets in repo; `*.pem`/`*.key` ignored
- `become: true` scoped to play; handlers restrict restarts
- ufw default deny, allow only OpenSSH + Nginx Full

## Cleanup

```bash
ansible -i inventory/hosts.ini web -b -m systemd -a "name=hello-web state=stopped" 2>/dev/null || true
ansible -i inventory/hosts.ini web -b -m file -a "path=/var/www/hello-web state=absent"
ansible -i inventory/hosts.ini web -b -m file -a "path=/etc/nginx/sites-enabled/hello-site state=absent"
```

Or `ssh` and `sudo rm /etc/nginx/sites-enabled/hello-site && sudo systemctl reload nginx`.

## Project Structure

```
ansible-server-configuration/
├── README.md
├── .gitignore
├── ansible.cfg
├── inventory/
│   ├── hosts.ini.example
│   └── hosts.ini         # gitignored
├── playbooks/
│   └── site.yml
├── roles/
│   ├── common/tasks/main.yml
│   ├── nginx/{tasks/main.yml,templates/hello-site.conf.j2}
│   └── app/{tasks/main.yml,templates/hello-web.service.j2}
├── docs/
└── diagrams/
```

## Future Improvements

- Molecule + Docker driver for local role testing
- Ansible Vault for encrypted secrets, `ansible-lint` in CI
- `geerlingguy` roles for hardened SSH/Nginx, `ufw` to `firewalld` variant
