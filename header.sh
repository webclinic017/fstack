#!/bin/bash
set -x
set -e

KERNEL_VERSION="${KERNEL_VERSION:-$(uname -r)}"
kernel_version="$(echo "${KERNEL_VERSION}" | awk -vFS=- '{ print $1 }')"
major_version="$(echo "${KERNEL_VERSION}" | awk -vFS=. '{ print $1 }')"

apt-get install -y build-essential bc curl flex bison libelf-dev

mkdir -p /usr/src/linux
#curl -sL "https://www.kernel.org/pub/linux/kernel/v${major_version}.x/linux-$kernel_version.tar.gz"     | tar --strip-components=1 -xzf - -C /usr/src/linux
curl -sL "https://www.kernel.org/pub/linux/kernel/v5.x/linux-5.19.tar.gz"     | tar --strip-components=1 -xzf - -C /usr/src/linux
cd /usr/src/linux
zcat /proc/config.gz > .config
make ARCH=x86 oldconfig
make ARCH=x86 prepare
mkdir -p /lib/modules/$(uname -r)
ln -sf /usr/src/linux /lib/modules/$(uname -r)/source
ln -sf /usr/src/linux /lib/modules/$(uname -r)/build
