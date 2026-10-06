# runenv-r-lineage-trees

R run environment for the Lineage Trees block: Dowser, TIgGER, Alakazam and SHazaM, plus
the tree builders raxml-ng 2.0.3, FastTree 2.1.11 and IgPhyML 2.0.0. R 4.4.2,
Bioconductor 3.20, on linux x64/aarch64, macOS x64/aarch64 and windows x64.

## Using It from a Block

Add the package as a devDependency of the block's software package and reference it from an
`R` artifact:

```json
"artifact": {
  "type": "R",
  "registry": "platforma-open",
  "environment": "@platforma-open/milaboratories.runenv-r-lineage-trees:main",
  "root": "./src"
}
```

The tree builders are on `PATH` (`.exe` on Windows), and IgPhyML's hotspot tables are in
`share/igphyml/motifs`.

## Releasing

Bump `version` in `package.json` and push to `main`. CI builds all five platforms in about
40 minutes; publishing waits for approval of the `release` environment. Clone with
`git lfs` installed.

## Building

`npm run build` runs `tools/build.sh`, which runs three steps:

1. `pl-r-builder` compiles R and restores `dependencies/renv.lock` into it. On Linux it
   needs Rocky Linux 8 with `sudo dnf`, whose glibc 2.28 is the oldest the environment
   runs on. On any other Linux, such as the Ubuntu CI runners, `tools/build.sh` runs the
   whole build in a Rocky 8 container, so it needs Docker.
2. `tools/binaries/install-binaries.sh` copies the tree builders from `binaries/` into
   `rdist/`, and unpacks the hotspot tables from the pinned IgPhyML source.
3. `pl-pkg build` packages the result.

Two known failures:

- **Posit binaries.** They link `libR.so`, which `pl-r-builder`'s R does not build, so
  `dependencies/.Renviron` turns them off and all 137 packages build from source.
- **pkgdepends 0.9.1** fails in `collect-dependencies.R` with "missing value where
  TRUE/FALSE needed". Until `@platforma-sdk/r-builder` pins 0.9.0 itself,
  `tools/patch-r-builder.mjs` (run on `npm install`) patches the pin in.

## Tree Builders

`binaries/<platform>/` holds them prebuilt, in Git LFS, so CI needs no Docker. To rebuild
after changing a pin in `tools/binaries/pins.sh` or a build file, run
`npm run build:binaries` (needs Docker) and commit `binaries/`. The install step refuses
binaries built from other pins, and LFS pointer files.

None of the three programs is released for Windows. `tools/binaries/win-compat/` holds
what mingw-w64 lacks: `strsep` and `getline` for IgPhyML, and a header and patch porting
raxml-ng's memory, timing and CPU queries. The Windows raxml-ng is single-threaded; dowser
always passes `--threads 1`, and a higher value hangs it. On the same input, each Windows
program gives the Linux likelihoods, trees and ancestral states.

## Regenerating the Lockfile

```bash
docker build -t rlock-base -f tools/lock.Dockerfile tools
docker run --rm -v "$PWD/tools:/w" rlock-base \
  bash -lc 'cp /w/generate-lock.R /app/ && R --no-echo -f /app/generate-lock.R && cat /app/renv.lock' \
  > dependencies/renv.lock
```

This takes about 25 minutes, since everything builds from source. Keep the result identical
to the block's `software/immcantation/context/renv.lock`. Three traps, each hit producing
the current lock:

- **`renv::init(bioconductor = "3.20")` sets only CRAN.** Alakazam then misses
  `Biostrings`, `GenomicAlignments` and `IRanges`, and Dowser, TIgGER and SHazaM fail
  after it. `generate-lock.R` sets all six repositories, copied from `runenv-r-tcr-disco`.
- **ggplot2 4.x breaks ggtree 3.14.0**, which calls the removed `check_linewidth`. Only
  ggplot2 is pinned, to 3.5.2; the rest comes from a 2026-09-10 Posit snapshot.
- **renv will not snapshot without `BiocManager` and `BiocVersion`**, although neither is
  needed to install. Install both first.

| Package | Version | Source |
|---|---|---|
| dowser | 2.5.1 | CRAN |
| tigger | 1.1.3 | CRAN |
| alakazam | 1.4.3 | CRAN |
| shazam | 1.3.2 | CRAN |
| airr | 2.0.0 | CRAN |
| ggtree | 3.14.0 | Bioconductor |
| treeio | 1.30.0 | Bioconductor |
| pwalign | 1.2.0 | Bioconductor |
| ggplot2 | 3.5.2 | CRAN, pinned |

The lock holds 137 packages, 24 of them from Bioconductor.
