#!/bin/bash
# =============================================================================
# Filename: query_update.sh
# Purpose: The script is the entrypoint, workflow will execute this first, this
#           script mainly used to determine the packages need updating, if there
#           are packages, then it would execute a series of scripts.
# Usage: ./query_update.sh
# =============================================================================

ARCH="$1"
UPDATE_FILE="update_list"

query_update() {

    cd "$GITHUB_WORKSPACE"/repos

    mv "$UPDATE_FILE" "$UPDATE_FILE.old" || true

    # append update entries to file
    for package in */ ; do
        # in the form package1 package2 ... rather than package1/ package2/ ...
        check_update "${package%/}"
    done

    mv "${UPDATE_FILE}_$ARCH" "${UPDATE_FILE}_$ARCH.old" || true
}


main() {

    query_update

    cd "$GITHUB_WORKSPACE"/repos

    # if there is an update, initialize archlinux container
    if [[ -n "$(<'update_list')" ]]; then
        echo "===============initialize archlinux container==============="
        case "$ARCH" in
            'x86_64')
                "$GITHUB_WORKSPACE/utils/make_arch_chroot.sh"
                ;;
            'aarch64')
                "$GITHUB_WORKSPACE/utils/make_arch_chroot_aarch64.sh"
                ;;
        esac
        echo "==============archlinux container initialized==============="
        # packages have benn added into update_list, query update_list and git clone repos
        "$GITHUB_WORKSPACE/utils/prepare_update.sh" "$ARCH"
        "$GITHUB_WORKSPACE/utils/post_update.sh" "$ARCH"
    else
        echo "There is nothing to do."
        echo "There is nothing to do."
        echo "There is nothing to do."
    fi
}

check_update() {
    local package="$1"

    if [[ "$ARCH" == 'aarch64' ]]; then
        if [ ! -f "$GITHUB_WORKSPACE/repos/$package/aarch64" ]; then
            return 0
        fi
    fi

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
        local pkg2="${url}/-/raw/master/PKGBUILD"
    else # aur.archlinux.org
        pkg="https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=$package"
    fi

    # may not exist, so use path to check its existence first.
    local version_path="$package/version_$ARCH"

    # FIXME: handle epoch, ver=epoch:pkgver-pkgrel, but epoch will carry a colon : which causes
    # release process replace it with a dot. , currently, I ignore epoch, one day pacman may miss a update.
    local new_version=$(curl --silent $pkg | awk -F= '{a[$1]=$2} END {print a["pkgver"] "-" a["pkgrel"]}')
    if [[ "$new_version" == '-' ]]; then
        new_version=$(curl --silent $pkg2 | awk -F= '{a[$1]=$2} END {print a["pkgver"] "-" a["pkgrel"]}')
    fi

    # if there is a command to get version (i.e. pkgver=$(...))
    if echo "$new_version" | grep -E '^\$(.*)-[0-9]+$'; then
        pkgver=$(echo "$new_version" | sed -n 's/^\$(\(.*\))-[0-9]$/\1/p')
        pkgrel=$(echo "$new_version" | sed -n 's/.*-\([0-9]\)$/\1/p')
        new_version=$(eval $pkgver)-$pkgrel
    fi

    # FIXME: let us use `makepkg --printsrcinfo > .SRCINFO` to determine
    # version things, there is a change to .SRCINFO if a update is coming,
    # then dynamically fetching version by shell
    compare_version "$version_path" "$new_version"

    case $? in
        0)
            echo "There is nothing to do for $package"
            ;;
        1)
            echo "There are updates for $package"
            echo "$package $new_version" >> "$UPDATE_FILE"
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
