#! /bin/bash

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
