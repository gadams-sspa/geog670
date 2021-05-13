# Author: Glen Adams
# Used these Docker files as reference
# https://github.com/rocker-org/rocker-versioned/blob/master/r-ver/3.6.3.Dockerfile
# https://github.com/rocker-org/geospatial/blob/master/Dockerfile
# https://github.com/r-spatial/sf/
# https://github.com/r-spatial/sf/blob/master/inst/docker/base/Dockerfile
FROM postgis/postgis:13-master

ARG R_VERSION
ARG BUILD_DATE
ARG CRAN
ENV BUILD_DATE ${BUILD_DATE:-2020-04-24}
ENV R_VERSION=${R_VERSION:-3.6.3} \
    CRAN=${CRAN:-https://cran.rstudio.com} \ 
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    TERM=xterm
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8
  

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash-completion \
    ca-certificates \
    file \
    fonts-texgyre \
    g++ \
    gfortran \
    gsfonts \
    libblas-dev \
    libbz2-1.0 \
    libcurl4 \
    libicu63 \
    libjpeg62-turbo \
    libopenblas-dev \
    libpangocairo-1.0-0 \
    libpcre3 \
    libpng16-16 \
    libreadline7 \
    libtiff5 \
    liblzma5 \
    locales \
    make \
    unzip \
    zip \
    zlib1g \
  && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
  && locale-gen en_US.utf8 \
  && /usr/sbin/update-locale LANG=en_US.UTF-8 \
  && BUILDDEPS="curl \
    default-jdk \
    libbz2-dev \
    libcairo2-dev \
    libcurl4-openssl-dev \
    libpango1.0-dev \
    libjpeg-dev \
    libicu-dev \
    libpcre3-dev \
    libpng-dev \
    libreadline-dev \
    libtiff5-dev \
    liblzma-dev \
    libx11-dev \
    libxt-dev \
    perl \
    tcl8.6-dev \
    tk8.6-dev \
    texinfo \
    texlive-extra-utils \
    texlive-fonts-recommended \
    texlive-fonts-extra \
    texlive-latex-recommended \
    x11proto-core-dev \
    xauth \
    xfonts-base \
    xvfb \
    zlib1g-dev" \
  && apt-get install -y --no-install-recommends $BUILDDEPS \
  && cd tmp/ \
  ## Download source code
  && curl -O https://cran.r-project.org/src/base/R-3/R-${R_VERSION}.tar.gz \
  ## Extract source code
  && tar -xf R-${R_VERSION}.tar.gz \
  && cd R-${R_VERSION} \
  ## Set compiler flags
  && R_PAPERSIZE=letter \
    R_BATCHSAVE="--no-save --no-restore" \
    R_BROWSER=xdg-open \
    PAGER=/usr/bin/pager \
    PERL=/usr/bin/perl \
    R_UNZIPCMD=/usr/bin/unzip \
    R_ZIPCMD=/usr/bin/zip \
    R_PRINTCMD=/usr/bin/lpr \
    LIBnn=lib \
    AWK=/usr/bin/awk \
    CFLAGS="-g -O2 -fstack-protector-strong -Wformat -Werror=format-security -Wdate-time -D_FORTIFY_SOURCE=2 -g" \
    CXXFLAGS="-g -O2 -fstack-protector-strong -Wformat -Werror=format-security -Wdate-time -D_FORTIFY_SOURCE=2 -g" \
  ## Configure options
  ./configure --enable-R-shlib \
               --enable-memory-profiling \
               --with-readline \
               --with-blas \
               --with-tcltk \
               --disable-nls \
               --with-recommended-packages \
  ## Build and install
  && make \
  && make install \
  ## Add a library directory (for user-installed packages)
  && mkdir -p /usr/local/lib/R/site-library \
  && chown root:staff /usr/local/lib/R/site-library \
  && chmod g+ws /usr/local/lib/R/site-library \
  ## Fix library path
  && sed -i '/^R_LIBS_USER=.*$/d' /usr/local/lib/R/etc/Renviron \
  && echo "R_LIBS_USER=\${R_LIBS_USER-'/usr/local/lib/R/site-library'}" >> /usr/local/lib/R/etc/Renviron \
  && echo "R_LIBS=\${R_LIBS-'/usr/local/lib/R/site-library:/usr/local/lib/R/library:/usr/lib/R/library'}" >> /usr/local/lib/R/etc/Renviron \
  ## Set configured CRAN mirror
  && if [ -z "$BUILD_DATE" ]; then MRAN=$CRAN; \
   else MRAN=https://mran.microsoft.com/snapshot/${BUILD_DATE}; fi \
   && echo MRAN=$MRAN >> /etc/environment \
  && echo "options(repos = c(CRAN='$MRAN'), download.file.method = 'libcurl')" >> /usr/local/lib/R/etc/Rprofile.site \
  ## Use littler installation scripts
  && Rscript -e "install.packages(c('littler', 'docopt'), repo = '$CRAN')" \
  && ln -s /usr/local/lib/R/site-library/littler/examples/install2.r /usr/local/bin/install2.r \
  && ln -s /usr/local/lib/R/site-library/littler/examples/installGithub.r /usr/local/bin/installGithub.r \
  && ln -s /usr/local/lib/R/site-library/littler/bin/r /usr/local/bin/r \
  ## Clean up from R source install
  && cd / \
  && rm -rf /tmp/* \
  && apt-get remove --purge -y $BUILDDEPS \
  && apt-get autoremove -y \
  && apt-get autoclean -y \
  && rm -rf /var/lib/apt/lists/*

  RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    lbzip2 \
    libfftw3-dev \
    libgdal-dev \
    libgeos-dev \
    libgsl0-dev \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    libhdf4-alt-dev \
    libhdf5-dev \
    libjq-dev \
    liblwgeom-dev \
    libpq-dev \
    libproj-dev \
    libprotobuf-dev \
    libnetcdf-dev \
    libsqlite3-dev \
    libssl-dev \
    libudunits2-dev \
    netcdf-bin \
    postgis \
    protobuf-compiler \
    sqlite3 \
    tk-dev \
    unixodbc-dev

RUN install2.r --error \
    gstat \
    raster \
    sf \
    sp \
    data.table

# RUN install2.r --error \
#     RColorBrewer \
#     RandomFields \
#     RNetCDF \
#     classInt \
#     deldir \
#     gstat \
#     hdf5r \
#     lidR \
#     mapdata \
#     maptools \
#     mapview \
#     ncdf4 \
#     proj4 \
#     raster \
#     rgdal \
#     rgeos \
#     rlas \
#     sf \
#     sp \
#     spacetime \
#     spatstat \
#     spdep \
#     geoR \
#     geosphere \
#     data.table
    # ## from bioconductor
    # && R -e "BiocManager::install('rhdf5', update=FALSE, ask=FALSE)"
# ARG numcpu

# Setting up R and PL/R
# RUN apt-get -y update; apt-get install -y software-properties-common build-essential devscripts
# RUN add-apt-repository 'deb http://cloud.r-project.org/bin/linux/debian buster-cran40/'
# RUN apt-key adv --keyserver keys.gnupg.net --recv-key 'E19F5F87128899B192B1A2C2AD5F960A256A04AF'
# RUN apt-get -y update; apt-get install -y r-base r-base-dev r-recommended postgresql-13-plr

# # Setting up R and PL/R
# RUN apt-get -y update; apt-get install -y software-properties-common build-essential devscripts
# RUN add-apt-repository 'deb http://ppa.launchpad.net/ubuntugis/ubuntugis-unstable/ubuntu focal main'
# RUN apt-key adv --keyserver keys.gnupg.net --recv-key '6B827C12C2D425E227EDCA75089EBE08314DF160'
# RUN add-apt-repository 'deb http://cloud.r-project.org/bin/linux/debian buster-cran40/'
# RUN apt-key adv --keyserver keys.gnupg.net --recv-key 'E19F5F87128899B192B1A2C2AD5F960A256A04AF'
# RUN add-apt-repository 'deb http://ppa.launchpad.net/c2d4u.team/c2d4u4.0+/ubuntu focal main'
# RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-key '6E12762B81063D17BDDD3142F142A4D99F16EB04'
# RUN add-apt-repository 'deb http://http.us.debian.org/debian sid main non-free contrib'
# RUN add-apt-repository 'deb http://archive.ubuntu.com/ubuntu focal universe'
# RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-key '871920D1991BC93C'

# RUN export DEBIAN_FRONTEND=noninteractive; apt-get -y update \
#     && apt-get upgrade -y \
#     && apt-get install -y \
#     git \
#     wget \
#     make \
#     pandoc \
#     qpdf \
#     sqlite3 \
#     libcurl4-openssl-dev \
#     libssl-dev \
#     r-base \
#     r-base-dev \
#     r-recommended \
#     postgresql-13-plr \
#     libudunits2-dev \
#     libgdal-dev \
#     libgdal26 \
#     libgeos-dev \
#     libproj-dev \
#     liblwgeom-dev \
#     libgcc-s1 \
#     libogdi-dev \
#     r-cran-sf \
#     r-cran-rgdal \
#     r-cran-gstat \
#     r-cran-raster \
#     r-cran-data.table \
    
# RUN apt-get install -y texinfo \
#        texlive-base \
#        texlive-extra-utils \
#        texlive-fonts-extra \
#        texlive-fonts-recommended \
#        texlive-generic-recommended \
#        texlive-latex-base \
#        texlive-latex-extra \
#        texlive-latex-recommended

# RUN R -e "install.packages(c('gstat', 'raster', 'data.table'), dependencies=TRUE, repos=c('http://cran.rstudio.com/', 'https://cran.r-project.org/'), Ncpus=$numcpu)"
# RUN R -e "install.packages(c('sf'), dependencies=TRUE, repos=c('https://cloud.r-project.org'))"
# RUN git clone   https://github.com/r-spatial/sf.git
# RUN R CMD build --no-build-vignettes sf
# RUN R CMD INSTALL sf_*tar.gz
# RUN R CMD check --as-cran sf_*tar.gz