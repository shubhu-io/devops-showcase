# Setup — ansible-server-configuration

## Prerequisites
- Control: Ansible 2.14+, Python 3.10+, collection `community.general`
- Target: Ubuntu 22.04/24.04, SSH + sudo (passwordless or `-K`)

## Steps
```bash
git clone https://github.com/shubhu-io/ansible-server-configuration.git
cd ansible-server-configuration
cp inventory/hosts.ini.example inventory/hosts.ini
# edit hosts.ini
ansible-galaxy collection install community.general
ansible --version
ansible-inventory -i inventory/hosts.ini --list
ansible -i inventory/hosts.ini web -m ping
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --check --diff
ansible-playbook -i inventory/hosts.ini playbooks/site.yml
curl http://YOUR_SERVER_IP/
```
