# Dev/build container for finex-next (Kotlin Multiplatform + Compose Multiplatform).
#
# Scope on purpose: this image builds the Android and Web/Wasm targets only.
# iOS (Xcode, Kotlin/Native's iOS targets, cinterop) cannot run in a Linux
# container — there is no supported way around that — so iOS is built
# directly on the macOS host, outside this container, with the
# `macos-latest` GitHub Actions job as the authoritative iOS check.
# See /finex-next/../.github/workflows/ci.yml and the plan doc for details.

# Pinned to linux/amd64 rather than following the host's native arch: AGP's
# aapt2 (Android resource compiler) has no native linux/aarch64 build, so an
# arm64 container (the default Docker Desktop would build/run on an Apple
# Silicon Mac) fails Android resource processing outright ("aapt2 ... Daemon
# startup failed" / "rosetta error: failed to open elf"). Forcing amd64 here
# makes Docker Desktop run the whole container under Rosetta on Apple
# Silicon instead — transparent and fast — and is a no-op on an amd64 host.
# Confirmed by an actual :androidApp:assembleDebug run in this Phase 0
# session that failed on native arm64 with exactly that aapt2 error.
FROM --platform=linux/amd64 eclipse-temurin:25-jdk-jammy

# Google renamed the API 37 platform package to "37.0" (with a point
# release) partway through the API 37 cycle; sdkmanager has no bare
# "platforms;android-37" anymore. Keep the plain "37" for anything that
# still wants an int (e.g. Gradle's compileSdkVersion) and use the ".0"
# form only where we talk to sdkmanager below.
ARG ANDROID_COMPILE_SDK=37
ARG ANDROID_PLATFORM_PACKAGE=37.0
ARG ANDROID_BUILD_TOOLS=37.0.0
ARG ANDROID_NDK_VERSION=27.0.12077973
ARG ANDROID_CMAKE_VERSION=3.22.1
ARG ANDROID_CMDLINE_TOOLS_VERSION=11076708

ENV ANDROID_SDK_ROOT=/opt/android-sdk \
    ANDROID_HOME=/opt/android-sdk \
    ANDROID_NDK_HOME=/opt/android-sdk/ndk/${ANDROID_NDK_VERSION} \
    DEBIAN_FRONTEND=noninteractive

# Base packages:
#  - unzip/curl: SDK download + install
#  - git: obviously
#  - chromium: headless browser target for `wasmJsBrowserTest` (Kotlin/Wasm
#    test runner needs a real browser; we pin one in-image instead of
#    letting Karma download an arbitrary one at test time).
#    Ubuntu jammy dropped real chromium .deb builds in favor of a snap-only
#    transitional package, which can't be installed in a container ("Package
#    chromium is not available... refer to chromium-bsu"). The xtradeb/apps
#    PPA publishes actual Chromium builds for jammy on amd64 *and* arm64, so
#    pull from there instead.
#  - gh (GitHub CLI): pushing branches / opening PRs from inside the
#    container, mirroring the host workflow
#  - libatomic1: the Node.js toolchain Kotlin/Wasm downloads for
#    wasmJsBrowserDistribution/-Test (webpack bundling, the yarn/npm
#    tooling) fails to start without it ("libatomic.so.1: cannot open
#    shared object file") — not pulled in by anything else here.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        gnupg \
        libatomic1 \
        lsof \
        man \
        moreutils \
        musl-tools \
        net-tools \
        openssh-client \
        pkg-config \
        podman \
        procps \
        python3 \
        python3-pip \
        software-properties-common \
        sudo \
        unzip \
        xz-utils \
    && add-apt-repository -y ppa:xtradeb/apps \
    && apt-get update && apt-get install -y --no-install-recommends chromium \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        -o /usr/share/keyrings/docker-archive-keyring.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.asc] https://download.docker.com/linux/ubuntu jammy stable" \
        > /etc/apt/sources.list.d/docker.list \
    && apt-get update && apt-get install -y --no-install-recommends \
        docker-ce-cli \
        docker-compose-plugin \
        docker-buildx-plugin

# shellcheck + actionlint: the static checks for the two things this repo
# has a lot of and Gradle can't check — the bash in scripts/**/*.sh, and
# .github/workflows/ci.yml (actionlint validates workflow syntax, action
# inputs and ${{ }} expressions, and shells out to shellcheck for `run:`
# blocks). Both are single static binaries from their upstream releases
# rather than apt packages: Ubuntu 22.04 ships shellcheck 0.8.0 (2021) and
# no actionlint at all. Version-pinned so a rebuild can't silently change
# what CI-adjacent linting accepts.
#
# These live here rather than in the base image because they're about this
# repo's scripts and workflow, not the KMP toolchain; if finex-dev-env's
# other consumers end up wanting them too, move them there instead (see the
# note above about keeping provisioning in the base image). Note the
# consequence: ci.yml's containerized jobs run the *base* image directly,
# not this Dockerfile, so these two are a local-only check for now - moving
# them into finex-dev-env is what would let scripts/check.sh run them in CI.
# Downloaded to a file and then extracted, rather than curl | tar: RUN's
# shell is dash, which has no `set -o pipefail`, so a failing curl in a
# pipeline would be masked by tar's exit status and bake a broken layer.
# xz-utils is needed because shellcheck only publishes .tar.xz and the base
# image has no xz.
ARG SHELLCHECK_VERSION=0.11.0
ARG ACTIONLINT_VERSION=1.7.12
RUN set -eux; \
    curl -fsSL -o /tmp/shellcheck.tar.xz \
        "https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/shellcheck-v${SHELLCHECK_VERSION}.linux.x86_64.tar.xz"; \
    tar -xf /tmp/shellcheck.tar.xz -C /tmp; \
    install -m 0755 "/tmp/shellcheck-v${SHELLCHECK_VERSION}/shellcheck" /usr/local/bin/shellcheck; \
    curl -fsSL -o /tmp/actionlint.tar.gz \
        "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_linux_amd64.tar.gz"; \
    tar -xf /tmp/actionlint.tar.gz -C /tmp actionlint; \
    install -m 0755 /tmp/actionlint /usr/local/bin/actionlint; \
    rm -rf /tmp/shellcheck.tar.xz "/tmp/shellcheck-v${SHELLCHECK_VERSION}" /tmp/actionlint.tar.gz /tmp/actionlint; \
    shellcheck --version; \
    actionlint --version

RUN rm -rf /var/lib/apt/lists/*

# Docker CLI only — no dockerd/containerd is started in this image. The
# consumer's devcontainer.json is expected to bind-mount the host's
# /var/run/docker.sock (Docker Desktop) so `docker`/`docker compose` here
# talk to the host engine ("docker-outside-of-docker"), the same way `gh`
# above talks to github.com rather than running its own server. The `docker`
# group exists so the socket can be shared via group membership if its host
# GID is aligned at container start; until then cylon's passwordless sudo
# (below) covers `sudo docker ...`.
RUN groupadd -f docker

ENV CHROME_BIN=/usr/bin/chromium

# Android SDK: cmdline-tools + the platform/build-tools/NDK/cmake this
# project's existing native build already uses (matches
# `finex/build.gradle`'s compileSdkVersion=37 and the NDK already installed
# on the host, so behavior matches what's already validated for the C++
# core in api_data/ and rl/rl_native/).
RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools \
    && curl -fsSL -o /tmp/cmdline-tools.zip \
        "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip" \
    && unzip -q /tmp/cmdline-tools.zip -d ${ANDROID_SDK_ROOT}/cmdline-tools \
    && mv ${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/latest \
    && rm /tmp/cmdline-tools.zip

ENV PATH=${PATH}:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools

RUN yes | sdkmanager --licenses > /dev/null \
    && sdkmanager \
        "platform-tools" \
        "platforms;android-${ANDROID_PLATFORM_PACKAGE}" \
        "build-tools;${ANDROID_BUILD_TOOLS}" \
        "ndk;${ANDROID_NDK_VERSION}" \
        "cmake;${ANDROID_CMAKE_VERSION}"


# Gradle: baked in, and the wrapper's own distribution cache pre-warmed too
# — not just a standalone `gradle` on PATH. finex-next's CI scripts call
# `./gradlew`, which always manages its own versioned distribution under
# GRADLE_USER_HOME independent of what's on PATH; leaving that cache cold
# meant every fresh CI job downloaded gradle-9.4.1-bin.zip from
# services.gradle.org on its own, which is exactly the "installs tools
# during CI" cost this image exists to front-load (same reasoning as the
# Android SDK above).
#
# GRADLE_USER_HOME is set explicitly rather than left as the default
# $HOME/.gradle: GitHub Actions container jobs mount their own $HOME over
# whatever the image sets, so a cache baked in under the image's $HOME
# would be invisible at CI time. An explicit path here survives that.
#
# Primed using finex-next's *real* gradlew + gradle/wrapper/gradle-wrapper.
# {properties,jar} (vendored below, copied from finex-next's repo — keep
# them in sync there if finex-next ever bumps its Gradle version) rather
# than hand-deriving the wrapper's hash-keyed cache path: running the actual
# wrapper is the only way to guarantee the cache entry lands exactly where
# `./gradlew` will look for it later, and this doubles as the standalone
# `gradle` CLI install via the symlink at the end (no second download).
#
# Left world-writable at the end: this image's users differ by context
# (root in CI container jobs, `cylon` in the local devcontainer per
# remoteUser below), and both need to write their own dependency-cache
# entries into GRADLE_USER_HOME on top of the primed wrapper dist.
ENV GRADLE_USER_HOME=/opt/gradle-home
ADD ./build-env/gradle-wrapper-prime /tmp/gradle-wrapper-prime
RUN cd /tmp/gradle-wrapper-prime \
    && chmod +x gradlew \
    && ./gradlew --version \
    && gradle_bin="$(find "${GRADLE_USER_HOME}/wrapper/dists" -type f -name gradle -path '*/bin/gradle')" \
    && ln -s "${gradle_bin}" /usr/local/bin/gradle \
    && gradle --version \
    && cd / && rm -rf /tmp/gradle-wrapper-prime \
    && chmod -R o+rwX,g+rwX "${GRADLE_USER_HOME}"

RUN useradd -m -s /bin/bash cylon &&\
  usermod -aG sudo,docker cylon &&\
  passwd -d cylon &&\
  echo "cylon ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/cylon

# Add scripts
ENV FINEX_SCRIPT_DIR=/opt/finex/scripts

ADD ./build-env/scripts ${FINEX_SCRIPT_DIR}
ADD ./build-env/.githooks /.githooks

# Shell aliases for interactive use (e.g. `gis`, `dag`), applied system-wide
# so they're available to any user's non-login interactive bash shell.
ADD ./build-env/.bash_aliases /tmp/.bash_aliases
RUN cat /tmp/.bash_aliases >> /etc/bash.bashrc && rm /tmp/.bash_aliases

WORKDIR /workspaces/finex-next
