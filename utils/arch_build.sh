#!/bin/bash
# =============================================================================
# Filename: arch_build.sh
# Purpose: Used by arch chroot to pack packages in the repos
# Usage: ./arch_build.sh
# =============================================================================


PROD_DIR='/home/nuvole/prod'
ARCH="$1" # only used by aarch64

main() {

    # import gpg
    cd /home/nuvole/repos
    gpg --import ./*/keys/pgp/*

    # make use of cores
    export MAKEFLAGS=-j$(nproc)
    printenv MAKEFLAGS
    # building from files in memory
    export BUILDDIR=/tmp/makepkg makepkg
    # set packager
    export PACKAGER='nuvole <me@nuvole.eu.org>'

    # build
    mkdir "$PROD_DIR"
    for package in */ ; do
        if [[ $ARCH == 'aarch64' ]]; then
            if [ ! -f "$package/aarch64" ]; then
                continue
            fi
        fi

        # for now, ignore epoch
        if grep -q 'epoch=' "$package/PKGBUILD"; then
            echo "remove epoch for ${package%/}"
        fi
        sed -i 's/^\s*epoch=[0-9]\+//' "$package/PKGBUILD"
        build $package
        update_repo ${package%/}
        echo "${package%/} done!"
    done

    cd "$PROD_DIR"
    # download my arch repo databases if they exist, then update them
    local URL='https://github.com/right-0903/my_arch_auto_pack/releases/download/packages'
    local PACKAGE_DB='nuvole-arch.db.tar.gz'
    local FILES_DB='nuvole-arch.files.tar.gz'

    if [[ $ARCH == 'aarch64' ]]; then
        local PACKAGE_DB='nuvole-arch-aarch64.db.tar.gz'
        local FILES_DB='nuvole-arch-aarch64.files.tar.gz'
    fi

    # use '-L' because github will redirect it, and we check DB only.
    http_code=$(curl -L -o /dev/null -w "%{http_code}" "$URL/$PACKAGE_DB")
    if [ "$http_code" -eq 200 ]; then
        curl -L -o $PACKAGE_DB "$URL/$PACKAGE_DB"
        curl -L -o $FILES_DB "$URL/$FILES_DB"
    fi

    # TODO: if there is a repo update broken, the non tar.gz suffix should be safe, so use it
    # a repo update broken may cause a invalid tar.gz file, check it then replace it
    # curl -L --output $PACKAGE_DB "(echo $URL/$PACKAGE_DB | sed 's/\.tar\.gz$//')"
    # or we can check if repo is valid before upload it

    # FIXME: --new for only add packages that are not already in the databases, not --sign for now
    # This causes package info unchanged, new package may not same as the old, like size
    repo-add --new "$PACKAGE_DB" *.pkg.tar.*

    # repo-remove when packages in repos are removed
    local remove_list=$(cat /home/nuvole/repos/remove_list)
    remove_list=($remove_list)

    local length=${#remove_list[@]}
    for (( i=0; i<$length; i++ )); do
        repo-remove "$PACKAGE_DB" "${remove_list[$i]}"
    done

    # fix permission for upload-artifact
    chmod 777 -R /home/nuvole
}

build() {
    cd "$1"
    prepare
    # TODO: parse the order of dependencies, only install makedepends
    # maybe a qsort with the cmp function(package A is later(greater) than package B if B in A's dependencies)
    makepkg -s --noconfirm
    post
    mv ./*.pkg.tar.* "$PROD_DIR"
    rm -rf /tmp/makepkg/* # clean
    cd ..
}

prepare() {
    echo "do the prepare jobs, $(pwd)"
    # add patches for some packages
    if [ -f 'quirks' ]; then
        chmod +x quirks
        ./quirks before
    fi
}

post() {
    if [ -f 'quirks' ]; then
        ./quirks after
    fi
}

update_repo() {
    if [[ -f "$1/my_repo" ]]; then
        # only aur use this now
        local AUR_KEY_PATH='/home/nuvole/aur_key'
        GIT_SSH_COMMAND="ssh -i $AUR_KEY_PATH -o StrictHostKeyChecking=no" git clone "ssh://aur@aur.archlinux.org/$1.git" 'my_repo'
        cd 'my_repo'
        makepkg --printsrcinfo > .SRCINFO
        git config user.name "nuvole"
        git config user.email "github-actions[bot]@users.noreply.github.com"
        git add .
        local new_version=$(cat .SRCINFO | awk -F ' = ' '{a[$1]=$2} END {print a["\tpkgver"] "-" a["\tpkgrel"]}')
        git commit -m "v$new_version: updated by bot"
        GIT_SSH_COMMAND="ssh -i $AUR_KEY_PATH" git push
        cd ..
        rm -rf 'my_repo'
    fi
}

main
