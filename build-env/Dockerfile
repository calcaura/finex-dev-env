# Dev/build container for finex-next (Kotlin Multiplatform + Compose Multiplatform).
#
# Scope on purpose: this image builds the Android and Web/Wasm targets only.
# iOS (Xcode, Kotlin/Native's iOS targets, cinterop) cannot run in a Linux
# container — there is no supported way around that — so iOS is built
# directly on the macOS host, outside this container, with the
# `macos-latest` GitHub Actions job as the authoritative iOS check.
# See /finex-next/../.github/workflows/ci.yml and the plan doc for details.

FROM eclipse-temurin:25-jdk-jammy

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
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        gnupg \
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
    && add-apt-repository -y ppa:xtradeb/apps \
    && apt-get update && apt-get install -y --no-install-recommends chromium \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

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

# Gradle itself is not baked in on purpose — the project's own ./gradlew
# wrapper (added when the KMP project is scaffolded) pins the exact Gradle
# version and downloads it on first run, same as the existing Android app.

RUN useradd -m -s /bin/bash cylon &&\
  usermod -aG sudo cylon &&\
  passwd -d cylon &&\
  echo "cylon ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/cylon

# Add scripts
ENV FINEX_SCRIPT_DIR=/opt/finex/scripts

ADD ./build-env/scripts ${FINEX_SCRIPT_DIR}
ADD ./build-env/.githooks /.githooks

WORKDIR /workspaces/finex-next
