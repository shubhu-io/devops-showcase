# Commands Cheat Sheet

> **Documented, not executed** — these commands are real and were written for an Ubuntu 22.04/24.04 server; they were not executed on a live machine for this deliverable.

Every command below follows the same format:

```
COMMAND
↓ PURPOSE
↓ WHAT IT DOES
↓ EXPECTED OUTPUT
↓ COMMON ERROR
↓ FIX
```

---

## 1. `ls -la`

`ls -la`

↓ PURPOSE
List all files (including hidden) in the current directory with detailed metadata.

↓ WHAT IT DOES
`-l` prints the long format (permissions, owner, group, size, date). `-a` includes dotfiles. The first column encodes the type and permission bits, e.g. `drwxr-xr-x`.

↓ EXPECTED OUTPUT
```
total 20
drwxr-xr-x 4 webuser webuser 4096 Aug 12 09:00 .
-rw-r--r-- 1 webuser webuser  512 Aug 12 09:00 index.html
```

↓ COMMON ERROR
`ls: cannot access 'missing': No such file or directory`

↓ FIX
Confirm the path with `pwd`; use tab-completion or `ls .` / `ls ..` to find the right location.

---

## 2. `cd`

`cd /etc/nginx`

↓ PURPOSE
Change the current working directory.

↓ WHAT IT DOES
Moves the shell into the given directory, so relative paths resolve from there. `cd` with no argument returns to the home directory.

↓ EXPECTED OUTPUT
No output on success; the prompt path changes.

↓ COMMON ERROR
`bash: cd: /etc/ngin: No such file or directory`

↓ FIX
Typo — retype with tab-completion (`cd /etc/ng<TAB>`).

---

## 3. `cp`

`cp -r web/ /var/www/hello-web/`

↓ PURPOSE
Copy files or directories.

↓ WHAT IT DOES
Copies the source to the destination. `-r` copies directories recursively. `-p` preserves permissions/ownership/timestamps.

↓ EXPECTED OUTPUT
No output on success (silent). Add `-v` for verbose file-by-file listing.

↓ COMMON ERROR
`cp: cannot stat 'web/': No such file or directory`

↓ FIX
Run `cp` from the repo root (where `web/` lives) or use an absolute path.

---

## 4. `mv`

`mv hello-site.conf hello-site.conf.bak`

↓ PURPOSE
Move or rename a file.

↓ WHAT IT DOES
Renames within the same filesystem or relocates across paths. Unlike `cp`, the source disappears.

↓ EXPECTED OUTPUT
No output on success.

↓ COMMON ERROR
`mv: cannot move 'x' to 'y': Permission denied`

↓ FIX
The target directory is not writable by you — retry with `sudo`.

---

## 5. `chmod`

`chmod 755 scripts/setup.sh`

↓ PURPOSE
Change file permissions (read/write/execute for user/group/others).

↓ WHAT IT DOES
`755` = owner `rwx`, group `r-x`, others `r-x`; `644` = owner `rw-`, others `r--`. `+x` / `-x` toggle execute without numbers.

↓ EXPECTED OUTPUT
No output on success.

↓ COMMON ERROR
`chmod: changing permissions of 'x': Operation not permitted`

↓ FIX
You are not the owner — use `sudo chmod`.

---

## 6. `chown`

`chown -R webuser:webuser /var/www/hello-web`

↓ PURPOSE
Change file ownership (user and/or group).

↓ WHAT IT DOES
`-R` recurses into subdirectories. `user:group` sets both. Nginx then serves files owned by `webuser` instead of root.

↓ EXPECTED OUTPUT
No output on success.

↓ COMMON ERROR
`chown: changing ownership of 'x': Operation not permitted`

↓ FIX
`chown` requires root — prefix with `sudo`.

---

## 7. `useradd`

`sudo useradd -m -s /bin/bash webuser`

↓ PURPOSE
Create a new user account.

↓ WHAT IT DOES
`-m` creates a home directory, `-s /bin/bash` sets the login shell. The user is created with no password (locked) until `passwd` sets one.

↓ EXPECTED OUTPUT
No output on success.

↓ COMMON ERROR
`useradd: user 'webuser' already exists`

↓ FIX
The user was already created (scripts are idempotent) — check with `id webuser` and continue.

---

## 8. `usermod`

`sudo usermod -aG sudo deployer`

↓ PURPOSE
Modify an existing user's group memberships or shell.

↓ WHAT IT DOES
`-aG` appends (`-a`) the group(s) (`-G`) without removing existing memberships. This grants `deployer` sudo powers. `-s` changes the login shell.

↓ EXPECTED OUTPUT
No output on success.

↓ COMMON ERROR
`usermod: group 'sudo' does not exist`

↓ FIX
Wrong distro/group name — on some systems the admin group is `wheel`. Check with `getent group sudo wheel`.

---

## 9. `passwd`

`passwd deployer`

↓ PURPOSE
Set or change a user's password.

↓ WHAT IT DOES
Prompts for the new password twice (input is hidden), hashes it, and stores it. Root can change any user's password; regular users only their own.

↓ EXPECTED OUTPUT
```
New password:
Retype new password:
passwd: password updated successfully
```

↓ COMMON ERROR
`passwd: Authentication token manipulation error`

↓ FIX
Permission problem — run with `sudo`, or the password policy rejected a weak value (choose 12+ characters).

---

## 10. `ssh`

`ssh -i ~/.ssh/id_ed25519 deployer@SERVER_IP`

↓ PURPOSE
Open an encrypted remote shell.

↓ WHAT IT DOES
Authenticates to the remote host using your key (or password if enabled), then runs your shell commands remotely. `-i` selects a specific private key, `-p PORT` sets a non-default port.

↓ EXPECTED OUTPUT
```
Welcome to Ubuntu 24.04 LTS (GNU/Linux ...)
Last login: ...
deployer@server:~$
```

↓ COMMON ERROR
`ssh: connect to host SERVER_IP port 22: Connection refused`

↓ FIX
SSH is not running, or ufw blocks 22 — connect via provider console, `sudo systemctl enable --now ssh`, `sudo ufw allow OpenSSH`.

---

## 11. `scp`

`scp -r linux-nginx-server deployer@SERVER_IP:/home/deployer/`

↓ PURPOSE
Copy files to/from a remote host over SSH.

↓ WHAT IT DOES
`-r` copies directories recursively. Runs entirely inside the SSH session, so it uses the same auth (key) and is encrypted end-to-end.

↓ EXPECTED OUTPUT
```
index.html                                      100%  512     0.5KB/s   00:00
```

↓ COMMON ERROR
`scp: /home/deployer/linux-nginx-server: No such file or directory`

↓ FIX
The parent directory does not exist — create it with `ssh deployer@SERVER_IP 'mkdir -p /home/deployer'` first.

---

## 12. `systemctl`

`sudo systemctl reload nginx`

↓ PURPOSE
Manage systemd services (start, stop, restart, reload, enable, status).

↓ WHAT IT DOES
`reload` re-reads config without dropping connections; `restart` stops and starts; `status` shows state + recent logs; `enable --now` starts now and at boot; `is-active --quiet` is script-friendly (exit 0 if running).

↓ EXPECTED OUTPUT
```
nginx.service - A high performance web server
     Loaded: loaded (/lib/systemd/system/nginx.service; enabled; vendor preset: enabled)
     Active: active (running)
```

↓ COMMON ERROR
`Failed to reload nginx.service: Unit nginx.service not found.`

↓ FIX
The unit name is wrong, or nginx is not installed — `apt install -y nginx` then `systemctl daemon-reload`.

---

## 13. `journalctl`

`journalctl -u nginx -n 50 --no-pager`

↓ PURPOSE
Read logs written by systemd for a specific unit.

↓ WHAT IT DOES
`-u` filters by unit, `-n 50` shows the last 50 lines, `--no-pager` prints to stdout (good for scripts). `-f` follows live like `tail -f`.

↓ EXPECTED OUTPUT
```
Aug 12 09:00:01 server nginx[1234]: configuration file /etc/nginx/nginx.conf test is successful
```

↓ COMMON ERROR
`journalctl: Unknown machine id or directory ...`

↓ FIX
journald has no data (e.g. in a minimal container) — check `/var/log/nginx/*.log` instead.

---

## 14. `apt update`

`sudo apt update`

↓ PURPOSE
Refresh the package index from the configured repositories.

↓ WHAT IT DOES
Downloads package metadata (not the packages) so `apt install` can resolve available versions. Run it before installing anything on a fresh box.

↓ EXPECTED OUTPUT
```
Hit:1 http://archive.ubuntu.com/ubuntu noble InRelease
Reading package lists... Done
```

↓ COMMON ERROR
`E: Could not resolve 'archive.ubuntu.com'`

↓ FIX
DNS/network problem — check `ping 8.8.8.8` and `/etc/resolv.conf`.

---

## 15. `curl`

`curl -I http://127.0.0.1/`

↓ PURPOSE
Transfer data from/to a URL; the workhorse of HTTP testing.

↓ WHAT IT DOES
`-I` fetches headers only; `-sS` is silent-but-shows-errors; `-o /dev/null -w '%{http_code}'` prints just the status code; `-f` makes non-2xx statuses a shell failure (exit code ≠ 0). Useful for scripts.

↓ EXPECTED OUTPUT
```
HTTP/1.1 200 OK
Server: nginx/1.24.0
Content-Type: text/html
```

↓ COMMON ERROR
`curl: (7) Failed to connect to 127.0.0.1 port 80: Connection refused`

↓ FIX
Nothing is listening on port 80 — `sudo systemctl status nginx`, check error logs.

---

## 16. `nginx -t`

`sudo nginx -t`

↓ PURPOSE
Test the Nginx configuration for syntax and semantic errors.

↓ WHAT IT DOES
Parses `nginx.conf`, all `include`d server blocks, and validates each one. Prints the file+line of any problem. Does **not** reload or restart anything.

↓ EXPECTED OUTPUT
```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

↓ COMMON ERROR
`nginx: [emerg] "root" directive is duplicate in /etc/nginx/sites-enabled/hello-site:3`

↓ FIX
A duplicate directive or conflicting server block — run `nginx -t` inside the config file to find the line, fix it, re-test.

---

## 17. `ufw status`

`sudo ufw status verbose`

↓ PURPOSE
Show the current firewall rules and default policy.

↓ WHAT IT DOES
Lists each rule with its action and (with `verbose`) the default incoming/outgoing policy and logging level. `ufw allow/deny` modifies rules; `ufw enable` activates the firewall.

↓ EXPECTED OUTPUT
```
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)
To                         Action      From
--                         ------      ----
22/tcp (OpenSSH)           ALLOW IN    Anywhere
80,443/tcp (Nginx Full)    ALLOW IN    Anywhere
```

↓ COMMON ERROR
`ERROR: Couldn't determine iptables version`

↓ FIX
The kernel/module is missing (common in some containers) — ensure you run on a full Ubuntu server, or use `ufw` alternatives (`nftables`) in minimal environments.
