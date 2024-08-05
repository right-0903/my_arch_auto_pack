#!/bin/bash
# =============================================================================
# Filename: post_update.sh
# Purpose: Do jobs after arch_build.sh, like remove debug packages, commit changes
#           to version and update_list.
# Usage: ./post_update.sh
# =============================================================================


git_push() {
    echo "post_update"
    cd "$GITHUB_WORKSPACE"/repos

    local package_list=$(cat 'update_list' | awk '{print $1}')
    package_list=($package_list)
    local version_list=$(cat 'update_list' | awk '{print $2}')
    version_list=($version_list)

    # reset update_list, mark succeed or failed
    rm 'update_list' && touch 'update_list'

    local length=${#package_list[@]}
    for (( i=0; i<$length; i++ )); do
        # failed when there are multiple paired
        # if [ -f "$GITHUB_WORKSPACE/builddir/root.x86_64/home/nuvole/prod/"*"${package_list[$i]}"* ]; then
        if ls "$GITHUB_WORKSPACE/builddir/root.x86_64/home/nuvole/prod/"*"${package_list[$i]}"* 1> /dev/null 2>&1; then
            printf "%s\t%s\t%s\n" 'succeed' "${package_list[$i]}" "${version_list[$i]}" >> 'update_list'
        else
            printf "%s\t%s\t%s\n" 'failed' "${package_list[$i]}" "${version_list[$i]}" >> 'update_list'
            # discard the update for version number, resotre if tracked else delete
            # TODO: not test functionality yet
            if git ls-files --error-unmatch "${package_list[$i]}/version" > /dev/null 2>&1; then
                git restore "${package_list[$i]}/version"
            else
                rm "${package_list[$i]}/version"
            fi
        fi
    done

    git config --global user.name "nuvole"
    git config --global user.email "github-actions[bot]@users.noreply.github.com"
    git add update_list*
    git add */version

    localtime="$(timedatectl | grep 'Local time' | awk '{print $4"_"$5}')"
    git commit -m "$localtime: updated" -m "$(cat 'update_list')"
}

handle_prod() {
    # TODO: with makepkg option !debug
    # remove debug package
    if ls "$GITHUB_WORKSPACE/builddir/root.x86_64/home/nuvole/prod/"*-debug-* 1> /dev/null 2>&1; then
        rm "$GITHUB_WORKSPACE/builddir/root.x86_64/home/nuvole/prod/"*-debug-*
    fi

    # remove invalid characters from package name (github upload artifacts require this,
    # release upload does not, so disable it but keep it in case.)
    # "$GITHUB_WORKSPACE/utils/change_invalid_name.sh" "$GITHUB_WORKSPACE/builddir/root.x86_64/home/nuvole/prod/"
}

git_push
handle_prod
