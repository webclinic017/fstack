#!/bin/bash
set -x
set -e

apt get update
apt get upgrade -y

apt install -y sudo meson wget git nano 
sudo -i

apt-get install -y build-essential bc curl flex bison libelf-dev

KERNEL_VERSION="${KERNEL_VERSION:-$(uname -r)}"
kernel_version="$(echo "${KERNEL_VERSION}" | awk -vFS=- '{ print $1 }')"
major_version="$(echo "${KERNEL_VERSION}" | awk -vFS=. '{ print $1 }')"

mkdir -p /usr/src/linux
curl -sL "https://www.kernel.org/pub/linux/kernel/v${major_version}.x/linux-$kernel_version.tar.gz"     | tar --strip-components=1 -xzf - -C /usr/src/linux
#curl -sL "https://www.kernel.org/pub/linux/kernel/v5.x/linux-5.19.tar.gz"     | tar --strip-components=1 -xzf - -C /usr/src/linux
cd /usr/src/linux
zcat /proc/config.gz > .config
make ARCH=x86 oldconfig
make ARCH=x86 prepare
mkdir -p /lib/modules/$(uname -r)
ln -sf /usr/src/linux /lib/modules/$(uname -r)/source
ln -sf /usr/src/linux /lib/modules/$(uname -r)/build


#!/bin/bash
# clone F-Stack
mkdir -p /data
mkdir -p /data/f-stack

# Install git libnuma-dev
sudo apt -y install git libnuma-dev meson
git clone https://github.com/F-Stack/f-stack.git /data/f-stack

# Compile DPDK
cd /data/f-stack/dpdk
meson -Denable_kmods=true build
ninja -C build
ninja -C build install

# Upgrade pkg-config while version < 0.28
cd /data
wget https://pkg-config.freedesktop.org/releases/pkg-config-0.29.2.tar.gz
tar xzvf pkg-config-0.29.2.tar.gz
cd pkg-config-0.29.2
./configure --with-internal-glib
make
make install
mv /usr/bin/pkg-config /usr/bin/pkg-config.bak
ln -s /usr/local/bin/pkg-config /usr/bin/pkg-config

# On Ubuntu, use gawk instead of the default mawk.
sudo apt-get -y install gawk  # or execute `sudo update-alternatives --config awk` to choose gawk.

# Install dependencies for F-Stack
sudo apt-get -y gcc make libssl-dev                            # On ubuntu
#apt-get install gcc gmake openssl pkgconf libepoll-shim       # On FreeBSD

# Compile f-stack lib
export FF_PATH=/data/f-stack
export PKG_CONFIG_PATH=/usr/lib64/pkgconfig:/usr/local/lib64/pkgconfig:/usr/lib/pkgconfig
cd /data/f-stack/lib
make

# Compile Nginx
cd ../app/nginx-1.16.1
./configure --prefix=/usr/local/nginx_fstack --with-ff_module
make
make install

# Compile Redis
cd ../redis-5.0.5
make

# Compile f-stack tools
cd ../../tools
make

# Compile helloworld examples
cd ../examples
make

# Set hugepage (Linux only)
# single-node system
echo 1024 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

# or NUMA (Linux only)
echo 1024 > /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages
echo 1024 > /sys/devices/system/node/node1/hugepages/hugepages-2048kB/nr_hugepages

# Using Hugepage with the DPDK (Linux only)
mkdir /mnt/huge
mount -t hugetlbfs nodev /mnt/huge

# Close ASLR; it is necessary in multiple process (Linux only)
echo 0 > /proc/sys/kernel/randomize_va_space

# Install python for running DPDK python scripts
# sudo apt install python # On ubuntu

# Offload NIC
# For Linux:
modprobe uio
insmod /data/f-stack/dpdk/build/kernel/linux/igb_uio/igb_uio.ko
insmod /data/f-stack/dpdk/build/kernel/linux/kni/rte_kni.ko carrier=on
python dpdk-devbind.py --status
ifconfig eth0 down
python dpdk-devbind.py --bind=igb_uio eth0
