#!/bin/bash
# =============================================================================
# Filename: query_update.sh
# Purpose: The script is the entrypoint, workflow will execute this first, this
#           script mainly used to determine the packages need updating, if there
#           are packages, then it would execute a series of scripts.
# Usage: ./query_update.sh
# =============================================================================


main() {

    cd "$GITHUB_WORKSPACE"/repos

    if [ -f 'update_list' ]; then
        # check if last update list is empty
        if [[ -n "$(<'update_list')" ]]; then
            mv 'update_list' 'update_list.old'
            touch 'update_list'
        fi
    else
        # if update list not exist(initialize or reset)
        touch 'update_list'
    fi

    for package in */ ; do
        # in the form package1 package2 ... rather than package1/ package2/ ...
        check_update "${package%/}"
    done

    # if there is an update, initialize archlinux container
    if [[ -n "$(<'update_list')" ]]; then
        echo "===============initialize archlinux container==============="
        "$GITHUB_WORKSPACE/utils/make_arch_chroot.sh"
        echo "==============archlinux container initialized==============="
        # packages have benn added into update_list, query update_list and git clone repos
        "$GITHUB_WORKSPACE/utils/prepare_update.sh"
        "$GITHUB_WORKSPACE/utils/post_update.sh"
    else
        echo "There is nothing to do."
        echo "There is nothing to do."
        echo "There is nothing to do."
    fi
}

check_update() {
    local package="$1"

    # github
    # url: https://github.com/username/repo-name
    # raw: https://raw.githubusercontent.com/username/repo-name/trunk/path-to/PKGBUILD

    # gitlab
    # url: https://host-domain-name/path-to/repo-name
    # raw: $url/-/raw/{master, main}/path-to/PKGBUILD
    # master example: https://gitlab.manjaro.org/packages/core/linux66
    # main example: https://gitlab.archlinux.org/archlinux/packaging/packages/linux-lts
    # TODO: handle main and master

    # aur
    # url: https://aur.archlinux.org/repo-name
    # raw: https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=repo-name

    # repo=$url.git

    # echo "$(pwd)"

    local url=$(cat "$package"/url)
    local pkg

    # may not exist, so use path to check its existence first.
    local host_path="$package"/host
    if [ -f "$host_path" ]; then
        :
    else
        echo "do not provide host site, use the default, aur.archlinux.org"
        ln -s ../default_host $host_path
    fi

    local host=$(cat $host_path)

    if [[ "$host" == 'github' ]]; then
        pkg=$(echo "$url" | sed 's/github/raw.githubusercontent/')/trunk/PKGBUILD
    elif [[ "$host" == 'gitlab' ]]; then
        # FIXME: it is not always main.
        pkg="${url}/-/raw/main/PKGBUILD"
    else # aur.archlinux.org
        pkg="https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=$package"
    fi

    # may not exist, so use path to check its existence first.
    local version_path="$package/version"

    local new_version=$(curl $pkg | awk -F= '{a[$1]=$2} END {print a["pkgver"] "-" a["pkgrel"]}')

    compare_version "$version_path" "$new_version"

    case $? in
        0)
            echo "There is nothing to do for $package"
            ;;
        1)
            echo "There are updates for $package"
            echo "$package $new_version" >> 'update_list'
            echo "$new_version" > "$version_path"
            ;;
    esac

}

compare_version() {

    local version_path=$1
    local new_version=$2

    if [[ -f "$version_path" ]]; then
        local version=$(cat "$version_path")
    else
        local version=""
    fi

    # we check if the new_version is equal to version, rather than bigger or less,
    # if version is null, then build it, and append new_version to it
    # (determine bigger or less is difficult for somthing like 6.10.3.zen1-1 and 6.9.3.zen1-2)
    if [[ "$version" == "$new_version" ]]; then
        return 0
    else # verison is null or different
        return 1
    fi
}

main
