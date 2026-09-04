# Deployment

```bash
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --check --diff
ansible-playbook -i inventory/hosts.ini playbooks/site.yml
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --limit web1 --tags nginx
```

Verify on target:
```bash
ssh ubuntu@<host> "curl -I http://127.0.0.1/; systemctl status nginx hello-web --no-pager; sudo ufw status verbose"
```
