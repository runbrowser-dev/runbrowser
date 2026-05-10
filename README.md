# runbrowser/chromium

[![License: MIT](badge)](LICENSE) [![Docker Pulls](badge)](dockerhub) [![Image Size](badge)](dockerhub)

A Chromium image tuned for headless service use. Drop-in for any process that drives a browser via CDP: Playwright, Puppeteer, raw WebSocket, your own gateway.

Available on Docker Hub and GHCR:

```bash
docker pull runbrowser/chromium                # Docker Hub
docker pull ghcr.io/runbrowser-dev/chromium    # GitHub Container Registry
```

```bash
docker run -d --rm --shm-size=2gb -p 9222:9222 runbrowser/chromium
```

That's it. CDP debugger is at `ws://localhost:9222`.

## Quickstart

```bash
# fastest path
docker run -d --rm --shm-size=2gb -p 9222:9222 runbrowser/chromium

# or with compose
git clone https://github.com/runbrowser-dev/runbrowser.git
cd runbrowser
docker compose up -d
curl http://localhost:9222/json/version
```

## Connecting from Playwright

```js
import { chromium } from 'playwright'
const browser = await chromium.connectOverCDP('http://localhost:9222')
const page = await browser.newPage()
await page.goto('https://example.com')
await page.screenshot({ path: 'out.png' })
await browser.close()
```

## Connecting from Puppeteer

```js
import puppeteer from 'puppeteer-core'
const browser = await puppeteer.connect({ browserURL: 'http://localhost:9222' })
const page = await browser.newPage()
await page.goto('https://example.com')
await browser.disconnect()
```

## What's actually inside

Putting Chromium in a container is easy. Putting Chromium in a container that *doesn't surprise you in production* takes a small handful of non-obvious decisions. They're all documented in the [Dockerfile](Dockerfile); here's the summary:

**Fonts** (~14 packages, ~150 MB).
- `fonts-noto-core` covers ~100 scripts: Latin, Cyrillic, Greek, Arabic, Hebrew, Devanagari, Thai, Georgian, Armenian, etc.
- `fonts-noto-cjk` adds Chinese, Japanese, Korean.
- `fonts-noto-color-emoji` makes emoji render in color instead of as text-codepoint boxes.
- `fonts-liberation` + `fonts-liberation2` are metric-equivalents of Arial / Times New Roman / Verdana / etc.
- The naive answer of `apt-get install --no-install-recommends fonts-noto` silently installs the metadata but no font files: Recommends are dropped, and the script-specific font subpackages are listed there. We pull `fonts-noto-core` explicitly. There's a smoke test in [`tests/fonts-test.html`](tests/fonts-test.html) covering 14 scripts so you can verify yourself.

**DNS-rebind workaround.**
- Recent Chromium ignores `--remote-debugging-address=0.0.0.0` and binds the debugger to `127.0.0.1` only. We bind chromium loopback-only on `:9223` and run `socat` as a TCP bridge from `0.0.0.0:9222` to `127.0.0.1:9223`. Drop the bridge and the debugger becomes unreachable from outside the container.
- Chromium also rejects HTTP requests whose `Host` header isn't `localhost` or an IP. If you proxy this image, set `Host: localhost:9222` on every upstream call.

**`/dev/shm` size.**
- The default 64 MB causes blank screenshots on full-page captures. Always run with `--shm-size=2gb` (or use the included `docker-compose.yml`).

**Init / zombie reaping.**
- Chromium spawns helper processes. Without an init reaper they accumulate. We use `tini` as ENTRYPOINT.

**Sandbox.**
- We pass `--no-sandbox` because container PID-namespace + user-namespace boundaries are typically the security boundary of choice. If you need Chromium's own sandbox layered on top, drop the flag and add the appropriate `seccomp` / `apparmor` profile.

## Configuration

| Surface | Default | Override |
|---|---|---|
| CDP port (host) | `9222` | `-p 9223:9222` |
| `/dev/shm` size | `2gb` (compose) | `--shm-size=4gb` for screenshot-heavy workloads |
| User-data dir | `/tmp/chrome-data` | rebuild with a different `--user-data-dir` |

## Why this exists

Most "headless Chromium in Docker" answers online are 80% of the way there but skip one of the gotchas above. There's room for a permissive, well-documented base image that hides nothing and explains what it does.

This image is the foundation that runbrowser, the [hosted browser-as-a-service](https://runbrowser.dev), runs on. If you want everything around it (auth, multi-tenancy, fleet lifecycle, stealth, billing, REST shortcuts), bring your own integration on top of this image or skip to the hosted service.

## License

[MIT](LICENSE). Use it for whatever, including commercial.

## Contributing

Issues and PRs welcome. Please run `tests/smoke.sh` against your change before opening a PR.

The smoke test brings the image up, hits `/json/version`, and tears down. For multi-script font verification, render `tests/fonts-test.html` through your favorite CDP client and eyeball each row.
