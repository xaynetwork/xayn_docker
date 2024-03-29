FROM debian:11.2-slim

ARG flutter_version
ARG just_version
ARG rust_nightly_version
ARG rust_version
ARG android_platform_version
ARG android_build_tools_version="30.0.2"
ARG android_ndk_version="21.4.7075529"
ARG cargo_sort_version
ARG cargo_ndk_version="2.7.0"
# comes from https://developer.android.com/studio/#command-tools
ARG android_sdk_tools_version="8092744"

USER root

RUN apt-get update && apt-get install -y \
  libclang-11-dev \
  rsync \
  && rm -rf /var/lib/apt/lists/*

# Begin: Android SDK manager
# See https://github.com/cirruslabs/docker-images-android/blob/aea8dd73efac23072d0d88aa688e3bba3d0f694a/sdk/tools/Dockerfile

ENV ANDROID_HOME=/opt/android-sdk-linux \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    LANGUAGE=en_US:en

ENV ANDROID_SDK_ROOT=$ANDROID_HOME \
    PATH=${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/emulator

ENV ANDROID_SDK_TOOLS_VERSION "${android_sdk_tools_version}"

RUN set -o xtrace \
    && cd /opt \
    && apt-get update \
    && apt-get install -y openjdk-11-jdk \
    && apt-get install -y sudo wget zip unzip git openssh-client curl bc software-properties-common build-essential ruby-full ruby-bundler libstdc++6 libpulse0 libglu1-mesa locales lcov libsqlite3-0 --no-install-recommends \
    # for checking/fixing shared objects for android
    && apt-get install -y pax-utils patchelf \
    # for x86 emulators
    && apt-get install -y libxtst6 libnss3-dev libnspr4 libxss1 libasound2 libatk-bridge2.0-0 libgtk-3-0 libgdk-pixbuf2.0-0 \
    && rm -rf /var/lib/apt/lists/* \
    && sh -c 'echo "en_US.UTF-8 UTF-8" > /etc/locale.gen' \
    && locale-gen \
    && update-locale LANG=en_US.UTF-8 \
    && wget -q https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_SDK_TOOLS_VERSION}_latest.zip -O android-sdk-tools.zip \
    && mkdir -p ${ANDROID_HOME}/cmdline-tools/ \
    && unzip -q android-sdk-tools.zip -d ${ANDROID_HOME}/cmdline-tools/ \
    && mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest \
    && chown -R root:root $ANDROID_HOME \
    && rm android-sdk-tools.zip \
    && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
    && yes | sdkmanager --licenses \
    && wget -O /usr/bin/android-wait-for-emulator https://raw.githubusercontent.com/travis-ci/travis-cookbooks/master/community-cookbooks/android-sdk/files/default/android-wait-for-emulator \
    && chmod +x /usr/bin/android-wait-for-emulator \
    && touch /root/.android/repositories.cfg \
    && sdkmanager platform-tools \
    && mkdir -p /root/.android \
    && touch /root/.android/repositories.cfg

# End: Android SDK manager
# ------------------------

# Begin: Android SDK + NDK
# See https://github.com/cirruslabs/docker-images-android/blob/aea8dd73efac23072d0d88aa688e3bba3d0f694a/sdk/30/Dockerfile

ENV ANDROID_PLATFORM_VERSION "${android_platform_version}"
ENV ANDROID_BUILD_TOOLS_VERSION "${android_build_tools_version}"
ENV ANDROID_NDK_VERSION "${android_ndk_version}"
ENV ANDROID_NDK_HOME "/opt/android-sdk-linux/ndk/${android_ndk_version}"
ENV PATH ${PATH}:${ANDROID_NDK_HOME}

RUN yes | sdkmanager \
    "platforms;android-$ANDROID_PLATFORM_VERSION" \
    "build-tools;$ANDROID_BUILD_TOOLS_VERSION" \
    "ndk;$ANDROID_NDK_VERSION"

# End: Android SDK + NDK
# ----------------------

# Begin: Flutter SDK
# Taken from https://github.com/cirruslabs/docker-images-flutter/blob/9982f37ed1b44563800592cb2a92c897cb01f6cd/sdk/Dockerfile

ENV FLUTTER_HOME=${HOME}/sdks/flutter \
    FLUTTER_VERSION=$flutter_version
ENV FLUTTER_ROOT=$FLUTTER_HOME

ENV PATH ${PATH}:${FLUTTER_HOME}/bin:${FLUTTER_HOME}/bin/cache/dart-sdk/bin

RUN git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git ${FLUTTER_HOME}

RUN yes | flutter doctor --android-licenses \
    && flutter doctor \
    && chown -R root:root ${FLUTTER_HOME}

# End: Flutter SDK
# ----------------

# Begin: Rust base
# Taken from https://github.com/rust-lang/docker-rust/blob/878a3bd2f3d92e51b9984dba8f8fd8881367a063/1.55.0/buster/Dockerfile

ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH \
    RUST_VERSION="${rust_version}"

RUN set -eux; \
    dpkgArch="$(dpkg --print-architecture)"; \
    case "${dpkgArch##*-}" in \
        amd64) rustArch='x86_64-unknown-linux-gnu'; rustupSha256='3dc5ef50861ee18657f9db2eeb7392f9c2a6c95c90ab41e45ab4ca71476b4338' ;; \
        armhf) rustArch='armv7-unknown-linux-gnueabihf'; rustupSha256='67777ac3bc17277102f2ed73fd5f14c51f4ca5963adadf7f174adf4ebc38747b' ;; \
        arm64) rustArch='aarch64-unknown-linux-gnu'; rustupSha256='32a1532f7cef072a667bac53f1a5542c99666c4071af0c9549795bbdb2069ec1' ;; \
        i386) rustArch='i686-unknown-linux-gnu'; rustupSha256='e50d1deb99048bc5782a0200aa33e4eea70747d49dffdc9d06812fd22a372515' ;; \
        *) echo >&2 "unsupported architecture: ${dpkgArch}"; exit 1 ;; \
    esac; \
    url="https://static.rust-lang.org/rustup/archive/1.24.3/${rustArch}/rustup-init"; \
    wget "$url"; \
    echo "${rustupSha256} *rustup-init" | sha256sum -c -; \
    chmod +x rustup-init; \
    ./rustup-init -y --no-modify-path --profile minimal --default-toolchain $RUST_VERSION --default-host ${rustArch}; \
    rm rustup-init; \
    chmod -R a+w $RUSTUP_HOME $CARGO_HOME; \
    rustup --version; \
    cargo --version; \
    rustc --version;

# End: Rust base
# --------------


# Begin: Additional Rust requirements
# Added by us

RUN set -eux; \
  rustup toolchain install "${rust_nightly_version}" --component rustfmt --profile minimal; \
  rustc +${rust_nightly_version} --version

RUN rustup component add clippy

RUN rustup target add \
	aarch64-linux-android \
	x86_64-linux-android \
	armv7-linux-androideabi \
	i686-linux-android

RUN set -eux; \
  cargo install just --version="${just_version}" ; \
  cargo install cargo-sort --version="${cargo_sort_version}" ; \
  cargo install cargo-ndk --version="${cargo_ndk_version}"; \
  cargo install --git https://github.com/xaynetwork/xayn_async_bindgen.git async-bindgen-gen-dart; \
  rm -rf /usr/local/cargo/{.package-cache,registry};

# End: Additional Rust requirements
# ---------------------------------
