# Troubleshooting

## `ERROR! the role 'common' was not found`
- Check `ansible.cfg` has `roles_path = roles` and you run from repo root: `ansible-playbook -i inventory/hosts.ini playbooks/site.yml`

## `FAILED! => Missing sudo password`
- Add `-K` or configure passwordless sudo on target: `ansible-playbook -i ... playbooks/site.yml -K`

## `permission denied` on SSH
- Verify `inventory/hosts.ini` `ansible_ssh_private_key_file` and `chmod 400` on key, `ansible_host` correct.

## `nginx -t` fails
- Check templated `/etc/nginx/sites-available/hello-site` on target: `nginx -t` output, `server_name`/`web_root` vars.

## No change on second run?
- Expected — roles are idempotent. Use `--check --diff` to preview.
