FROM r-base:4.4.2
ENV RENV_CONFIG_PPM_ENABLED=false
# Dated snapshot: renv::restore against a plain CRAN mirror ignores lockfile versions.
RUN apt-get update && apt-get install -y \
    ca-certificates curl dash default-libmysqlclient-dev libbz2-dev libcairo2-dev \
    libcurl4-openssl-dev libfreetype6-dev libfribidi-dev libgit2-dev libglpk-dev \
    libgmp-dev libgsl-dev libharfbuzz-dev libjpeg-dev liblzma-dev libpcre2-dev \
    libpng-dev libpq-dev libsasl2-dev libsqlite3-dev libssh2-1-dev libssl-dev \
    libtiff5-dev libuv1-dev libxml2-dev unixodbc-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
WORKDIR /app
RUN R -e "install.packages('renv', repos='https://cloud.r-project.org')"
ENV RENV_PATHS_RENV=/app/renv
ENV RENV_PATHS_LOCKFILE=/app/renv.lock
ENV R_LIBS_USER=/app/renv/library
ENV RENV_PATHS_LIBRARY=${R_LIBS_USER}
RUN mkdir -p "${R_LIBS_USER}"
