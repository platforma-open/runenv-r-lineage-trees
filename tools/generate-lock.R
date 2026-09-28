# Repository set copied from support/runenv-r-tcr-disco/dependencies/renv.lock, which is the
# proven configuration here. renv::init(bioconductor=) does NOT populate getOption("repos").
options(repos = c(
  BioCsoft      = "https://bioconductor.org/packages/3.20/bioc",
  BioCann       = "https://bioconductor.org/packages/3.20/data/annotation",
  BioCexp       = "https://bioconductor.org/packages/3.20/data/experiment",
  BioCworkflows = "https://bioconductor.org/packages/3.20/workflows",
  BioCbooks     = "https://bioconductor.org/packages/3.20/books",
  CRAN          = "https://packagemanager.posit.co/cran/2026-09-10"
))
renv::init(bare = TRUE)
options(repos = c(
  BioCsoft      = "https://bioconductor.org/packages/3.20/bioc",
  BioCann       = "https://bioconductor.org/packages/3.20/data/annotation",
  BioCexp       = "https://bioconductor.org/packages/3.20/data/experiment",
  BioCworkflows = "https://bioconductor.org/packages/3.20/workflows",
  BioCbooks     = "https://bioconductor.org/packages/3.20/books",
  CRAN          = "https://packagemanager.posit.co/cran/2026-09-10"
))
cat("REPOS:\n"); print(getOption("repos"))
# ggplot2 4.x drops check_linewidth, which ggtree 3.14.0 (Bioc 3.20) needs at lazy-load.
# Pin just ggplot2 rather than freezing all of CRAN to Sep 2025, which would cost
# dowser 2.5.1 -> 2.3 and tigger 1.1.3 -> 1.1.0.
renv::install("ggplot2@3.5.2")
renv::install(c("dowser", "tigger", "alakazam", "shazam", "airr"))
renv::install(c("BiocManager", "BiocVersion"))
renv::snapshot(type = "all", prompt = FALSE)
cat("SNAPSHOT DONE\n")
