# Sourced by build-binaries.sh and install-binaries.sh: what the tree-building
# programs are built from, and the stamp that says a built set matches it.

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
ALL_PLATFORMS=(linux-x64 linux-aarch64 macosx-x64 macosx-aarch64 windows-x64)
PROGRAMS=(FastTree igphyml raxml-ng)

exe() { [ "$1" = windows-x64 ] && echo ".exe" || true; }
sha256() { if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d' ' -f1; }

# fetch <name> <cache dir>: the pinned download, verified.
fetch() {
  local d name url sum f got
  for d in "${DOWNLOADS[@]}"; do
    IFS='|' read -r name url sum <<<"$d"
    [ "$name" = "$1" ] || continue
    f="$2/$name"
    if [ ! -f "$f" ] || [ "$(sha256 "$f")" != "$sum" ]; then
      mkdir -p "$2"
      echo "fetching $url"
      curl -fsSL --retry 3 -o "$f.part" "$url"
      got="$(sha256 "$f.part")"
      [ "$got" = "$sum" ] || { rm -f "$f.part"; echo "checksum mismatch for $url: $got" >&2; return 1; }
      mv "$f.part" "$f"
    fi
    return 0
  done
  echo "no pinned download named $1" >&2; return 1
}

# What a built set is a function of: the pins and the files that build it.
build_stamp() {
  local here=$1
  { printf '%s\n' "$BASE_IMAGE" "${DOWNLOADS[@]}"
    for f in build-in-container.sh omp-stub/omp.h win-compat/posix.c win-compat/posix.h \
             win-compat/raxml-compat.h win-compat/raxml-ng-2.0.3-windows.patch; do
      echo "$f $(sha256 "$here/$f")"
    done; } | { if command -v sha256sum >/dev/null; then sha256sum; else shasum -a 256; fi; } | cut -d' ' -f1
}
