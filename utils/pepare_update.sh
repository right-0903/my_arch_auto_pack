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

    # deal quirks
    for item in "${update_list[@]}"; do
        if [ -f "$GITHUB_WORKSPACE/repos/$item/quirks" ]; then
            echo "$item have quirks"
            cp "$GITHUB_WORKSPACE/repos/$item/quirks" "$GITHUB_WORKSPACE/builddir/repos/$item"
        fi
    done

    sudo cp -r repos root.x86_64/home/nuvole/

    # avoid permission issues
    sudo arch-chroot root.x86_64 sh -c 'chown nuvole:nuvole -R /home/nuvole'
    sudo arch-chroot root.x86_64 sh -c "su - nuvole -c '/home/nuvole/repos/arch_build.sh' "

}

main
