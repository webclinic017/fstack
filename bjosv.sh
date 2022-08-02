#!/bin/sh
set -e
set -x
alias sudo="sudo -E"

export FSTACK="${PWD}/f-stack"
export IF="enp0s8"
export PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig

echo "FSTACK=${PWD}/f-stack" | sudo tee -a /etc/environment
echo "IF=enp0s8" | sudo tee -a /etc/environment

sudo apt-get -q update
sudo apt-get -q install -y \
     make meson git gcc openssl libssl-dev linux-headers-$(uname -r) \
     bc libnuma1 libnuma-dev libpcre3 libpcre3-dev zlib1g-dev python \
     net-tools pkg-config

################################################################################
# Download f-stack
################################################################################
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
echo "vagant ssh"
echo "cd ${FSTACK}/example"
echo "make"
echo "sudo ./helloworld --conf ../config.ini"
echo
echo "# Run tools like:"
echo "vagant ssh"
echo "sudo ff_netstat -s -p udp"
echo
