#!/usr/bin/env bash
# npm run build: R with the locked packages, the tree builders, then the package.
# On Linux pl-r-builder needs Rocky Linux 8: it installs with sudo dnf, and the glibc it
# builds against (2.28) is the oldest the environment runs on. Any other Linux reruns
# this script in a Rocky 8 container, with the host's node and this checkout mounted.
set -euo pipefail
cd "$(dirname "$0")/.."

ROCKY_IMAGE="rockylinux/rockylinux:8.10@sha256:e8a49c5403b687db05d4d67333fa45808fbe74f36e683cec7abb1f7d0f2338c6"

if [ "$(uname -s)" = Linux ] && ! grep -qs 'platform:el8' /etc/os-release; then
  command -v docker >/dev/null || { echo "build: Docker is required to build on non-Rocky-8 Linux" >&2; exit 1; }
  envs=()
  for v in $(compgen -e | grep -E '^(CI|RUNNER_DEBUG|PL_[A-Z_]+)$' || true); do envs+=(-e "$v"); done
  # ponytail: no ccache in the container, so CI reruns compile R and all packages again;
  # mount the host's ccache dir here if reruns get too slow.
  exec docker run --rm "${envs[@]}" \
    -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
    -v "$PWD:/w" -w /w \
    -v "$(readlink -f "$(command -v node)"):/usr/local/bin/node:ro" \
    "$ROCKY_IMAGE" \
    bash -c 'set -euo pipefail
      # Hand the results back to the caller even when a step fails.
      trap "chown -R $HOST_UID:$HOST_GID /w" EXIT
      # What the old Rocky 8 runners had preinstalled and pl-r-builder does not install:
      # cmake for fs, and the image libraries for ragg and textshaping.
      dnf -y -q install sudo dnf-plugins-core
      dnf config-manager --set-enabled powertools
      dnf -y -q install cmake freetype-devel libtiff-devel libjpeg-turbo-devel libwebp-devel \
        harfbuzz-devel fribidi-devel
      PATH="/w/node_modules/.bin:$PATH" bash tools/build.sh'
fi

pl-r-builder
bash tools/binaries/install-binaries.sh
pl-pkg build
