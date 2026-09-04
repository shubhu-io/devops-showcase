# Architecture Decisions

- Ansible over shell scripts: declarative, idempotent, check-mode friendly, auditable.
- Roles common/nginx/app for separation of concerns and reuse.
- community.general.ufw vs firewalld: ufw is default on Ubuntu, simpler.
- Handlers for nginx reload / systemd restart only on change.
- Jinja2 templates for server_name/web_root/web_user vars.
- ansible.cfg host_key_checking False for lab convenience; enable in prod.
