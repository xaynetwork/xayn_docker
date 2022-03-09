#!/bin/bash

set -eux

source discovery_engine/.env

RUST_VERSION="1.55.0"
CARGO_SORT_VERSION="1.0.7"

docker build \
    --build-arg flutter_version="${FLUTTER_VERSION}" \
    --build-arg just_version="${JUST_VERSION}" \
    --build-arg rust_version="${RUST_VERSION}" \
    --build-arg rust_nightly_version="${RUST_NIGHTLY}" \
    --build-arg android_platform_version="${ANDROID_PLATFORM_VERSION}" \
    --build-arg cargo_sort_version="${CARGO_SORT_VERSION}" \
    $@
