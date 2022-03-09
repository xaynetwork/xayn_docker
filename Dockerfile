FROM cirrusci/flutter:2.5.3

RUN apt-get update && apt-get install -y \
  libclang-10-dev \
  && rm -rf /var/lib/apt/lists/*

ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH \
    RUST_VERSION=1.55.0

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

RUN set -eux; \
  cargo install \
    just \
    cargo-sort \
    ; \
   cargo install --git https://github.com/xaynetwork/cargo-ndk.git cargo-ndk ;  \
   cargo install \
     --git https://github.com/xaynetwork/xayn_async_bindgen.git \
     async-bindgen-gen-dart; \
  rm -rf /usr/local/cargo/{.package-cache,registry};

ENV ANDROID_NDK_HOME /opt/android-ndk
ENV ANDROID_NDK_VERSION r21

RUN mkdir /opt/android-ndk-tmp && \
    cd /opt/android-ndk-tmp && \
    wget -q https://dl.google.com/android/repository/android-ndk-${ANDROID_NDK_VERSION}-linux-x86_64.zip && \
    unzip -q android-ndk-${ANDROID_NDK_VERSION}-linux-x86_64.zip && \
    mv ./android-ndk-${ANDROID_NDK_VERSION} ${ANDROID_NDK_HOME} && \
    cd ${ANDROID_NDK_HOME} && \
    rm -rf /opt/android-ndk-tmp

ENV PATH ${PATH}:${ANDROID_NDK_HOME}

RUN rustup target add \
	aarch64-linux-android \
	x86_64-linux-android \
	armv7-linux-androideabi \
	i686-linux-android

RUN rustup toolchain install "nightly-2021-09-09" --component rustfmt  --profile minimal

RUN rustup component add clippy