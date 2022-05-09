#!/bin/bash

set -eux

repodir=$(mktemp -d)

if [ -z "${1+x}" ]; then
  branch="main"
else
  branch="$1"
  shift
fi

git clone --depth 1 https://github.com/xaynetwork/xayn_discovery_engine -b "$branch" "$repodir"

cp "$repodir/.env" engine_env

RUST_TOOLCHAIN_TOML="$repodir/discovery_engine_core/rust-toolchain.toml"
RUST_VERSION=$(perl -ne 'print $1 if /channel = \"(.*)\"/' "$RUST_TOOLCHAIN_TOML")

echo "RUST_VERSION=$RUST_VERSION" >> engine_env
