#!/bin/bash
# =============================================================================
# Filename: arch_build.sh
# Purpose: Used by arch chroot to pack packages in the repos
# Usage: ./arch_build.sh
# =============================================================================


PROD_DIR='/home/nuvole/prod'

main() {

    # import gpg
    cd /home/nuvole/repos
    gpg --import ./*/keys/pgp/*

    # make use of cores
    export MAKEFLAGS=-j$(nproc)
    printenv MAKEFLAGS
    # building from files in memory
    export BUILDDIR=/tmp/makepkg makepkg

    # build
    mkdir "$PROD_DIR"
    for package in */ ; do
        build $package
        echo "${package%/} done!"
    done

    cd "$PROD_DIR"
    # download my arch repo databases if they exist, then update them
    local URL='https://github.com/right-0903/my_arch_auto_pack/releases/download/packages'
    local PACKAGE_DB='nuvole-arch.db.tar.gz'
    local FILES_DB='nuvole-arch.files.tar.gz'
    if curl --output "$PACKAGE_DB" --silent --head --fail "$URL/$PACKAGE_DB" > /dev/null; then
        # use '-L' because github will redirect it.
        curl -L --output $PACKAGE_DB "$URL/nuvole-arch.db"
    fi

    if curl --output "$FILES_DB" --silent --head --fail "$URL/$FILES_DB" > /dev/null; then
        curl -L --output $FILES_DB "$URL/nuvole-arch.files"
    fi

    # only add packages that are not already in the databases, not --sign for now
    repo-add --new "$PACKAGE_DB" *.pkg.tar.zst

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
    mv ./*zst "$PROD_DIR"
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
