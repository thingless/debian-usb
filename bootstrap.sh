#!/bin/sh
# Author: za3k
# Create a forget-base.img
# Uses debian's 'debootstrap', which requires: ar, sh, wget, and basic tools
# This image will boot in both EFI and non-EFI BIOS. It also ships with a memory checker. GPT-supporting BIOS is required.
# Set http_proxy=??? to speed up a slightly bigger set of things than CACHE_DOWNLOADS=YES
export REPRODUCIBLE=YES # lies--but until ext4 is reproducible we do the best we can
export VERIFY_SHA=NO
export CACHE_DOWNLOADS=YES
DISTRO=forget-base
DEBIAN_VERSION=stretch
MANDATORY_PACKAGES="e2fsprogs"
BOOTSTRAP_PACKAGES="wget dosfstools"
CLI_PACKAGES="autossh bsd-mailx build-essential deluge deluge-console deluged electrum fail2ban feh finch git gnupg hddtemp iotop irssi libfaketime lxc lynx mdadm mplayer mutt nginx nmap openvpn parallel pv python qemu rsync smartmontools sudo ssh tmux tor trickle vim-tiny w3m wpasupplicant zsh"
X_PACKAGES="awesome xorg xterm"
PACKAGES="${MANDATORY_PACKAGES} ${BOOTSTRAP_PACKAGES} ${CLI_PACKAGES} ${X_PACKAGES}"
export ROOT_PASSWORD=root
export CHROOT=/tmp/${DISTRO}-chroot
OVERLAY_MOUNT=/tmp/${DISTRO}-overlay
MEMTEST_MOUNT=/tmp/${DISTRO}-memtest-mount
MEMTEST_DIR=/tmp/${DISTRO}-memtest
MEMTEST_ISO=/tmp/${DISTRO}-memtest-iso
IMAGE=/tmp/${DISTRO}.img
RANDOM_HOSTNAME=$(cat /proc/sys/kernel/random/uuid)
HOSTNAME="${HOSTNAME:-$RANDOM_HOSTNAME}"
XDG_CACHE_HOME=${XDG_CACHE_HOME:-$HOME/.cache}
if [ $CACHE_DOWNLOADS=YES ]; then
    export CACHE_DIR=${CACHE_DIR:-${XDG_CACHE_HOME}/forget-bootstrap}
fi
if [ -z "$ARCH" ]; then
    ARCH=amd64
    which dkpg >/dev/null 2>/dev/null && ARCH=$(dpkg --print-archicture)
fi
DEBOOTSTRAP_VERSION=1.0.92
DEBOOTSTRAP=/tmp/debootstrap
export LOOP_DEVICE=${LOOP_DEVICE:-/dev/loop0}
IMAGE_SIZE=8G
export EFI_PARTITION_SIZE=+8M
export SYSTEM_PARTITION_SIZE=+6G
export GRUB_PARTITION_SIZE=+1M
export OVERLAY_PARTITION_SIZE="" # Rest of the space
export EFI_PARTITION_NAME="EFI System"
export SYSTEM_PARTITION_NAME="system"
export GRUB_PARTITION_NAME="BIOS Boot Partition"
export OVERLAY_PARTITION_NAME="config"

grub_cfg() {
sed "s/4.9.0-3-amd64/${LINUX_VERSION}/g"  <<'EOF'
# Do not re-generate this file. It is manually written.
set default=0
set timeout=5
set menu_color_normal=cyan/blue
set menu_color_highlight=white/blue

insmod efi_gop
insmod efi_uga
insmod vbe

insmod font
if loadfont ${prefix}/fonts/unicode.pf2
then
  insmod gfxterm
  set gfxmode=auto
  set gfxpayload=keep
  terminal_output gfxterm
fi

#set root='hd2,gpt2'
#search --no-floppy --set=root --label system --hint hd0,msdos2

menuentry 'rw/ro Persistent Overlay' {
	insmod gzio
	if [ x$grub_platform = xxen ]; then insmod xzio; insmod lzopio; fi
	insmod part_gpt
	insmod ext2
	echo	'Loading Linux 4.9.0-3-amd64 ...'
	linux	/boot/vmlinuz-4.9.0-3-amd64 root=PARTLABEL=system net.ifnames=0 overlaytype=rw/ro quiet
	echo	'Loading initial ramdisk ...'
	initrd	/boot/initrd.img-4.9.0-3-amd64
}
menuentry 'tmpfs/ro Temporary Overlay' {
	insmod gzio
	if [ x$grub_platform = xxen ]; then insmod xzio; insmod lzopio; fi
	insmod part_gpt
	insmod ext2
	echo	'Loading Linux 4.9.0-3-amd64 ...'
	linux	/boot/vmlinuz-4.9.0-3-amd64 root=PARTLABEL=system net.ifnames=0 overlaytype=mem/none/ro quiet
	echo	'Loading initial ramdisk ...'
	initrd	/boot/initrd.img-4.9.0-3-amd64
}
menuentry 'tmpfs/ro/ro Temporary + Persistent Overlay' {
	insmod gzio
	if [ x$grub_platform = xxen ]; then insmod xzio; insmod lzopio; fi
	insmod part_gpt
	insmod ext2
	echo	'Loading Linux 4.9.0-3-amd64 ...'
	linux	/boot/vmlinuz-4.9.0-3-amd64 root=PARTLABEL=system net.ifnames=0 overlaytype=mem/ro/ro quiet
	echo	'Loading initial ramdisk ...'
	initrd	/boot/initrd.img-4.9.0-3-amd64
}
menuentry 'memfs/memfs In-Memory Overlay' {
	insmod gzio
	if [ x$grub_platform = xxen ]; then insmod xzio; insmod lzopio; fi
	insmod part_gpt
	insmod ext2
	echo	'Loading Linux 4.9.0-3-amd64 ...'
	linux	/boot/vmlinuz-4.9.0-3-amd64 root=PARTLABEL=system net.ifnames=0 overlaytype=mem/mem quiet
	echo	'Loading initial ramdisk ...'
	initrd	/boot/initrd.img-4.9.0-3-amd64
}
menuentry 'memfs In-memory System boot' {
	insmod gzio
	if [ x$grub_platform = xxen ]; then insmod xzio; insmod lzopio; fi
	insmod part_gpt
	insmod ext2
	echo	'Loading Linux 4.9.0-3-amd64 ...'
	linux	/boot/vmlinuz-4.9.0-3-amd64 root=PARTLABEL=system net.ifnames=0 overlaytype=none/mem quiet
	echo	'Loading initial ramdisk ...'
	initrd	/boot/initrd.img-4.9.0-3-amd64
}
menuentry 'memfs Flat memory boot (of rw/ro overlay)' {
	insmod gzio
	if [ x$grub_platform = xxen ]; then insmod xzio; insmod lzopio; fi
	insmod part_gpt
	insmod ext2
	echo	'Loading Linux 4.9.0-3-amd64 ...'
	linux	/boot/vmlinuz-4.9.0-3-amd64 root=PARTLABEL=system net.ifnames=0 overlaytype=mem quiet
	echo	'Loading initial ramdisk ...'
	initrd	/boot/initrd.img-4.9.0-3-amd64
}
menuentry 'rw System Maintenance boot' {
	insmod gzio
	if [ x$grub_platform = xxen ]; then insmod xzio; insmod lzopio; fi
	insmod part_gpt
	insmod ext2
	echo	'Loading Linux 4.9.0-3-amd64 ...'
	linux	/boot/vmlinuz-4.9.0-3-amd64 root=PARTLABEL=system net.ifnames=0 overlaytype=none/rw quiet
	echo	'Loading initial ramdisk ...'
	initrd	/boot/initrd.img-4.9.0-3-amd64
}
menuentry 'MemTest86 (non-EFI only) by PassMark' {
  linux16 /boot/memtest86
}
menuentry 'MemTest86+ (non-EFI only), GPL' {
  linux16 /boot/memtest86+
}
menuentry 'MemTest86, 32-bit (EFI only) by PassMark' {
  set root='hd0,gpt1'
  chainloader /EFI/MEMTEST86/BOOTIA32.EFI
}
menuentry 'MemTest86, 64-bit (EFI only) by PassMark' {
  set root='hd0,gpt1'
  chainloader /EFI/MEMTEST86/BOOTX64.EFI
}
EOF
}

overlay_hook() {
cat <<'EOF'
#!/bin/sh
case $1 in
prereqs)
  exit 0
  ;;
esac

. /scripts/functions
MYTAG="root-overlay"

overlaytype=rw
root_rw_access=y
for CMD_PARAM in $(cat /proc/cmdline); do
  case ${CMD_PARAM} in
    overlaytype=*)
      overlaytype=${CMD_PARAM#overlaytype=}
      ;;
    root_ro=*)
      root_rw_access=${CMD_PARAM#root_rw_access=}
      ;;
  esac
done

move_to_mem() {
  mkdir -p /tmp/mem
  /bin/mount -t tmpfs tmpfs /tmp/mem
  /bin/cp -a "$1"/* /tmp/mem
  /bin/umount "$1"
  /bin/mount -o move /tmp/mem "$1"
}

case $overlaytype in
  rw/ro|mem/none/ro|mem/ro/ro|mem/mem|mem|none/mem|none/rw)
    log_begin_msg "${MYTAG} Beginning overlay of type ${overlaytype}"
    log_end_msg
    ;;
  *)
    log_failure_msg "${MYAG} Unrecognized overlay type ${overlaytype}"
    exit 0
    ;;
esac

#set -x
log_begin_msg "Moving root filesystem"
/bin/mount -o move ${rootmnt} /mnt/ro
log_end_msg

case $overlaytype in
  none/rw)
    log_begin_msg "Remounting root filesystem read-write"
    /bin/mount -o remount,rw /mnt/ro
    log_end_msg
    ;;
esac
if [ "${root_rw_access}" = y ]; then
case $overlaytype in
  rw/ro|mem/none/ro|mem/ro/ro)
    log_begin_msg "Remounting root filesystem for submount"
    /bin/mount -o remount,rw /mnt/ro
    log_end_msg
    ;;
esac
fi

case $overlaytype in
  rw/ro)
    log_begin_msg "Mount upper filesystem rw"
    /bin/mount /dev/disk/by-partlabel/config /mnt/rw
    log_end_msg
    ;;
  mem/ro/ro|mem/mem|mem)
    log_begin_msg "Mount upper filesystem read-only"
    /bin/mount -o ro /dev/disk/by-partlabel/config /mnt/rw
    log_end_msg
    ;;
  mem/none/ro)
    log_begin_msg "Create upper filesystem in memory"
    /bin/mount -t tmpfs tmpfs /mnt/rw
    mkdir -p /mnt/rw/work /mnt/rw/upper
    log_end_msg
    ;;
esac

case $overlaytype in
  mem/mem)
    log_begin_msg "Moving upper filesystem to memory"
    move_to_mem /mnt/rw
    log_end_msg
    ;;
esac

case $overlaytype in
  mem/mem|none/mem)
    log_begin_msg "Moving lower filesystem to memory"
    move_to_mem /mnt/ro
    log_end_msg
    ;;
esac

case $overlaytype in
  rw/ro|mem/none/ro|mem/mem)
    log_begin_msg "Mounting rw/ro overlay"
    /bin/mount -t overlay overlay -o noatime,lowerdir=/mnt/ro,upperdir=/mnt/rw/upper,workdir=/mnt/rw/work ${rootmnt}
    log_end_msg
    log_begin_msg "Moving underlying filesystems to overlay"
    /bin/mount -o move /mnt/ro ${rootmnt}/media/lower
    /bin/mount -o move /mnt/rw ${rootmnt}/media/rw
    log_end_msg
    ;;
  mem)
    log_begin_msg "Mounting ro/ro overlay"
    /bin/mount -t overlay overlay -o noatime,lowerdir=/mnt/rw/upper:/mnt/ro ${rootmnt}
    log_end_msg
    ;;
  mem/ro/ro)
    log_begin_msg "Making ram fs"
    mkdir -p /tmp/mem
    mount -t tmpfs tmpfs /tmp/mem
    mkdir -p /tmp/mem/work /tmp/mem/upper
    log_end_msg
    log_begin_msg "Mounting rw/ro/ro overlay"
    /bin/mount -t overlay overlay -o noatime,lowerdir=/mnt/rw/upper:/mnt/ro,upperdir=/tmp/mem/upper,workdir=/tmp/mem/work ${rootmnt}
    log_end_msg
    log_begin_msg "Moving underlying filesystems to overlay"
    /bin/mount -o move /mnt/ro ${rootmnt}/media/lower
    /bin/mount -o move /mnt/rw ${rootmnt}/media/rw
    /bin/mount -o move /tmp/mem ${rootmnt}/media/mem
    log_end_msg
    ;;
  none/rw|none/mem)
    log_begin_msg "Moving filesystem back to root"
    /bin/mount -o move /mnt/ro ${rootmnt}
    log_end_msg
    ;;
esac

case $overlaytype in
  mem)
    log_begin_msg "Moving combined filesystem to memory"
    move_to_mem ${rootmnt}
    log_end_msg
    ;;
esac

case $overlaytype in
  mem)
    log_begin_msg "Unmounting underlying disk filesystems"
    /bin/umount /mnt/ro
    /bin/umount /mnt/rw
    log_end_msg
    ;;
esac

log_success_msg "${MYTAG} successfully set up ${overlaytype}  root fs using overlay"
EOF
}

media_hook() {
cat <<'EOF'
#!/bin/sh

. /usr/share/initramfs-tools/scripts/functions
. /usr/share/initramfs-tools/hook-functions

mkdir -p ${DESTDIR}/mnt/rw
mkdir -p ${DESTDIR}/mnt/ro
copy_exec /sbin/fsck
copy_exec /sbin/fsck.ext4
copy_exec /sbin/logsave
#copy_exec /sbin/blkid
EOF
}

hosts() {
cat <<EOF
127.0.0.1 localhost
127.0.1.1 $HOSTNAME

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback $HOSTNAME
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
EOF
}

interfaces(){
  INTERFACE=${INTERFACE:-eth0}
cat <<EOF
# interfaces(5) file used by ifup(8) and ifdown(8)
# Include files from /etc/network/interfaces.d:
source-directory /etc/network/interfaces.d

auto ${INTERFACE}
iface ${INTERFACE} inet dhcp
EOF
}

adjtime() {
    echo "0.0 0 0.0"
    echo "0"
    echo "UTC"
}

resolv() {
    echo "nameserver 8.8.8.8"
    echo "nameserver 2001:4860:4860::8888"
}

command_exists() {
    which "$1" >/dev/null 2>/dev/null
}
debootstrap_nocache() {
    curl -s http://ftp.debian.org/debian/pool/main/d/debootstrap/debootstrap_${DEBOOTSTRAP_VERSION}.tar.gz | tar xzO debootstrap-${DEBOOTSTRAP_VERSION}/debootstrap
}
debootstrap() {
    if [ -z "${CACHE_DIR}" ]; then
        debootstrap_nocache
    else
        mkdir -p "${CACHE_DIR}"
        TARGET="${CACHE_DIR}/debootstrap"
        [ -s "${TARGET}" ] || debootstrap_nocache >"${TARGET}"
        cat "${TARGET}"
    fi
}
memtest86plus_bin_nocache() {
    curl -s http://www.memtest.org/download/5.01/memtest86+-5.01.bin.gz | zcat
}
memtest86plus_bin() {
    if [ -z "${CACHE_DIR}" ]; then
        memtest86plus_bin_nocache
    else
        mkdir -p "${CACHE_DIR}"
        TARGET="${CACHE_DIR}/memtest86+.bin"
        [ -s "${TARGET}" ] || memtest86plus_bin_nocache >"${TARGET}"
        cat "${TARGET}"
    fi
}
memtest86_iso_nocache() {
    curl -s https://www.memtest86.com/downloads/memtest86-iso.tar.gz | tar xzO Memtest86-7.4.iso
}
memtest86_iso() {
    if [ -z "${CACHE_DIR}" ]; then
        memtest86_iso_nocache
    else
        mkdir -p "${CACHE_DIR}"
        TARGET="${CACHE_DIR}/memtest86.iso"
        [ -s "${TARGET}" ] || memtest86_iso_nocache >"${TARGET}"
        cat "${TARGET}"
    fi
}
reproducible_uuid() {
    echo 00000000-0000-0000-0000-00000000000$1
}
reproducible_fat_id() {
    echo 0000000${1}
}
mkfs_fat() {
    if [ $REPRODUCIBLE = YES ]; then
        sudo mkfs.fat "$1" -i $(reproducible_fat_id)
    else
        sudo mkfs.fat "$1"
    fi
}
mkfs_ext4() {
    if [ $REPRODUCIBLE = YES ]; then
        sudo mkfs.ext4 "$1" -q
    else
        sudo mkfs.ext4 "$1" -q -U $(reproducible_uuid $2) -o ""
        echo "Can't make ext2/3/4 filesystem reproducible yet, skipping" >/dev/stderr
    fi
}

fdisk_partition() {
    number="$1"
    size="$2"
    name="$3"
    echo n
    echo "${number}"
    echo
    echo "${size}"
    echo x
    echo n
    if [ "${number}" -gt 1 ]; then
        echo "${number}"
    fi
    echo "${name}"
    echo r
}
fdisk_format() {
    echo g
    fdisk_partition 1 "${EFI_PARTITION_SIZE}" "${EFI_PARTITION_NAME}"
    fdisk_partition 2 "${SYSTEM_PARTITION_SIZE}" "${SYSTEM_PARTITION_NAME}"
    fdisk_partition 3 "${GRUB_PARTITION_SIZE}" "${GRUB_PARTITION_NAME}"
    echo t # BIOS partition
    echo 3
    echo 4
    fdisk_partition 4 "${OVERLAY_PARTITION_SIZE}" "${OVERLAY_PARTITION_NAME}"
    # To make GPT disk images reproducible, manually set all the UUIDs
    if [ "${REPRODUCIBLE}" = YES ]; then
        echo x
        echo i
        reproducible_uuid 1
        for partnum in 1 2 3 4; do
            echo u
            echo ${partnum}
            reproducible_uuid $((partnum+1))
        done
        echo r
    fi
    echo w
}

outside_chroot() {
    set -eE
    set -x
    rm -f ${IMAGE}
    sudo rm -rf ${MEMTEST_DIR}

    # Make the USB disk image
    #fallocate -l ${IMAGE_SIZE} ${IMAGE}
    truncate -s ${IMAGE_SIZE} ${IMAGE}
    # truncate -s instead makes a 'sparse' image. see how they compare?
    [ $VERIFY_SHA = YES ] && echo "SHA1 (${IMAGE}) = bcc8c0ca9e402eee924a6046966d18b1f66eb577" | sha1sum --check --quiet

    # Format the image as a GPT image. There will be four partitions:
    # - EFI
    # - System partition
    # - Non-EFI grub partition
    # - Overlay partition
    fdisk_format | /sbin/fdisk ${IMAGE} >/dev/null
    [ $VERIFY_SHA = YES ] && echo "SHA1 (${IMAGE}) = 1701878bc69d0477df2948a2bba549f61337b686" | sha1sum --check --quiet
    EFI_PARTITION=${LOOP_DEVICE}p1
    SYSTEM_PARTITION=${LOOP_DEVICE}p2
    GRUB_PARTITION=${LOOP_DEVICE}p3
    CONFIG_PARTITION=${LOOP_DEVICE}p4
    # Because the EFI partition is mounted by partition name, it's remounted after fdisk runs while self-hosting. Fix.
    sudo umount ${EFI_PARTITION} 2>/dev/null || true
    sudo umount ${SYSTEM_PARTITION} 2>/dev/null || true
    sudo umount ${CONFIG_PARTITION} 2>/dev/null || true

    # Create filesystems on each partition
    # Mount all partitions using a loopback device
    if [ $(cat /sys/module/loop/parameters/max_part) = "0" ]; then
    sudo modprobe -r loop
    sudo modprobe loop max_part=31
    fi
    sudo losetup ${LOOP_DEVICE} /tmp/forget-base.img
    remove_loop() {
        sudo losetup -d ${LOOP_DEVICE}
    }
    trap remove_loop EXIT

    # Make a FAT32 filesystem for EFI
    mkfs_fat ${EFI_PARTITION}
    [ $VERIFY_SHA = YES ] && echo "SHA1 (${EFI_PARTITION}) = cc7803986ebc700a2e0d5b4e1135d8c5bf264ec0" | sha1sum --check --quiet

    # Make an EXT4 filesystem for the system
    mkfs_ext4 ${SYSTEM_PARTITION} 2

    # No filesystem needed for GRUB BIOS partition
    [ $VERIFY_SHA = YES ] && echo "SHA1 (${GRUB_PARTITION}) = 3b71f43ff30f4b15b5cd85dd9e95ebc7e84eb5a3" | sha1sum --check --quiet

    # Make an EXT4 filesystem for the overlay
    mkfs_ext4 ${CONFIG_PARTITION} 4

    # Set up directories needed by overlay
    mkdir -p ${OVERLAY_MOUNT}
    sudo mount ${CONFIG_PARTITION} ${OVERLAY_MOUNT}
    unmount_overlay() {
        sudo umount ${OVERLAY_MOUNT}
        remove_loop
    }
    trap unmount_overlay EXIT  
    sudo mkdir -p ${OVERLAY_MOUNT}/{upper,work}
    sudo umount ${OVERLAY_MOUNT}
    trap remove_loop EXIT

    # Download memtest86+ and memtest86
    mkdir -p ${MEMTEST_DIR}
    memtest86plus_bin >${MEMTEST_DIR}/memtest86+
    chmod +x ${MEMTEST_DIR}/memtest86+
    [ $VERIFY_SHA = YES ] && echo "SHA1 (${MEMTEST_DIR}/memtest86+) = 636d34c0302b2cc8061281ae3a572b1c1e74f1cd" | sha1sum --check --quiet
    memtest86_iso >${MEMTEST_ISO}
    [ $VERIFY_SHA = YES ] && echo "SHA1 (${MEMTEST_ISO}) = d63040395891b70949c6a53972dde3618ff57b43" | sha1sum --check --quiet
    mkdir -p ${MEMTEST_MOUNT}
    sudo mount -o loop ${MEMTEST_ISO} ${MEMTEST_MOUNT}
    unmount_memtest() {
        sudo umount ${MEMTEST_MOUNT}
        remove_loop
    }
    trap unmount_memtest EXIT
    cp ${MEMTEST_MOUNT}/isolinux/memtest ${MEMTEST_DIR}/memtest86
    [ $VERIFY_SHA = YES ] && echo "SHA1 (${MEMTEST_DIR}/memtest86) = b093be1b3620b0dd45cb0745fb1051ae8706434b" | sha1sum --check --quiet
    cp -r ${MEMTEST_MOUNT}/efi/boot ${MEMTEST_DIR}/MEMTEST86
    sudo umount ${MEMTEST_MOUNT}
    trap remove_loop EXIT

    # Mount for bootstrap
    mkdir -p ${CHROOT}
    sudo mount -o noatime ${SYSTEM_PARTITION} ${CHROOT}
    unmount_chroot() {
        sudo umount -R ${CHROOT}
        remove_loop
    }
    trap unmount_chroot EXIT

    # Use debian's debootstrap into the partition
    DEBOOTSTRAP_VERSION=$DEBOOTSTRAP_VERSION debootstrap >${DEBOOTSTRAP} && chmod +x ${DEBOOTSTRAP}
    #if [ -z $CACHE_DIR ]; then
        sudo PATH=/usr/sbin:/sbin:/usr/local/bin:/usr/bin:/bin ${DEBOOTSTRAP} --arch="${ARCH}" ${DEBIAN_VERSION} ${CHROOT} >/dev/null # It's just too noisy and has no config options
    # Couldn't figure out how to get '--make-tarball' to work yet
    #else
    #    mkdir -p "${CACHE_DIR}"
    #    unset TARGET
    #    TARBALL="${CACHE_DIR}/debootstrap.tar.gz"
    #    if [ \! -s "${TARBALL}" ]; then
    #        sudo ${DEBOOTSTRAP} --arch="${ARCH}" ${DEBIAN_VERSION} --make-tarball="${TARBALL}" $(mktemp) 
    #    fi
    #    sudo ${DEBOOTSTRAP} --arch="${ARCH}" ${DEBIAN_VERSION} --unpack-tarball="${TARBALL}" ${CHROOT}
    #fi

    # Set up the chroot
    # Mount weird partitions
    sudo mount --bind /dev ${CHROOT}/dev
    sudo mount --bind /proc ${CHROOT}/proc
    sudo mount --bind /sys ${CHROOT}/sys
    # Mount the EFI partition
    sudo mkdir -p ${CHROOT}/boot/efi
    sudo mount ${EFI_PARTITION} ${CHROOT}/boot/efi
    # Run the rest of the bootstrap inside the root
    sudo cp "$0" ${CHROOT}/
    sudo cp -r ${MEMTEST_DIR} ${CHROOT}/memtest
    sudo http_proxy="$http_proxy" HOSTNAME=$HOSTNAME ARCH=$ARCH GRUB_PARTITION=${GRUB_PARTITION} LOOP_DEVICE=${LOOP_DEVICE} LANG=C.UTF-8 PATH=/usr/sbin:/sbin:/usr/local/bin:/usr/bin:/bin chroot ${CHROOT} /bin/sh /bootstrap.sh inside_chroot
    
    # Tear down the chroot
    unmount_chroot
    trap - EXIT
    
    echo ${IMAGE}
}

inside_chroot() {
    # Install system files
    cat >/etc/fstab <<EOF
# file system                       mount point     type        options                                          dump pass
tmpfs                               /tmp            tmpfs       nodev,nosuid                                     0    0
PARTLABEL=EFI\040System             /boot/efi       vfat        defaults                                         0    1
EOF
    adjtime >/etc/adjtime
    echo $HOSTNAME >/etc/hostname
    HOSTNAME=$HOSTNAME hosts >/etc/hosts
    INTERFACE=eth0 interfaces >/etc/network/interfaces
    resolv >/etc/resolv.conf

    # Install packages
    cat >/etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian $DEBIAN_VERSION main
deb http://deb.debian.org/debian $DEBIAN_VERSION contrib
EOF
    apt-get -q update
    DEBIAN_FRONTEND=noninteractive apt-get -q install --assume-yes -o "Dpkg::Options::=--force-confdef" linux-image-${ARCH} grub-pc ${PACKAGES}

    # Install the bootloader
    grub-install --target=i386-pc ${LOOP_DEVICE}
    DEBIAN_FRONTEND=noninteractive apt-get -q install --assume-yes grub-efi
    grub-install --target=x86_64-efi --skip-fs-probe --efi-directory=/boot/efi --bootloader-id=boot ${LOOP_DEVICE} # boot = no configuration
    mv /memtest/MEMTEST86 /boot/efi/EFI/
    mv /memtest/memtest86 /memtest/memtest86+ /boot
    rmdir /memtest

    # Install custom initramfs
    overlay_hook >/etc/initramfs-tools/scripts/init-bottom/overlay
    chmod +x /etc/initramfs-tools/scripts/init-bottom/overlay
    media_hook >/etc/initramfs-tools/hooks/media
    chmod +x /etc/initramfs-tools/hooks/media
    update-initramfs -u -k all

    # Install custom grub boot script and disable grub boot
    # Check linux version. `uname -r` gives the host version so it won't work.
    LINUX_VERSION=$(dpkg -l | grep linux-image | awk '{print $2}' | head -n1 | sed -e 's/linux-image-//')
    
    LINUX_VERSION=${LINUX_VERSION} grub_cfg >/boot/grub/grub.cfg
    cp /boot/grub/grub.cfg /boot/grub/grub.bak
    sed -Eie "s/( +)(exec update-grub)/\1#\2/" /etc/kernel/postinst.d/zz-update-grub

    # Set up directories needed by overlay
    mkdir -p /media/{lower,mem,rw}

    # Set up root
    echo "root:${ROOT_PASSWD}"|chpasswd
}

if [ "$1" = "inside_chroot" ]; then
  http_proxy="$http_proxy" inside_chroot
else
  http_proxy="$http_proxy" outside_chroot
fi
