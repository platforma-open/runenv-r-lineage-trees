#!/usr/bin/env bash
# Copies binaries/<platform>/ into rdist/<platform>/bin and unpacks IgPhyML's hotspot tables.
# Usage: install-binaries.sh [platform...]   (default: those present under rdist/)
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
bins="$root/binaries"
cache="${LINEAGE_TREES_BIN_CACHE:-$here/.cache}"
. "$here/pins.sh"

platforms=("$@")
if [ ${#platforms[@]} -eq 0 ]; then
  for p in "${ALL_PLATFORMS[@]}"; do [ -d "$root/rdist/$p" ] && platforms+=("$p"); done
fi
[ ${#platforms[@]} -gt 0 ] || { echo "install-binaries: no platform under rdist/" >&2; exit 1; }

stamp="$(build_stamp "$here")"
for p in "${platforms[@]}"; do
  x="$(exe "$p")"
  for b in "${PROGRAMS[@]}"; do
    f="$bins/$p/$b$x"
    [ -f "$f" ] || { echo "install-binaries: $f is missing; run tools/binaries/build-binaries.sh $p" >&2; exit 1; }
    # An LFS checkout that did not fetch leaves a small text pointer in place.
    if head -c 40 "$f" | grep -q "git-lfs"; then
      echo "install-binaries: $f is a Git LFS pointer; check out with LFS (git lfs pull)" >&2; exit 1
    fi
  done
  [ "$(cat "$bins/$p/.stamp" 2>/dev/null)" = "$stamp" ] || {
    echo "install-binaries: binaries/$p was built from other pins or build files; run tools/binaries/build-binaries.sh $p and commit binaries/" >&2
    exit 1; }
done

fetch igphyml.tar.gz "$cache"
motifs="$(mktemp -d "${TMPDIR:-/tmp}/igphyml-motifs.XXXXXX")"
trap 'rm -rf "$motifs"' EXIT
tar -zxf "$cache/igphyml.tar.gz" -C "$motifs" --strip-components 3 igphyml-2.0.0/src/motifs

for p in "${platforms[@]}"; do
  x="$(exe "$p")"
  [ -d "$root/rdist/$p/bin" ] || { echo "install-binaries: rdist/$p/bin is missing" >&2; exit 1; }
  for b in "${PROGRAMS[@]}"; do
    cp "$bins/$p/$b$x" "$root/rdist/$p/bin/$b$x"
    chmod 755 "$root/rdist/$p/bin/$b$x"
  done
  rm -rf "$root/rdist/$p/share/igphyml/motifs"
  mkdir -p "$root/rdist/$p/share/igphyml"
  cp -r "$motifs" "$root/rdist/$p/share/igphyml/motifs"
  chmod 755 "$root/rdist/$p/share/igphyml/motifs"
  echo "$p: installed into rdist"
done
