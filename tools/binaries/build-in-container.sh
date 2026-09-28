#!/usr/bin/env bash
# Runs inside the debian:trixie build container started by build-binaries.sh.
# /src holds the verified downloads, /tools this directory, /out the bin tree.
# Usage: build-in-container.sh <platform>...
set -euo pipefail

platforms=("$@")
# Hand the output back to the caller's user even when a step fails.
trap 'chown -R "${HOST_UID:-0}:${HOST_GID:-0}" /out' EXIT
has() { local p; for p in "${platforms[@]}"; do [ "$p" = "$1" ] && return 0; done; return 1; }

export DEBIAN_FRONTEND=noninteractive
pkgs=(build-essential autoconf automake cmake flex bison unzip xz-utils file)
has linux-aarch64 && pkgs+=(gcc-aarch64-linux-gnu g++-aarch64-linux-gnu qemu-user)
apt-get update -qq
apt-get install -y -qq --no-install-recommends "${pkgs[@]}" >/dev/null

if has macosx-x64 || has macosx-aarch64; then
  mkdir -p /opt/zig
  tar -xJf /src/zig.tar.xz -C /opt/zig --strip-components 1
  export ZIG_GLOBAL_CACHE_DIR=/tmp/zig-cache ZIG_LOCAL_CACHE_DIR=/tmp/zig-cache
fi

# The Docker image builds IgPhyML in /usr/local/share/igphyml, and IgPhyML bakes
# "<build dir>/src/motifs/HTABLE_" in as its first place to look for its tables.
# Building at the same path keeps that identical; elsewhere it falls back to
# IGPHYML_PATH.
igsrc=/usr/local/share/igphyml
igphyml_tree() {
  rm -rf "$igsrc" && mkdir -p "$igsrc"
  tar -zxf /src/igphyml.tar.gz -C "$igsrc" --strip-components 1
  # The prototype patch from the Dockerfile.
  sed -i 's/t_tree \*Make_Tree();/t_tree *Make_Tree(int n_otu);/' "$igsrc/src/utilities.h"
  (cd "$igsrc" && aclocal && autoheader && autoconf -f && automake -f --add-missing) >/dev/null 2>&1
}

# Static, so the binary runs on any Linux whatever its glibc. The whole-archive
# libpthread is raxml-ng's own static recipe; harmless on glibc 2.34+.
static_libs="-Wl,--whole-archive -lpthread -Wl,--no-whole-archive"

# $1 platform, $2 C compiler (with any extra flags), $3 configure --host or "".
build_linux() {
  local plat=$1 cc=$2 host=$3 dest=/out/$1
  mkdir -p "$dest"
  echo "== $plat: FastTree"
  # Debian's recipe: one file, double precision, no OpenMP.
  $cc -O2 -DUSE_DOUBLE -static -w -o "$dest/FastTree" /src/FastTree.c -lm

  echo "== $plat: IgPhyML"
  igphyml_tree
  (
    cd "$igsrc"
    # --enable-omp is make_phyml_omp. The malloc answers stop a cross configure
    # from swapping in rpl_malloc, which IgPhyML does not provide.
    ./configure --enable-omp ${host:+--host=$host} CC="$cc" LDFLAGS="-static" LIBS="$static_libs" \
      ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes >/dev/null
    make -j"$(nproc)" >/dev/null 2>build.log || { tail -40 build.log; exit 1; }
  )
  cp "$igsrc/src/igphyml" "$dest/igphyml"
  cp "$igsrc/config.h" /tmp/igphyml-config.h
}

# The macOS IgPhyML has no configure step (its darwin branch adds -arch ppc), so
# it compiles the sources the way src/Makefile.am does, with the config.h of a
# Linux configure and the single-threaded OpenMP stub.
build_macos() {
  local plat=$1 target=$2 dest=/out/$1
  local zcc="/opt/zig/zig cc -target $target -ffp-contract=off"
  mkdir -p "$dest"
  echo "== $plat: FastTree"
  $zcc -O2 -DUSE_DOUBLE -w -o "$dest/FastTree" /src/FastTree.c -lm

  echo "== $plat: IgPhyML"
  igphyml_tree
  if [ ! -f /tmp/igphyml-config.h ]; then
    (cd "$igsrc" && ./configure --enable-omp >/dev/null)
    cp "$igsrc/config.h" /tmp/igphyml-config.h
  fi
  cp /tmp/igphyml-config.h "$igsrc/config.h"
  (
    cd "$igsrc/src"
    $zcc -O3 -fomit-frame-pointer -funroll-loops -std=gnu99 \
      -Wno-implicit-function-declaration -Wno-int-conversion -Wno-incompatible-pointer-types \
      -Wno-unknown-pragmas -w \
      -I/tools/omp-stub -DUNIX -DPHYML -DDEBUG -DOMP -D_GNU_SOURCE \
      -DHTABLE="\"$igsrc/src/motifs/HTABLE_\"" \
      -o "$dest/igphyml" \
      main.c utilities.c optimiz.c lk.c bionj.c models.c free.c help.c simu.c eigen.c \
      pars.c alrt.c controller.c cl.c spr.c stats.c nucle2codon.c io.c -lm
  )

  echo "== $plat: raxml-ng (upstream universal binary)"
  rm -rf /tmp/raxml-mac && mkdir /tmp/raxml-mac
  unzip -q /src/raxml-macos.zip -d /tmp/raxml-mac
  cp /tmp/raxml-mac/raxml-ng "$dest/raxml-ng"
}

if has linux-x64; then
  build_linux linux-x64 gcc ""
  echo "== linux-x64: raxml-ng (upstream static binary)"
  rm -rf /tmp/raxml-linux && mkdir /tmp/raxml-linux
  unzip -q /src/raxml-linux-x64.zip -d /tmp/raxml-linux
  cp /tmp/raxml-linux/raxml-ng /out/linux-x64/raxml-ng
fi

if has linux-aarch64; then
  # -ffp-contract=off: GCC fuses multiply-adds on aarch64 by default, which
  # rounds differently from the x86-64 build.
  build_linux linux-aarch64 "aarch64-linux-gnu-gcc -ffp-contract=off" aarch64-linux-gnu
  # Upstream ships no Linux ARM binary. Its x86-64 release is a static,
  # portable build; this is the same for aarch64 (NEON kernels via sse2neon).
  echo "== linux-aarch64: raxml-ng (from source)"
  rm -rf /tmp/raxml-src && mkdir /tmp/raxml-src
  unzip -q /src/raxml-source.zip -d /tmp/raxml-src
  mkdir /tmp/raxml-src/build
  (
    cd /tmp/raxml-src/build
    cmake .. -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
      -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ \
      -DSTATIC_BUILD=ON -DPORTABLE_BUILD=ON -DUSE_TERRAPHAST=ON -DUSE_GMP=OFF >/dev/null
    make -j"$(nproc)" >build.log 2>&1 || { tail -40 build.log; exit 1; }
  )
  cp /tmp/raxml-src/build/bin/raxml-ng /out/linux-aarch64/raxml-ng
fi

has macosx-x64 && build_macos macosx-x64 x86_64-macos.11.0
has macosx-aarch64 && build_macos macosx-aarch64 aarch64-macos.11.0

# Platform-independent, so shipped once beside the platform directories.
echo "== IgPhyML hotspot tables"
rm -rf /out/igphyml-motifs && mkdir -p /out/igphyml-motifs
tar -zxf /src/igphyml.tar.gz -C /out/igphyml-motifs --strip-components 3 igphyml-2.0.0/src/motifs

echo "== smoke tests"
for p in "${platforms[@]}"; do
  d=/out/$p
  chmod 755 "$d"/*
  case "$p" in
    linux-x64) run="" ;;
    linux-aarch64) run="qemu-aarch64" ;;
    *) run="-" ;;
  esac
  for b in FastTree igphyml raxml-ng; do echo "$p/$b: $(file -b "$d/$b" | cut -c1-110)"; done
  if [ "$run" != "-" ]; then
    # igphyml --version exits 1, so check what each prints, not how it exits.
    check() { local want=$1; shift; local got; got="$($run "$@" 2>&1 || true)"
      case "$got" in *"$want"*) ;; *) echo "$p: $* does not print '$want'" >&2; exit 1 ;; esac; }
    check "Double precision" "$d/FastTree" -expert
    check "IgPhyML 2.0.0" "$d/igphyml" --version
    check "RAxML-NG v. 2.0.3" "$d/raxml-ng" --version
    echo "$p: runs"
  fi
done
