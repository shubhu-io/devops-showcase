# Screenshots — ansible-server-configuration

Capture (do not fabricate):

1. `ansible -i inventory/hosts.ini web -m ping`
2. `ansible-playbook -i inventory/hosts.ini playbooks/site.yml --check --diff`
3. `curl -I http://YOUR_SERVER_IP/` after apply
4. `systemctl status nginx hello-web` on target
