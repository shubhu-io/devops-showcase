# Commands

```bash
ansible-galaxy collection install community.general
ansible --version
ansible-inventory -i inventory/hosts.ini --list | head
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --syntax-check
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --check --diff
ansible-playbook -i inventory/hosts.ini playbooks/site.yml
ansible -i inventory/hosts.ini web -m ping
ansible -i inventory/hosts.ini web -a "systemctl status nginx --no-pager"
```
