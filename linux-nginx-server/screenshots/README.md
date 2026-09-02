# Screenshots

> **Documented, not executed.** No screenshots in this folder are fabricated and none were taken for this deliverable. To produce real screenshots, run the exact commands below on your own Ubuntu 22.04/24.04 server and capture the output with your OS screenshot tool (or `sudo apt install scrot` on a server with a display).

## How to capture

Capture the full terminal window (or just the output) after each command. Save files with descriptive names, e.g. `01-nginx-version.png`. Keep them in this `screenshots/` folder with a link from this README.

## Commands and what to screenshot

| # | Command | What the screenshot should show |
|---|---|---|
| 1 | `nginx -v` | `nginx version: nginx/1.24.0` (or similar) — proves Nginx is installed |
| 2 | `systemctl status nginx --no-pager` | `● nginx.service - A high performance web server` … `Active: active (running)` |
| 3 | `curl -I http://127.0.0.1/` | `HTTP/1.1 200 OK`, `Server: nginx/…`, `Content-Type: text/html` |
| 4 | Browser: `http://<SERVER_IP>/` | The hello page with heading and footer rendered in a real browser |
| 5 | `curl -s http://127.0.0.1/ \| head -n 5` | The first HTML lines of `index.html` served over HTTP |
| 6 | `sudo ufw status verbose` | `Status: active`, `Default: deny (incoming)`, rules for `22/tcp (OpenSSH)` and `80,443/tcp (Nginx Full)` |
| 7 | `journalctl -u nginx -n 20 --no-pager` | Recent Nginx unit log lines |
| 8 | `bash tests/smoke-test.sh` | `PASS: …` output (and a second screenshot of the FAIL output is optional) |
| 9 | `sudo nginx -t` | `syntax is ok` / `test is successful` |
| 10 | `ss -ltnp \| grep -E ':80|:3000'` | Nginx listening on `:80` and the backend on `127.0.0.1:3000` |

## What to avoid

- Do not screenshot anything containing private keys, tokens, or IPs you want to keep private — blur them or use `127.0.0.1`.
- Do not include browser windows that show unrelated personal data.

## Suggested checklist before uploading screenshots

- [ ] Timestamps visible or the output is clearly from your server
- [ ] All commands run in the order documented in `docs/setup.md`
- [ ] Nothing private is visible
