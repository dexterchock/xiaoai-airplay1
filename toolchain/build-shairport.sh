#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="xiaoai-airplay1-toolchain:dev"
SHAIRPORT_VERSION="4.3.5"
SHAIRPORT_SRC_DIR="${PROJECT_ROOT}/build/shairport-sync-src"
OUTPUT_BIN="${PROJECT_ROOT}/build/shairport-sync"

if [ -f "${OUTPUT_BIN}" ]; then
  echo "==> Static shairport-sync already exists at ${OUTPUT_BIN}, skipping build."
  exit 0
fi

make -C "${PROJECT_ROOT}/toolchain" build

mkdir -p "${PROJECT_ROOT}/build"

if [ ! -d "${SHAIRPORT_SRC_DIR}" ]; then
  echo "==> Cloning shairport-sync ${SHAIRPORT_VERSION}..."
  git clone --depth 1 --branch "${SHAIRPORT_VERSION}" \
    https://github.com/mikebrady/shairport-sync.git "${SHAIRPORT_SRC_DIR}"
fi

echo "==> Building static shairport-sync (with SoXR + Apple ALAC) for ARMv7 Cortex-A53..."
docker run --rm -i \
  -v "${PROJECT_ROOT}":/workspace \
  -w /workspace/build/shairport-sync-src \
  "${IMAGE_NAME}" \
  bash << 'EOF'
set -euo pipefail
git config --global --add safe.directory "*"

OPT_FLAGS="-O3 -march=armv7-a -mtune=cortex-a53 -mfpu=neon-vfpv4 -mfloat-abi=hard -ffast-math"

# 1. Build static libasound.a
if [ ! -f /usr/lib/arm-linux-gnueabihf/libasound.a ]; then
  echo "==> Building static libasound.a for ARMv7..."
  mkdir -p /tmp/alsa
  cd /tmp/alsa
  ALSA_VER="1.2.12"
  curl -fsSL "https://www.alsa-project.org/files/pub/lib/alsa-lib-${ALSA_VER}.tar.bz2" -o alsa.tar.bz2 || \
  curl -fsSL "https://github.com/alsa-project/alsa-lib/releases/download/v${ALSA_VER}/alsa-lib-${ALSA_VER}.tar.bz2" -o alsa.tar.bz2
  tar -xjf alsa.tar.bz2
  cd "alsa-lib-${ALSA_VER}"
  ./configure \
    --host=arm-linux-gnueabihf \
    --enable-static \
    --disable-shared \
    --prefix=/usr \
    --libdir=/usr/lib/arm-linux-gnueabihf \
    --disable-python \
    CFLAGS="${OPT_FLAGS}"
  make -j$(nproc)
  make install
  rm -rf /tmp/alsa
fi

# 2. Build static libsoxr.a (without OpenMP to keep static pthread linking clean)
if [ ! -f /usr/lib/arm-linux-gnueabihf/libsoxr.a ]; then
  echo "==> Building static libsoxr.a for ARMv7..."
  mkdir -p /tmp/soxr
  cd /tmp/soxr
  if curl -fsSL "http://archive.ubuntu.com/ubuntu/pool/universe/libs/libsoxr/libsoxr_0.1.3.orig.tar.xz" -o soxr.tar.xz; then
    tar -xJf soxr.tar.xz --strip-components=1
  else
    git clone --depth 1 https://github.com/chirlu/soxr.git .
  fi
  cmake -S . -B build \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=arm \
    -DCMAKE_C_COMPILER=arm-linux-gnueabihf-gcc \
    -DCMAKE_C_FLAGS="${OPT_FLAGS}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DLIB_INSTALL_DIR=/usr/lib/arm-linux-gnueabihf \
    -DBUILD_SHARED_LIBS=OFF \
    -DWITH_OPENMP=OFF \
    -DBUILD_TESTS=OFF \
    -DBUILD_EXAMPLES=OFF
  cmake --build build -j$(nproc)
  cmake --install build
  rm -rf /tmp/soxr
fi

# 3. Build static Apple ALAC decoder (libalac.a)
if [ ! -f /usr/lib/arm-linux-gnueabihf/libalac.a ]; then
  echo "==> Building static libalac.a for ARMv7..."
  git clone --depth 1 https://github.com/mikebrady/alac.git /tmp/alac
  cd /tmp/alac
  autoreconf -fi
  ./configure \
    --host=arm-linux-gnueabihf \
    --enable-static \
    --disable-shared \
    --prefix=/usr \
    --libdir=/usr/lib/arm-linux-gnueabihf \
    CFLAGS="${OPT_FLAGS}" \
    CXXFLAGS="${OPT_FLAGS}"
  make -j$(nproc)
  make install
  rm -rf /tmp/alac
fi

# 4. Build static shairport-sync
cd /workspace/build/shairport-sync-src
autoreconf -fi
export PKG_CONFIG_PATH="/usr/lib/arm-linux-gnueabihf/pkgconfig:/usr/share/pkgconfig"
export PKG_CONFIG_LIBDIR="/usr/lib/arm-linux-gnueabihf/pkgconfig:/usr/share/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR=""

./configure \
  --host=arm-linux-gnueabihf \
  --with-alsa \
  --with-stdout \
  --with-pipe \
  --with-tinysvcmdns \
  --with-ssl=openssl \
  --with-metadata \
  --with-soxr \
  --with-apple-alac \
  CFLAGS="${OPT_FLAGS}" \
  CXXFLAGS="${OPT_FLAGS}" \
  LDFLAGS="-static -L/usr/lib/arm-linux-gnueabihf" \
  LIBS="-lm -lpthread -ldl"

make -j$(nproc)
arm-linux-gnueabihf-strip shairport-sync
cp shairport-sync /workspace/build/shairport-sync
EOF

echo "==> Static shairport-sync built successfully: ${OUTPUT_BIN}"
ls -lh "${OUTPUT_BIN}"
