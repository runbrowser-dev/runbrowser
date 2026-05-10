# runbrowser/chromium: a Chromium image tuned for headless service use.
#
# Why this image exists: getting Chromium to run reliably under a CDP
# debugger inside a container has a small handful of non-obvious gotchas
# (font Recommends silently dropped by --no-install-recommends, recent
# Chromium ignoring --remote-debugging-address=0.0.0.0, blank screenshots
# from /dev/shm exhaustion, zombie children when chromium spawns helpers).
# This image bakes in the answers we've collected so you don't have to
# rediscover them.

FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        chromium \
        chromium-sandbox \
        ca-certificates \
        fonts-liberation \
        fonts-liberation2 \
        fonts-noto-core \
        fonts-noto-color-emoji \
        fonts-noto-cjk \
        fonts-noto-mono \
        libnss3 \
        libxss1 \
        libxtst6 \
        socat \
        tini \
        wget \
    && rm -rf /var/lib/apt/lists/*

# Why these packages:
#   fonts-liberation, fonts-liberation2  metric-equivalents to Arial/Times/Courier
#   fonts-noto-core    Sans/Serif covering ~100 scripts (Arabic, Hebrew, Devanagari,
#                      Thai, Georgian, Armenian, etc.). Pulled explicitly because
#                      the `fonts-noto` meta-package lists script-specific fonts as
#                      Recommends, which --no-install-recommends drops, leaving
#                      the meta-package's metadata but no actual font files.
#   fonts-noto-cjk           Chinese / Japanese / Korean
#   fonts-noto-color-emoji   colored emoji (otherwise text-codepoint boxes)
#   fonts-noto-mono          monospace fallback for code-on-page rendering
#   socat                    bridges 0.0.0.0:9222 to chrome's loopback :9223 (see CMD)
#   tini                     reaps zombie children (chromium spawns many)

RUN groupadd -r chrome && useradd -r -g chrome -G audio,video chrome \
    && mkdir -p /home/chrome/Downloads /tmp/chrome-data \
    && chown -R chrome:chrome /home/chrome /tmp/chrome-data

USER chrome
WORKDIR /home/chrome

EXPOSE 9222

# OCI labels for Docker Hub / GHCR metadata.
LABEL org.opencontainers.image.title="runbrowser/chromium" \
      org.opencontainers.image.description="Chromium tuned for headless service use: fonts, DNS-rebind, socat bridge, init reaper, no surprises." \
      org.opencontainers.image.url="https://runbrowser.dev" \
      org.opencontainers.image.source="https://github.com/runbrowser-dev/runbrowser" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="runbrowser"

# tini reaps zombies (chromium spawns many helper processes).
ENTRYPOINT ["/usr/bin/tini", "--"]

# Recent Chromium silently ignores --remote-debugging-address=0.0.0.0 and
# binds the debugger to 127.0.0.1 only. socat bridges :9222 on all
# interfaces to chrome's loopback :9223 so sibling containers (and the
# healthcheck) can reach it. Drop this and the image binds loopback-only.
CMD ["/bin/sh", "-c", "socat TCP-LISTEN:9222,fork,reuseaddr TCP:127.0.0.1:9223 & exec /usr/bin/chromium --headless=new --no-sandbox --disable-dev-shm-usage --no-first-run --no-default-browser-check --remote-debugging-address=127.0.0.1 --remote-debugging-port=9223 --remote-allow-origins=* --user-data-dir=/tmp/chrome-data"]
