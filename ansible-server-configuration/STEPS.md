# Steps — ansible-server-configuration

Copy-paste execution.

## Prerequisites
- Ansible 2.14+, Python 3.10+
- Ubuntu target reachable via SSH

## Clone
```bash
git clone https://github.com/shubhu-io/ansible-server-configuration.git
cd ansible-server-configuration
```

## Run
```bash
cp inventory/hosts.ini.example inventory/hosts.ini
# edit hosts.ini with your server IP and key
ansible-galaxy collection install community.general
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --check --diff
ansible-playbook -i inventory/hosts.ini playbooks/site.yml
curl http://YOUR_SERVER_IP/
```

## Cleanup
```bash
ansible -i inventory/hosts.ini web -b -m file -a "path=/var/www/hello-web state=absent"
```
