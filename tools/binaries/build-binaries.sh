#!/usr/bin/env bash
# Rebuilds binaries/<platform>/ in a pinned Debian container (needs Docker); commit the result.
# Usage: build-binaries.sh [--force] [platform...]   (default: all five; --force ignores stamps)
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
out="$root/binaries"
cache="${LINEAGE_TREES_BIN_CACHE:-$here/.cache}"
. "$here/pins.sh"

force=0
platforms=()
for a in "$@"; do
  case "$a" in
    --force) force=1 ;;
    *) printf '%s\n' "${ALL_PLATFORMS[@]}" | grep -qx -- "$a" || { echo "unknown argument: $a" >&2; exit 2; }
       platforms+=("$a") ;;
  esac
done
[ ${#platforms[@]} -gt 0 ] || platforms=("${ALL_PLATFORMS[@]}")

stamp="$(build_stamp "$here")"
todo=()
for p in "${platforms[@]}"; do
  up=1
  [ "$(cat "$out/$p/.stamp" 2>/dev/null)" = "$stamp" ] || up=0
  for b in "${PROGRAMS[@]}"; do [ -x "$out/$p/$b$(exe "$p")" ] || up=0; done
  if [ "$force" = 0 ] && [ "$up" = 1 ]; then echo "$p: up to date"; else todo+=("$p"); fi
done
[ ${#todo[@]} -gt 0 ] || exit 0

command -v docker >/dev/null || { echo "build-binaries: Docker is required to build ${todo[*]}" >&2; exit 1; }
for d in "${DOWNLOADS[@]}"; do fetch "${d%%|*}" "$cache"; done

# Build into a staging tree and move each platform in only once all succeeded.
stage="$(mktemp -d "${TMPDIR:-/tmp}/lineage-trees-bin.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
docker run --rm --platform linux/amd64 \
  -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
  -v "$cache:/src:ro" -v "$here:/tools:ro" -v "$stage:/out" \
  "$BASE_IMAGE" bash /tools/build-in-container.sh "${todo[@]}"

mkdir -p "$out"
for p in "${todo[@]}"; do
  rm -rf "$out/$p"
  mv "$stage/$p" "$out/$p"
  echo "$stamp" > "$out/$p/.stamp"
  echo "$p: built"
done
