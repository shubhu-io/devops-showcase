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

## Deploy Your Own App (3 changes)

**1. Use your GitHub repo:**
```bash
# fork https://github.com/shubhu-io/ansible-server-configuration
git clone https://github.com/<YOUR_USERNAME>/ansible-server-configuration.git
cd ansible-server-configuration
git remote set-url origin https://github.com/<YOUR_USERNAME>/ansible-server-configuration.git
```

**2. Point Ansible to your server + your site:**
```bash
nano inventory/hosts.ini
# web1 ansible_host=<YOUR_SERVER_IP> ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/your-key.pem
# edit the inline HTML in roles/nginx/tasks/main.yml or add your own files/template
nano roles/nginx/tasks/main.yml
# optional: change vars in playbooks/site.yml -> web_user, web_root, server_name
```

**3. Deploy:** `ansible-playbook -i inventory/hosts.ini playbooks/site.yml`

