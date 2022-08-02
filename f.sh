$ sudo -i
# in centos and redhat
$ yum install -y git gcc openssl-devel kernel-devel-$(uname -r) bc numactl-devel python
# in ubuntu
$ apt-get install git gcc openssl libssl-dev linux-headers-$(uname -r) bc libnuma1 libnuma-dev libpcre3 libpcre3-dev zlib1g-dev python

$ mkdir /data/f-stack
$ git clone https://github.com/F-Stack/f-stack.git /data/f-stack

# compile dpdk
$ cd /data/f-stack/dpdk
$ meson -Denable_kmods=true build
$ ninja -C build
$ ninja -C build install

# Upgrade pkg-config while version < 0.28
$ cd /data
$ wget https://pkg-config.freedesktop.org/releases/pkg-config-0.29.2.tar.gz
$ tar xzvf pkg-config-0.29.2.tar.gz
$ cd pkg-config-0.29.2
$ ./configure --with-internal-glib
$ make
$ make install
$ mv /usr/bin/pkg-config /usr/bin/pkg-config.bak
$ ln -s /usr/local/bin/pkg-config /usr/bin/pkg-config

# Compile f-stack lib
$ export FF_PATH=/data/f-stack
$ export PKG_CONFIG_PATH=/usr/lib64/pkgconfig:/usr/local/lib64/pkgconfig:/usr/lib/pkgconfig
$ cd /data/f-stack/lib
$ make

# Compile Nginx
$ cd ../app/nginx-1.16.1
$ ./configure --prefix=/usr/local/nginx_fstack --with-ff_module
$ make
$ make install

# Compile Redis
$ cd ../redis-5.0.5
$ make

# Compile f-stack tools
$ cd ../../tools
$ make

# Compile helloworld examples
$ cd ../examples
$ make
