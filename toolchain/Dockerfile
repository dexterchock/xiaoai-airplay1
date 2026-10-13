# syntax=docker/dockerfile:1.4
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture armhf \
    && rm -f /etc/apt/sources.list.d/ubuntu.sources \
    && printf '%s\n' \
      'deb [arch=amd64] http://archive.ubuntu.com/ubuntu noble main restricted universe multiverse' \
      'deb [arch=amd64] http://archive.ubuntu.com/ubuntu noble-updates main restricted universe multiverse' \
      'deb [arch=amd64] http://security.ubuntu.com/ubuntu noble-security main restricted universe multiverse' \
      > /etc/apt/sources.list \
    && printf '%s\n' \
      'deb [arch=armhf] http://ports.ubuntu.com/ubuntu-ports noble main restricted universe multiverse' \
      'deb [arch=armhf] http://ports.ubuntu.com/ubuntu-ports noble-updates main restricted universe multiverse' \
      'deb [arch=armhf] http://ports.ubuntu.com/ubuntu-ports noble-security main restricted universe multiverse' \
      > /etc/apt/sources.list.d/armhf.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
      ca-certificates curl git bzip2 xz-utils \
      build-essential cmake ninja-build pkg-config \
      autoconf automake libtool \
      crossbuild-essential-armhf \
      libssl-dev:armhf zlib1g-dev:armhf \
      libpopt-dev:armhf libconfig-dev:armhf \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
CMD ["/bin/bash"]