#!/bin/bash
# =============================================================================
# Filename: prepare_update.sh
# Purpose: Do some prepare jobs for arch_build,like clone repos need updating,
#           place arch_build script, and this is also the entrypoint for arch_build,
#           after prepare jobs, arch_build would be executed by arch chroot.
# Usage: ./prepare_update.sh
# =============================================================================


main() {

    # packages have benn added into update_list, query update_list and git clone repos

    cd "$GITHUB_WORKSPACE"/repos
    local update_list=$(cat 'update_list' | awk '{print $1}')
    # make list
    update_list=($update_list)

    # get repo url from repo-name
    local repo_list=()
    for item in "${update_list[@]}"; do
        repo_list+=( "$(cat $item/url).git" )
    done

    # the files chroot need
    # clone repos
    cd "$GITHUB_WORKSPACE"/builddir/
    mkdir repos && cd repos
    for item in "${repo_list[@]}"; do
        git clone --depth=1 "$item"
    done
    cd ..
    cp ../utils/arch_build.sh ./repos

    # deal quirks & my_repo
    for item in "${update_list[@]}"; do
        # TODO: use a loop?
        if [ -f "$GITHUB_WORKSPACE/repos/$item/quirks" ]; then
            echo "$item have quirks"
            cp "$GITHUB_WORKSPACE/repos/$item/quirks" "$GITHUB_WORKSPACE/builddir/repos/$item"
        fi
        if [ -f "$GITHUB_WORKSPACE/repos/$item/my_repo" ]; then
            echo "$item is my_repo"
            cp "$GITHUB_WORKSPACE/repos/$item/my_repo" "$GITHUB_WORKSPACE/builddir/repos/$item"
        fi
        if [ -f "$GITHUB_WORKSPACE/repos/$item/aarch64" ]; then
            echo "$item is aarch64"
            cp "$GITHUB_WORKSPACE/repos/$item/aarch64" "$GITHUB_WORKSPACE/builddir/repos/$item"
        fi
    done

    # deal remove_list
    if [ -f "$GITHUB_WORKSPACE/repos/remove_list" ]; then
        cp "$GITHUB_WORKSPACE/repos/remove_list" "$GITHUB_WORKSPACE/builddir/repos"
    fi

    CHROOT=('root.x86_64' 'root.aarch64')

    for arch in "${CHROOT[@]}"; do
        sudo cp -r repos $arch/home/nuvole/

        echo "$AUR_KEY" | sudo tee $arch/home/nuvole/aur_key > /dev/null
        sudo chmod 400 "$arch/home/nuvole/aur_key"

        # avoid permission issues
        sudo arch-chroot $arch sh -c 'chown nuvole:nuvole -R /home/nuvole'
        sudo arch-chroot $arch sh -c "su - nuvole -c '/home/nuvole/repos/arch_build.sh $arch' "
    done
}

main
