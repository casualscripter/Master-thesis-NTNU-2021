#!/usr/bin/env bash

# Usage:       ./make-virtio-kernel
#                or
#              bash make-virtio-kernel
# Description: Crossbuild four (4) RPi-kernels from given releases
#                of the raspberrypi kernel (github).
# Author:      Patrick Neumann (patrick@neumannsland.de)
# Platform:    Debian GNU/Linux (tested: 10.x)
# Version:     1.00
# Date:        23.09.2020
# License:     GPL3
# Warranty:    This program is distributed WITHOUT ANY WARRANTY

# mapping archive to linux kernel version:
# - 1.20200902-1 = 5.4.51
# - 1.20200601+amd64-1 = 5.4.42
# - 1.20200212-1 = 4.19.97
# - 1.20200114-1 = 4.19.93
# - 1.20190925-1 = 4.19.75
# - 1.20190819-1 = 4.19.66
# - 1.20190718-1 = 4.19.58
# - 1.20190709-1 = 4.19.57
# - 1.20190620-1 = 4.19.50 (32-Bit only!?)
# - 1.20190517-1 = 4.19.42 (32-Bit only!?)
# - 1.20190401-1 = 4.14.98 (32-Bit only!?)

# check os:
readonly OS="Debian GNU/Linux 10"
if ! grep --fixed-strings "${OS}" /usr/lib/os-release > /dev/null 2>&1 ; then
  echo "Only ${OS} is supported!"
  exit 1
fi

# check and install deps if necessary:
readonly PACKAGES="git
bc
bison
flex
libssl-dev
make
libc6dev
libncurses5-dev
crossbuild-essential-armhf
crossbuild-essential-arm64"

for package in ${PACKAGES} ; do
  if ! dpkg -s "${package}" > /dev/null 2>&1 ; then
    sudo apt install "${package}" --assume-yes
  fi     
done

# check and generate config fragment file if necessary:
if ! [ -r ./.config-virtio ] ; then
  cat <<EOF > ./.config-virtio 
CONFIG_BLK_MQ_VIRTIO=y
CONFIG_VIRTIO_BLK=y
CONFIG_VIRTIO_BLK_SCSI=y
CONFIG_VIRTIO_NET=y
CONFIG_VIRTIO_CONSOLE=y
CONFIG_DRM_VIRTIO_GPU=y
CONFIG_VIRTIO=y
CONFIG_VIRTIO_MENU=y
CONFIG_VIRTIO_PCI=y
CONFIG_VIRTIO_PCI_LEGACY=y
CONFIG_VIRTIO_BALLOON=y
CONFIG_VIRTIO_INPUT=y
CONFIG_VIRTIO_MMIO=y
CONFIG_VIRTIO_MMIO_CMDLINE_DEVICES=y
EOF
fi

# adjust number of jobs to cores (+ hypter threading):
readonly CPUS="$( lscpu | awk '/^CPU\(s\):/ { print $NF; }' )"
readonly JOBS="$( echo "12 * 1.5 / 1" | bc )"

readonly RELEASES="1.20200114-1
1.20200212-1
1.20200601+amd64-1
1.20200902-1
1.20190925-1
1.20190819-1
1.20190718-1
1.20190709-1
1.20190620-1
1.20190517-1
1.20190401-1
1.20190709-1
1.20190620-1
1.20190517-1
1.20190401-1"

for release in ${RELEASES} ; do
  # download, extract, version,...
  archive="raspberrypi-kernel_${release}.tar.gz"
  wget --timestamping "https://github.com/raspberrypi/linux/archive/${archive}"
  [ -r "${archive}" ] || continue
  tar xzf "${archive}"
  rm "${archive}"
  mv "./linux-${archive%.tar.gz}" ./linux

  cd ./linux

  version="$( awk '/^VERSION =/ { print $NF; }' ./Makefile )"
  patchlevel="$( awk '/^PATCHLEVEL =/ { print $NF; }' ./Makefile )"
  sublevel="$( awk '/^SUBLEVEL =/ { print $NF; }' Makefile )"

  target="${HOME}/RPi/Kernels/${version}.${patchlevel}.${sublevel}"
  [ -d "${target}" ] || mkdir -p "${target}"
  
  # RPi1...
  export KERNEL="kernel"
  export ARCH="arm"
  export CROSS_COMPILE="arm-linux-gnueabihf-"
  make bcmrpi_defconfig
  ./scripts/kconfig/merge_config.sh .config ../.config-virtio
  make --jobs="${JOBS}" zImage
  cp ./arch/arm/boot/zImage "${target}/RPi1-${KERNEL}-virtio"
  make clean

  # RPi2-3...
  export KERNEL="kernel7"
  make bcm2709_defconfig
  ./scripts/kconfig/merge_config.sh .config ../.config-virtio
  make --jobs="${JOBS}" zImage
  cp ./arch/arm/boot/zImage "${target}/RPi2-${KERNEL}-virtio"
  make clean

  # RPi4 (32 Bit)...
  export KERNEL="kernel7l"
  make bcm2711_defconfig
  ./scripts/kconfig/merge_config.sh .config ../.config-virtio
  make --jobs="${JOBS}" zImage
  cp ./arch/arm/boot/zImage "${target}/RPi4-${KERNEL}-virtio"
  make clean

  # RPi4 (64 Bit)...
  export KERNEL="kernel8"
  export ARCH="arm64"
  export CROSS_COMPILE="aarch64-linux-gnu-"
  make bcm2711_defconfig
  ./scripts/kconfig/merge_config.sh .config ../.config-virtio
  make --jobs="${JOBS}" Image
  cp ./arch/arm64/boot/Image "${target}/RPi4-${KERNEL}-virtio"

  # cleanup:
  cd ..
  rm -rf ./linux
done

exit 0
