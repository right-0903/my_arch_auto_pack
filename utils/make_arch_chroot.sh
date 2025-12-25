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
sudo sh -c 'tar xf ./archlinux-bootstrap-x86_64.tar.zst --numeric-owner'
sudo chown $(whoami):$(whoami) -R ./root.x86_64

# config pacman
echo 'Server = http://mirror.rackspace.com/archlinux/$repo/os/$arch' >> ./root.x86_64/etc/pacman.d/mirrorlist
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 4/' ./root.x86_64/etc/pacman.conf

# check config
cat ./root.x86_64/etc/pacman.d/mirrorlist | grep -Ei '^Server'
cat ./root.x86_64/etc/pacman.conf | grep 'ParallelDownloads'

if grep -qE '^OPTIONS.*!debug.*$' $CHROOT_DIR/etc/makepkg.conf; then
    echo "makepkg debug disabled!"
else
    # disable deubg
    sed -i 's/^\(OPTIONS.*\)\(debug\)\(.*)$\)/\1!\2\3/p' $CHROOT_DIR/etc/makepkg.conf
fi

# avoid pacman issue
sudo chown root:root -R ./root.x86_64

# refer to https://wiki.archlinux.org/title/Install_Arch_Linux_from_existing_Linux#Downloading_basic_tools
sudo mount --bind ./root.x86_64/ ./root.x86_64/

# initialize pacman
sudo arch-chroot ./root.x86_64/ sh -c 'pacman-key --init && pacman-key --populate'

# setting my arch repo databases if they exist
URL='https://github.com/right-0903/my_arch_auto_pack/releases/download/packages'
PACKAGE_DB='nuvole-arch'

# use '-L' because github will redirect it, and we check DB only.
http_code=$(curl -L -o /dev/null -w "%{http_code}" "$URL/$PACKAGE_DB.db.tar.gz")
if [ "$http_code" -eq 200 ]; then
    # use dependnecies built before
    sudo sh -c "echo [$PACKAGE_DB] >> ./root.x86_64/etc/pacman.conf"
    sudo sh -c "echo 'Server = $URL' >> ./root.x86_64/etc/pacman.conf"
else
    echo "repo can't be added, http code is $http_code"
fi

# trust key
sudo install -m 444 "$GITHUB_WORKSPACE/keys/CA909D46CD1890BE.asc" './root.x86_64/root'
sudo arch-chroot ./root.x86_64/ sh -c 'pacman-key --add /root/CA909D46CD1890BE.asc && pacman-key --lsign-key CA909D46CD1890BE'

# update and install
sudo arch-chroot ./root.x86_64/ sh -c 'pacman -Syu base-devel git curl openssh --noconfirm'

# makepkg refuse to work when user is root, create a new user instead of hacking makepkg
sudo arch-chroot ./root.x86_64/ sh -c 'useradd -m -s /bin/bash nuvole'
# avoid the interactive shell for password
sudo sh -c 'echo "nuvole ALL=(ALL) NOPASSWD: /usr/bin/pacman" >> ./root.x86_64/etc/sudoers'
