sudo apt-get -q update
sudo apt-get -q upgrade -y

#!/bin/bash
set -x
set -e

#apt-get -q update

sudo apt-get -q update
sudo apt-get -q upgrade -y

sudo apt-get -q install -y make meson git gcc openssl libssl-dev bc libnuma1 libnuma-dev libpcre3 libpcre3-dev zlib1g-dev net-tools pkg-config

################################################################################
# Download kernel headers
################################################################################

#!/bin/bash
set -x
set -e

#KERNEL_VERSION="${KERNEL_VERSION:-$(uname -r)}"
#kernel_version="$(echo "${KERNEL_VERSION}" | awk -vFS=- '{ print $5 }')"
#major_version="$(echo "${KERNEL_VERSION}" | awk -vFS=. '{ print $5 }')"

#sudo apt-get install -y build-essential bc curl flex bison libelf-dev
#sudo apt-get install bzip2
#mkdir -p /usr/src/linux
#curl "https://mirrors.edge.kernel.org/pub/linux/kernel/v5.x/"     
#cd /usr/src/linux
##mkdir -p /lib/modules/$(uname -r)
#ln -sf /usr/src/linux /lib/modules/$(uname -r)/source
#ln -sf /usr/src/linux /lib/modules/$(uname -r)/build


KERNEL_VERSION="${KERNEL_VERSION:-$(uname -r)}"
kernel_version="$(echo "${KERNEL_VERSION}" | awk -vFS=- '{ print $1 }')"
major_version="$(echo "${KERNEL_VERSION}" | awk -vFS=. '{ print $1 }')"

sudo apt-get install -y build-essential bc curl flex bison libelf-dev

mkdir -p /usr/src/linux
curl -sL "https://www.kernel.org/pub/linux/kernel/v${major_version}.x/linux-$kernel_version.tar.gz"     | tar --strip-components=1 -xzf - -C /usr/src/linux
cd /usr/src/linux
zcat /proc/config.gz > .config
make ARCH=x86 oldconfig
make ARCH=x86 prepare
mkdir -p /lib/modules/$(uname -r)
ln -sf /usr/src/linux /lib/modules/$(uname -r)/source
ln -sf /usr/src/linux /lib/modules/$(uname -r)/build

################################################################################
# Download f-stack
################################################################################
#!/bin/sh
set -e
set -x
alias sudo="sudo -E"

export FSTACK="${PWD}/f-stack"
export IF="enp0s8"
export PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig

echo "FSTACK=${PWD}/f-stack" | sudo tee -a /etc/environment
echo "IF=enp0s8" | sudo tee -a /etc/environment

git clone https://github.com/F-Stack/f-stack.git

# To "Compile dpdk in virtual machine":
sed -i 's/pci_intx_mask_supported/true || pci_intx_mask_supported/' f-stack/dpdk/kernel/linux/igb_uio/igb_uio.c

################################################################################
# Build and install DPDK (20.11.0(LTS))
################################################################################
cd ${FSTACK}/dpdk
meson -Denable_kmods=true build
ninja -C build
sudo ninja -C build install
sudo ldconfig

################################################################################
# Setup DPDK
################################################################################

# Configure hugepages
# https://doc.dpdk.org/guides/linux_gsg/sys_reqs.html#use-of-hugepages-in-the-linux-environment
echo 1024 | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
# Make the hugepages available for DPDK
sudo mkdir /mnt/huge
sudo mount -t hugetlbfs nodev /mnt/huge

# Linux drivers / Offload NIC
# https://doc.dpdk.org/guides/linux_gsg/linux_drivers.html
# https://doc.dpdk.org/guides/prog_guide/kernel_nic_interface.html
# Install kernel modules
sudo modprobe uio
sudo insmod ${FSTACK}/dpdk/build/kernel/linux/igb_uio/igb_uio.ko
sudo insmod ${FSTACK}/dpdk/build/kernel/linux/kni/rte_kni.ko carrier=on

${FSTACK}/dpdk/usertools/dpdk-devbind.py --status
sudo ifconfig ${IF} down
sudo ${FSTACK}/dpdk/usertools/dpdk-devbind.py --bind=igb_uio ${IF}
${FSTACK}/dpdk/usertools/dpdk-devbind.py --status

################################################################################
# Build and install F-Stack
################################################################################
cd ${FSTACK}/lib
make
sudo make install

################################################################################
# Build tools
################################################################################
cd ${FSTACK}/tools
# https://github.com/F-Stack/f-stack/blob/dev/doc/F-Stack_Build_Guide.md#compile-tools-in-ubuntu
sed -i 's/\\#define/#define/' netstat/Makefile
sed -i 's/snprintf(gw_addr, sizeof(gw_addr), "%s\/resolve", iface_name);/{int ret=snprintf(gw_addr, sizeof(gw_addr), "%s\/resolve", iface_name);if (ret < 0) abort();}/' netstat/nhgrp.c
sed -i 's/snprintf(gw_addr, sizeof(gw_addr), "%s\/resolve", iface_name);/{int ret=snprintf(gw_addr, sizeof(gw_addr), "%s\/resolve", iface_name);if (ret < 0) abort();}/' netstat/nhops.c
make
sudo make install

echo "# Run example using:"
echo "vagrant ssh"
echo "cd ${FSTACK}/example"
echo "make"
echo "sudo ./helloworld --conf ../config.ini"
echo
echo "# Run tools like:"
echo "vagrant ssh"
echo "sudo ff_netstat -s -p udp"
echo
