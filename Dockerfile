# Dockerfile - the IntegrityAnalysis REST API as a container (issue 1,
# phase 2).
#
# PROVENANCE: written 2026-08-26 by Claude Code (model Claude Fable 5)
# at Steve Shafer's direction ("Go ahead with phase 2"): hosting target
# AWS App Runner, image built by AWS CodeBuild (buildspec.yml) - there
# is no local Docker on the development machine, and CodeBuild keeps
# every credential inside the AWS account.
#
# Base: rocker/r-ver pins the EXACT R version the package is developed
# and tested against (renv.lock records R 4.5.3), and configures CRAN
# to the Posit Package Manager binary repository for the distro, so
# renv::restore() installs binaries in minutes rather than compiling
# for an hour.
FROM rocker/r-ver:4.5.3

# System libraries for the locked R packages:
#   poppler  - pdftools (PDF text + rendering)
#   tesseract/leptonica + eng data - the OCR tier (issue 22)
#   tbb      - oneTBB runtime: the PPM binary of Rfast links libtbb12,
#              and without it the service dies at startup with
#              "undefined symbol: tbb::detail::r1::spawn" (found live
#              on the first App Runner deploy, 2026-08-26)
#   sodium   - plumber's dependency for encrypted cookies
#   xml2, curl, ssl, fontconfig/freetype/png/jpeg/tiff - parsing and
#   rendering stack
RUN apt-get update && apt-get install -y --no-install-recommends \
      libpoppler-cpp-dev \
      libtesseract-dev libleptonica-dev tesseract-ocr-eng \
      libtbb12 \
      libsodium-dev \
      libxml2-dev libcurl4-openssl-dev libssl-dev \
      libfontconfig1-dev libfreetype6-dev libpng-dev libjpeg-dev \
      libtiff5-dev zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Restore the LOCKED environment first, alone, so Docker layer caching
# makes rebuilds after code-only changes nearly instant.
COPY renv.lock renv.lock
RUN R -e "install.packages('renv'); renv::restore(lockfile = 'renv.lock', prompt = FALSE)"

# Rfast's PPM binary dies at load time in this image with an
# unresolved oneTBB symbol (tbb::detail::r1::spawn) - it links TBB
# through RcppParallel, and the prebuilt expectations do not line up
# with the container's loader (two failed App Runner deploys,
# 2026-08-26; installing libtbb12 alone did not cure it). Compiling
# RcppParallel and Rfast FROM SOURCE inside the image makes the whole
# TBB chain self-consistent. The locked versions are respected: the
# version to build comes from renv.lock.
RUN R -e "lk <- renv::lockfile_read('renv.lock')\$Packages; \
          for (p in c('RcppParallel', 'Rfast')) \
            renv::install(paste0(p, '@', lk[[p]]\$Version), \
                          type = 'source', rebuild = TRUE, prompt = FALSE); \
          library(Rfast); cat('Rfast loads OK\n')"

# Then the package itself.
COPY . /build
RUN R CMD INSTALL --no-multiarch /build && rm -rf /build

# The service. INTEGRITY_API_TOKENS must be supplied by the runtime
# (App Runner environment configuration) - with none set the service
# starts but refuses every data request (fail closed, by design).
# The commit this image was built from, so /health can name it (issue
# 28 for the container). CodeBuild passes CODEBUILD_RESOLVED_SOURCE_VERSION
# as --build-arg BUILD_SHA (buildspec.yml); a local build without it
# reports "unknown", which is the truth. Placed after the install so a
# new SHA never invalidates the package layers above.
ARG BUILD_SHA=unknown
ENV INTEGRITY_BUILD_SHA=$BUILD_SHA
EXPOSE 8080
CMD ["Rscript", "-e", "IntegrityAnalysis::runApiService(port = 8080, host = '0.0.0.0')"]
