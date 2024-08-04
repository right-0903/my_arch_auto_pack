#! /bin/bash

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
        cd "$package"
        # TODO: parse the order of dependencies, only install makedepends
        prepare
        makepkg -s --noconfirm
        mv ./*zst /home/nuvole/prod
        cd ..
        echo "${package%/} done!"
    done
    # fix permission for upload-artifact
    chmod 777 -R /home/nuvole
}

prepare() {
    echo "do the prepare jobs"
    # add patches for some packages
    if [ -f 'quirks' ]; then
        chmod +x quirks
        ./quirks
    fi
}

main
