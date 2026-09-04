# Screenshots

Capture:
- ansible-playbook --check --diff (changed=0 on 2nd run)
- ansible-playbook run (changed IDs)
- ssh target curl -I 200 and systemctl status nginx

```bash
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --check --diff
ansible-playbook -i inventory/hosts.ini playbooks/site.yml
ssh ubuntu@<host> "curl -I http://127.0.0.1/; systemctl status nginx --no-pager"
```
