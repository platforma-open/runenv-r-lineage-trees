# runenv-r-lineage-trees

R run environment for the Lineage Trees block: Dowser, TIgGER, Alakazam and SHazaM,
which cover germline reconstruction, novel allele inference and the tree metrics.
R 4.4.2, Bioconductor 3.20, all five platforms.

## Regenerating the lockfile

`dependencies/renv.lock` is generated, not hand-edited. `tools/` holds the recipe:

```bash
docker build -t rlock-base -f tools/lock.Dockerfile tools
docker run --rm -v "$PWD/tools:/w" rlock-base \
  bash -lc 'cp /w/generate-lock.R /app/ && R --no-echo -f /app/generate-lock.R && cat /app/renv.lock' \
  > dependencies/renv.lock
```

Expect around 25 minutes: these images build from source deliberately, with the Posit
binary packages disabled.

Then bump the version in `package.json`, commit, push to main. CI takes roughly 40
minutes.

## Three things that will break a regeneration

Each of these was hit while producing the current lock, and each fails in a way that
does not name its cause.

**`renv::init(bioconductor = "3.20")` does not set the repositories.** After calling
it, `getOption("repos")` holds CRAN and nothing else. Alakazam needs `Biostrings`,
`GenomicAlignments` and `IRanges`, so it fails with "package not available", and
Dowser, TIgGER and SHazaM fail after it because they all import Alakazam. Set all six
repositories explicitly, as `generate-lock.R` does. The set is copied from
`runenv-r-tcr-disco`, which is the proven configuration here.

**ggplot2 4.x breaks ggtree.** ggplot2 4.0 removed `check_linewidth`, which ggtree
3.14.0 from Bioconductor 3.20 calls at lazy-load, so ggtree fails to build and Dowser
fails with it. The `functional-analysis` block solved this under MILAB-6263 by freezing
all of CRAN to a 2025-09-10 snapshot, the day before ggplot2 4.0.0 was published. That
snapshot also predates dowser 2.4 and tigger 1.1.2, which would mean shipping dowser
2.3 and tigger 1.1.0. This environment pins only ggplot2, to 3.5.2, and keeps CRAN
current, so dowser 2.5.1 and tigger 1.1.3 are what get installed.

**renv will not snapshot a Bioconductor project without BiocManager.** The snapshot
aborts on pre-flight validation asking for `BiocManager` and `BiocVersion`, even though
neither is needed to install anything. Install both before snapshotting.

## What the lock currently pins

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

137 packages in total, 24 of them from Bioconductor.
