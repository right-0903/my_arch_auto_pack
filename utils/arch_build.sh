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
    # set packager
    export PACKAGER='nuvole <me@nuvole.eu.org>'

    # build
    mkdir "$PROD_DIR"
    for package in */ ; do
        # for now, ignore epoch
        if grep -q 'epoch=' "$package/PKGBUILD"; then
            echo "remove epoch for ${package%/}"
        fi
        sed -i 's/^\s*epoch=[0-9]\+//' "$package/PKGBUILD"
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
        curl -L --output $PACKAGE_DB "$URL/$PACKAGE_DB"
    fi

    if curl --output "$FILES_DB" --silent --head --fail "$URL/$FILES_DB" > /dev/null; then
        curl -L --output $FILES_DB "$URL/$FILES_DB"
    fi

    # TODO: if there is a repo update broken, the non tar.gz suffix should be safe, so use it
    # a repo update broken may cause a invalid tar.gz file, check it then replace it
    # curl -L --output $PACKAGE_DB "(echo $URL/$PACKAGE_DB | sed 's/\.tar\.gz$//')"
    # or we can check if repo is valid before upload it

    # only add packages that are not already in the databases, not --sign for now
    repo-add --new "$PACKAGE_DB" *.pkg.tar.zst

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
