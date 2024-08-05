#! /bin/bash

git_push() {
    echo "post_update"
    cd "$GITHUB_WORKSPACE"/repos

    git config --global user.name "nuvole"
    git config --global user.email "github-actions[bot]@users.noreply.github.com"
    git add update_list*
    git add */version

    update_list=$(cat 'update_list' | awk '{print $1}')

    cd "$GITHUB_WORKSPACE"
    localtime="$(timedatectl | grep 'Local time' | awk '{print $4"_"$5}')"
    git commit -m "$localtime: $update_list"
}

rename_invalid_name() {
    "$GITHUB_WORKSPACE/utils/change_invalid_name.sh" "$GITHUB_WORKSPACE/builddir/root.x86_64/home/nuvole/prod/"
}

git_push
rename_invalid_name
