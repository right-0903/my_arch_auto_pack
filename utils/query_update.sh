#! /bin/bash

main() {

    cd "$GITHUB_WORKSPACE"/repos

    local update_list='update_list'
    if [ -f "$update_list" ]; then
        # check if last update list is empty
        if [[ -n "$(<$update_list)" ]]; then
            mv "update_list" "update_list.old"
            touch "$update_list"
        fi
    else
        touch "$update_list"
    fi


    for package in */ ; do
        # in the form package1 package2 ... rather than package1/ package2/ ...
        check_update "${package%/}"
    done

    # if there is an update, initialize archlinux container
    if [[ -n "$(<$update_list)" ]]; then
        echo "===============initialize archlinux container==============="
        "$GITHUB_WORKSPACE/utils/make_arch_chroot.sh"
        echo "==============archlinux container initialized==============="
        # packages have benn added into update_list, query update_list and git clone repos
        "$GITHUB_WORKSPACE/utils/update.sh"
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
    # raw: $url/-/raw/main/path-to/PKGBUILD

    # gitlab
    # url: https://aur.archlinux.org/repo-name
    # raw: https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=repo-name

    # repo=$url.git

    # echo "$(pwd)"

    local url=$(cat "$package"/url)
    local pkg

    local host="$package"/host
    if [ -f "$host" ]; then
        :
    else
        echo "do not provide host site, use the default, aur.archlinux.org"
        ln -s ../default_host $host
    fi

    host=$(cat $host)

    if [[ "$host" == 'github' ]]; then
        pkg=$(echo "$url" | sed 's/github/raw.githubusercontent/')/trunk/PKGBUILD
    elif [[ "$host" == 'gitlab' ]]; then
        pkg="${url}/-/raw/main/PKGBUILD"
    else # aur.archlinux.org
        pkg="https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=$package"
    fi

    local version="$package/version"

    local new_version=$(curl $pkg | awk -F= '{a[$1]=$2} END {print a["pkgver"] "-" a["pkgrel"]}')

    local update_list='update_list'

    compare_version "$version" "$new_version"

    case $? in
        0)
            echo "There is nothing to do for $package"
            ;;
        1)
            echo "There are updates for $package"
            echo "$package $new_version" >> $update_list
            # TODO: modify it after build
            echo "$new_version" > "$version"
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

    # if version is null, then build it, and append new_version to it
    # next time, we check if the new_version is equal to version
    # rather than bigger or less
    # (determine bigger or less is difficult for somthing like 6.10.3.zen1-1 and 6.9.3.zen1-2)
    if [[ "$version" == "$new_version" ]]; then
        return 0
    else # verison is null or less
        return 1
    fi
}

main
