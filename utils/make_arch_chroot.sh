#!/bin/bash
# =============================================================================
# Filename: make_arch_chroot.sh
# Purpose: To create a chroot environment for arch linux
# Usage: ./make_arch_chroot.sh
# =============================================================================


# check if the execution user is root
if [ "$(id -u)" -eq 0 ]; then
    echo "error: please do not run this script as root."
    exit 1
fi

# update the github runner and install the dependencies we need
sudo apt-get update
sudo apt-get install -y arch-install-scripts zstd curl

# get into builddir, but root may do not know $GITHUB_WORKSPACE
# I use s series of sudo here rather than set absolute path for $GITHUB_WORKSPACE
mkdir "$GITHUB_WORKSPACE/builddir"
cd "$GITHUB_WORKSPACE/builddir"

# get archlinux-bootstrap and extract
curl http://mirror.rackspace.com/archlinux/iso/latest/archlinux-bootstrap-x86_64.tar.zst -o archlinux-bootstrap-x86_64.tar.zst
tar xf ./archlinux-bootstrap-x86_64.tar.zst --numeric-owner

# config pacman
echo 'Server = http://mirror.rackspace.com/archlinux/$repo/os/$arch' >> ./root.x86_64/etc/pacman.d/mirrorlist
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 4/' ./root.x86_64/etc/pacman.conf

# check config
cat ./root.x86_64/etc/pacman.d/mirrorlist | grep -Ei '^Server'
cat ./root.x86_64/etc/pacman.conf | grep 'ParallelDownloads'

# avoid pacman issue
sudo chown root:root -R ./root.x86_64

# refer to https://wiki.archlinux.org/title/Install_Arch_Linux_from_existing_Linux#Downloading_basic_tools
sudo mount --bind ./root.x86_64/ ./root.x86_64/

sudo arch-chroot ./root.x86_64/ sh -c 'pacman-key --init && pacman-key --populate && pacman -Syu --noconfirm'
sudo arch-chroot ./root.x86_64/ pacman -S base-devel git curl --noconfirm

# makepkg refuse to work when user is root, create a new user instead of hacking makepkg
sudo arch-chroot ./root.x86_64/ sh -c 'useradd -m -s /bin/bash nuvole'
# avoid the interactive shell for password
sudo sh -c 'echo "nuvole ALL=(ALL) NOPASSWD: /usr/bin/pacman" >> ./root.x86_64/etc/sudoers'
