#! /bin/bash

main() {

    # packages have benn added into update_list, query update_list and git clone repos

    cd "$GITHUB_WORKSPACE"/repos
    local update_list=$(cat 'update_list' | awk '{print $1}')
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
    cp ../utils/build.sh ./repos

    sudo cp -r repos root.x86_64/home/nuvole/

    # avoid permission issues
    sudo arch-chroot root.x86_64 sh -c 'chown nuvole:nuvole -R /home/nuvole'
    sudo arch-chroot root.x86_64 sh -c "su - nuvole -c '/home/nuvole/repos/build.sh' "

}

main
