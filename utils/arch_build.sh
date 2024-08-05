#!/bin/bash
# =============================================================================
# Filename: arch_build.sh
# Purpose: Used by arch chroot to pack packages in the repos
# Usage: ./arch_build.sh
# =============================================================================


main() {

    # import gpg
    cd /home/nuvole/repos
    gpg --import ./*/keys/pgp/*

    # make use of cores
    export MAKEFLAGS=-j$(nproc)
    printenv MAKEFLAGS

    # build
    mkdir /home/nuvole/prod
    for package in */ ; do
        build $package
        echo "${package%/} done!"
    done
    # fix permission for upload-artifact
    chmod 777 -R /home/nuvole
}

build() {
    cd "$1"
    prepare
    # TODO: parse the order of dependencies, only install makedepends
    makepkg -s --noconfirm
    post
    mv ./*zst /home/nuvole/prod
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

main
