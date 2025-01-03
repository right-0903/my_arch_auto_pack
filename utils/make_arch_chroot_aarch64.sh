#!/bin/bash
# =============================================================================
# Filename: make_arch_chroot_aarch64.sh
# Purpose: To create a chroot environment for arch linux arm
# Usage: ./make_arch_chroot_aarch64.sh
# =============================================================================


# check if the execution user is root
if [ "$(id -u)" -eq 0 ]; then
    echo "error: please do not run this script as root."
    exit 1
fi

# update the github runner and install the dependencies we need
sudo apt-get update
sudo apt-get install -y zstd curl libarchive-tools qemu-user-static parted arch-install-scripts

# handle binfmt_misc, https://access.redhat.com/solutions/1985633
if grep -q 'binfmt_misc' /proc/mounts; then
    echo "binfmt_misc mounted"
else
    mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc
fi

echo 1 > /proc/sys/fs/binfmt_misc/status
echo ':qemu-aarch64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-aarch64-static:FP' > /proc/sys/fs/binfmt_misc/register

# get into builddir, but root may do not know $GITHUB_WORKSPACE
# I use s series of sudo here rather than set absolute path for $GITHUB_WORKSPACE
mkdir "$GITHUB_WORKSPACE/builddir" || true
cd "$GITHUB_WORKSPACE/builddir"

CHROOT_DIR='root.aarch64'
mkdir $CHROOT_DIR

# get archlinux-bootstrap and extract
MIRROR_URL='http://fl.us.mirror.archlinuxarm.org'
curl "$MIRROR_URL/os/ArchLinuxARM-aarch64-latest.tar.gz" -o ArchLinuxARM-aarch64-latest.tar.gz
bsdtar -xpf ArchLinuxARM-aarch64-latest.tar.gz -C ${CHROOT_DIR}

cp /usr/bin/qemu-aarch64-static  ${CHROOT_DIR}/usr/bin/qemu-aarch64-static

# enable ParallelDownloads
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 4/' ${CHROOT_DIR}/etc/pacman.conf
echo "Server = $MIRROR_URL"'/$arch/$repo' >> ${CHROOT_DIR}/etc/pacman.d/mirrorlist

# setting my arch repo databases if they exist
local URL='https://github.com/right-0903/my_arch_auto_pack/releases/download/aarch64-packages'
local PACKAGE_DB='nuvole-arch.db.tar.gz'

# use '-L' because github will redirect it, and we check DB only.
http_code=$(curl -L -o /dev/null -w "%{http_code}" "$URL/$PACKAGE_DB")
if [ "$http_code" -eq 200 ]; then
    # add my repo to install kernel and firmware
    echo '[nuvole-arch]' >> ${CHROOT_DIR}/etc/pacman.conf
    echo "Server = https://github.com/right-0903/my_arch_auto_pack/releases/download/aarch64-packages" >> ${CHROOT_DIR}/etc/pacman.conf
fi

# disable deubg
sed -i 's/^\(OPTIONS.*\)\(debug\)\(.*)$\)/\1!\2\3/p' $CHROOT_DIR/etc/makepkg.conf

# avoid pacman issue
sudo chown root:root -R ${CHROOT_DIR}

# refer to https://wiki.archlinux.org/title/Install_Arch_Linux_from_existing_Linux#Downloading_basic_tools
sudo mount --bind ${CHROOT_DIR} ${CHROOT_DIR}

# initialize pacman
sudo arch-chroot ${CHROOT_DIR} sh -c 'pacman-key --init && pacman-key --populate archlinuxarm'

# trust key
sudo install -m 444 "$GITHUB_WORKSPACE/keys/CA909D46CD1890BE.asc" "${CHROOT_DIR}/root"
sudo arch-chroot ${CHROOT_DIR} sh -c 'pacman-key --add /root/CA909D46CD1890BE.asc && pacman-key --lsign-key CA909D46CD1890BE'

# speed up
sudo arch-chroot ${CHROOT_DIR} sh -c 'pacman -Rns linux-aarch64 --noconfirm'

# update and install
sudo arch-chroot ${CHROOT_DIR} sh -c 'pacman -Syu base-devel git curl openssh --noconfirm'

# makepkg refuse to work when user is root, create a new user instead of hacking makepkg
sudo arch-chroot ${CHROOT_DIR} sh -c 'useradd -m -s /bin/bash nuvole'
# avoid the interactive shell for password
sudo sh -c "echo 'nuvole ALL=(ALL) NOPASSWD: /usr/bin/pacman' >> ${CHROOT_DIR}/etc/sudoers"
