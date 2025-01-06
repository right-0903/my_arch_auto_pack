#!/bin/bash
# =============================================================================
# Filename: post_update.sh
# Purpose: Do jobs after arch_build.sh, like remove debug packages, commit changes
#           to version and update_list.
# Usage: ./post_update.sh
# =============================================================================

ARCH="$1"
VER="version_$ARCH"

git_push() {
    echo "post_update"
    cd "$GITHUB_WORKSPACE"/repos

    local package_list=$(cat 'update_list' | awk '{print $1}')
    package_list=($package_list)
    local version_list=$(cat 'update_list' | awk '{print $2}')
    version_list=($version_list)

    mv 'remove_list' 'remove_list.old' && touch 'remove_list'

    local length=${#package_list[@]}
    for (( i=0; i<$length; i++ )); do
        if [[ "$ARCH" == 'aarch64' ]] && [ ! -f $GITHUB_WORKSPACE/repos/${package_list[$i]}/aarch64 ]; then
            git restore "${package_list[$i]}/$VER" || true
            continue
        fi

        # failed when there are multiple paired
        # if [ -f "$GITHUB_WORKSPACE/builddir/root.x86_64/home/nuvole/prod/"*"${package_list[$i]}"* ]; then
        if ls "$GITHUB_WORKSPACE/builddir/root.$ARCH/home/nuvole/prod/"*"${package_list[$i]}"* 1> /dev/null 2>&1; then
            printf "%s\t%s\t%s\n" 'succeed' "${package_list[$i]}" "${version_list[$i]}" >> "update_list_$ARCH"
        else
            printf "%s\t%s\t%s\n" 'failed' "${package_list[$i]}" "${version_list[$i]}" >> "update_list_$ARCH"
            # discard the update for version number, resotre if tracked else delete
            if git ls-files --error-unmatch "${package_list[$i]}/$VER" > /dev/null 2>&1; then
                git restore "${package_list[$i]}/$VER"
            else
                rm "${package_list[$i]}/$VER"
            fi
        fi
    done

    git config --global user.name "nuvole"
    git config --global user.email "github-actions[bot]@users.noreply.github.com"
    git add remove_list*
    git add update_list*
    git add */"version_$ARCH"

    localtime="$(timedatectl | grep 'Local time' | awk '{print $4"_"$5}')"
    git commit -m "$localtime: updated for $ARCH" -m "$(cat update_list_$ARCH)"
}

handle_prod() {

    local PROD_DIR="$GITHUB_WORKSPACE/builddir/root.$ARCH/home/nuvole/prod"
    # TODO: with makepkg option !debug
    # remove debug package
    if ls "$PROD_DIR"/*-debug-* 1> /dev/null 2>&1; then
        rm "$PROD_DIR"/*-debug-*
    fi

    # GPG sign
    echo "$GPG_SIGNING_KEY_ARCH" | gpg --import
    # the only one key, shoould be default
    # gpg --default-key "$GPG_SIGNING_KEY_ARCH_ID"

    for FILE in "$PROD_DIR"/*.pkg.tar.*; do
        echo "Signing $FILE"
        gpg --output "$FILE.sig" --detach-sig "$FILE"
    done

    # remove invalid characters from package name (github upload artifacts require this,
    # release upload does not, so disable it but keep it in case.)
    # "$GITHUB_WORKSPACE/utils/change_invalid_name.sh" "$GITHUB_WORKSPACE/builddir/root.x86_64/home/nuvole/prod/"

}

git_push
handle_prod
