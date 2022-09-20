#!/usr/bin/env bash
set -e

VERSION_NS3="3.29"
PLATFORM="${2:-all}"

installBoost() {
  wget https://boostorg.jfrog.io/artifactory/main/release/1.67.0/source/boost_1_67_0.tar.gz
  tar xzvf boost_1_67_0.tar.gz
  cd boost_1_67_0 && ./bootstrap.sh && sudo ./b2 install && cd ..
  rm -rf boost_1_67_0.tar.gz boost_1_67_0
}

buildNs3() {
  hg clone http://code.nsnam.org/bake
  cd bake
  ./bake.py configure -e ns-3-allinone
  ./bake.py deploy -v
}

# macOS
# Note: we intentionally don't build these binaries inside a Docker container
for flavour in darwin-x64 darwin-arm64v8; do
  if [ $PLATFORM = $flavour ] && [ "$(uname)" == "Darwin" ]; then
    echo "Building $flavour..."
    root=$(pwd)
    brew update
    brew install advancecomp automake pkg-config cartr/qt4/qt-legacy-formula bzr rar p7zip xz cMake
    curl -O https://distfiles.macports.org/MacPorts/MacPorts-2.7.2.tar.bz2
    tar xf MacPorts-2.7.2.tar.bz2
    cd MacPorts-2.7.2/
    ./configure
    make
    sudo make install
    export PATH=$PATH:/opt/local/bin
    sudo port -v selfupdate
    sudo port install mercurial autoconf cvs
    cd $root
    installBoost
    cd $root
    pip3 install waf
    ls -R
    buildNs3
    tar czvf $flavour.tgz $(find . -name 'lib/lib*.so') $(find . -name 'include/*.h');
    ls -R
    exit 0
  fi
done

# Is docker available?
if ! [ -x "$(command -v docker)" ]; then
  echo "Please install docker"
  exit 1
fi

# Update base images
for baseimage in alpine:3.12 arm64v8/node:14.20.0 debian:bullseye debian:buster; do
  docker pull $baseimage
done

# Linux (x64, ARMv6, ARMv7, ARM64v8)
for flavour in linux-x64 linux-armv6 linux-armv7 linux-arm64v8; do
  if [ $PLATFORM = "all" ] || [ $PLATFORM = $flavour ]; then
    echo "Building $flavour..."
    docker build -t ns3-dev-$flavour $flavour
    mkdir $flavour-build
    docker run --rm -v $(pwd)/$flavour-build:/root/output ns3-dev-$flavour sh -c "cp -r /root/ns3/* /root/output"
    tar czvf $flavour.tgz $(pwd)/$flavour-build/*
  fi
done
ls -R
