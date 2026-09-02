# Screenshots

This folder is intentionally **empty** — no fabricated images are included.

Capture real screenshots as you run the demo and drop them here (e.g. `01-blue-ocean.png`).
Below is exactly what to capture and how.

| File name (suggested) | What to capture | How |
| --- | --- | --- |
| `01-jenkins-dashboard.png` | Jenkins dashboard after the first successful build | Open http://localhost:8080 → screenshot the dashboard |
| `02-blue-ocean-run.png` | Blue Ocean visual run of the pipeline | From the job page click **Open Blue Ocean** → screenshot the pipeline stages (all green) |
| `03-console-success.png` | Console output showing a successful build | Job → *Build #N* → **Console Output** → scroll to `Finished: SUCCESS` → screenshot |
| `04-console-failure.png` | Console output showing a failing build | Flip `EXPECTED` to `fail` in `app/test/example-failing.js`, commit & rebuild → screenshot the red **Test** stage / `Finished: FAILURE` |
| `05-curl-health.png` | Health endpoint returns `{"status":"ok"}` | Run `curl http://localhost:8090/health` in a terminal → screenshot the output |

## How to take the screenshots (Windows)

- Win+Shift+S (Snipping Tool) to capture a region, then save as PNG into this folder.
- macOS: Cmd+Shift+4. Linux: `gnome-screenshot -a`.

## How to take the screenshots (terminal)

```bash
# Linux/macOS/Git Bash - save terminal captures too
curl -s http://localhost:8090/health
```
