# Security

- inventory/hosts.ini gitignored; only hosts.ini.example committed.
- *.pem/*.key ignored, Ansible Vault for real secrets.
- become scoped to play, handlers restrict restarts.
- ufw default deny, allow only OpenSSH + Nginx Full.
- systemd NoNewPrivileges, PrivateTmp, ProtectSystem, server_tokens off.
- host_key_checking False in ansible.cfg for lab; production should enable.
