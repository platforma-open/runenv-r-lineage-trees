#!/usr/bin/env bash
# Builds the native tree-building programs the lineage-trees Docker image
# installs, at the same versions, and puts them into each built platform of this
# environment, whose bin/ is on PATH for every R tool that runs in it:
#
#   rdist/<platform>/bin/{raxml-ng,FastTree,igphyml}
#   rdist/<platform>/share/igphyml/motifs/HTABLE_*   (IgPhyML's hotspot tables)
#
# Every download is pinned by sha256 and the compiling happens in a pinned
# debian:trixie container (GCC 14, as in the image), so the host needs only
# bash, curl and Docker.
# Linux binaries are static. A platform whose stamp matches these pins and
# scripts is skipped, so rerunning is cheap; --force rebuilds.
#
# Usage: build-binaries.sh [--force] [platform...]
#   platforms: linux-x64 linux-aarch64 macosx-x64 macosx-aarch64
#   (default: those present under rdist/, else all)
#   Windows is not built: raxml-ng has no Windows release or port.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
out="$root/binaries"
cache="${LINEAGE_TREES_BIN_CACHE:-$here/.cache}"

BASE_IMAGE="debian:trixie-slim@sha256:a99cfc517144bc59b1978475ec53b46ecabec7e43635402ee5b77cc54cd1b20a"
# name|url|sha256
DOWNLOADS=(
  "raxml-linux-x64.zip|https://github.com/amkozlov/raxml-ng/releases/download/2.0.3/raxml-ng_v2.0.3_linux_x86_64.zip|d660cebe2a083de6c20d9354968803b8fd10be206f625be2393997d0abe98105"
  "raxml-macos.zip|https://github.com/amkozlov/raxml-ng/releases/download/2.0.3/raxml-ng_v2.0.3_macos.zip|6dc678ba0202da10dfeb8a7e4718dec583b68339fdc912391fbe349c69a1c99e"
  "raxml-source.zip|https://github.com/amkozlov/raxml-ng/releases/download/2.0.3/raxml-ng_v2.0.3_source.zip|7cd3fa6b1de373777d688032c9ec6731078b67e6a812d7a1d779295d016843d2"
  "igphyml.tar.gz|https://github.com/immcantation/igphyml/archive/refs/tags/2.0.0.tar.gz|9a21f79a3e3c269933fd9ce476f66101ea7a16cedd479c62d4e09fe0f91d9d2e"
  # Byte-identical to Debian's fasttree 2.1.11 source, which the image installs.
  "FastTree.c|http://www.microbesonline.org/fasttree/FastTree-2.1.11.c|9026ae550307374be92913d3098f8d44187d30bea07902b9dcbfb123eaa2050f"
  "zig.tar.xz|https://ziglang.org/download/0.14.1/zig-x86_64-linux-0.14.1.tar.xz|24aeeec8af16c381934a6cd7d95c807a8cb2cf7df9fa40d359aa884195c4716c"
)
ALL_PLATFORMS=(linux-x64 linux-aarch64 macosx-x64 macosx-aarch64)

force=0
platforms=()
for a in "$@"; do
  case "$a" in
    --force) force=1 ;;
    linux-x64|linux-aarch64|macosx-x64|macosx-aarch64) platforms+=("$a") ;;
    windows-x64) echo "windows-x64 is not supported: raxml-ng has no Windows build" >&2; exit 2 ;;
    *) echo "unknown argument: $a" >&2; exit 2 ;;
  esac
done
if [ ${#platforms[@]} -eq 0 ]; then
  for p in "${ALL_PLATFORMS[@]}"; do [ -d "$root/rdist/$p" ] && platforms+=("$p"); done
fi
[ ${#platforms[@]} -gt 0 ] || platforms=("${ALL_PLATFORMS[@]}")

# Copies built programs into the environment's platforms that exist.
install_into_rdist() {
  for p in "${platforms[@]}"; do
    [ -d "$root/rdist/$p/bin" ] || continue
    cp "$out/$p/raxml-ng" "$out/$p/FastTree" "$out/$p/igphyml" "$root/rdist/$p/bin/"
    mkdir -p "$root/rdist/$p/share/igphyml"
    rm -rf "$root/rdist/$p/share/igphyml/motifs"
    cp -r "$out/igphyml-motifs" "$root/rdist/$p/share/igphyml/motifs"
    echo "$p: installed into rdist"
  done
}

sha256() { if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d' ' -f1; }

# What a platform's binaries are a function of.
stamp="$(printf '%s\n' "$BASE_IMAGE" "${DOWNLOADS[@]}" \
  "$(sha256 "$here/build-binaries.sh")" "$(sha256 "$here/build-in-container.sh")" \
  "$(sha256 "$here/omp-stub/omp.h")" | { if command -v sha256sum >/dev/null; then sha256sum; else shasum -a 256; fi; } | cut -d' ' -f1)"

todo=()
for p in "${platforms[@]}"; do
  if [ "$force" = 0 ] && [ "$(cat "$out/$p/.stamp" 2>/dev/null)" = "$stamp" ] \
     && [ -x "$out/$p/raxml-ng" ] && [ -x "$out/$p/FastTree" ] && [ -x "$out/$p/igphyml" ] \
     && [ -f "$out/igphyml-motifs/HTABLE_WRC_2" ]; then
    echo "$p: up to date"
  else
    todo+=("$p")
  fi
done
[ ${#todo[@]} -gt 0 ] || { install_into_rdist; exit 0; }

command -v docker >/dev/null || { echo "build-binaries: Docker is required to build ${todo[*]}" >&2; exit 1; }

mkdir -p "$cache"
for d in "${DOWNLOADS[@]}"; do
  IFS='|' read -r name url sum <<<"$d"
  f="$cache/$name"
  if [ ! -f "$f" ] || [ "$(sha256 "$f")" != "$sum" ]; then
    echo "fetching $url"
    curl -fsSL --retry 3 -o "$f.part" "$url"
    got="$(sha256 "$f.part")"
    [ "$got" = "$sum" ] || { rm -f "$f.part"; echo "checksum mismatch for $url: $got" >&2; exit 1; }
    mv "$f.part" "$f"
  fi
done

# Build into a staging tree and move each platform in only once all succeeded.
stage="$(mktemp -d "${TMPDIR:-/tmp}/lineage-trees-bin.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
docker run --rm --platform linux/amd64 \
  -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
  -v "$cache:/src:ro" -v "$here:/tools:ro" -v "$stage:/out" \
  "$BASE_IMAGE" bash /tools/build-in-container.sh "${todo[@]}"

mkdir -p "$out"
rm -rf "$out/igphyml-motifs" && mv "$stage/igphyml-motifs" "$out/igphyml-motifs"
for p in "${todo[@]}"; do
  rm -rf "$out/$p"
  mv "$stage/$p" "$out/$p"
  echo "$stamp" > "$out/$p/.stamp"
  echo "$p: built"
done
install_into_rdist
