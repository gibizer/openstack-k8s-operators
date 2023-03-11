#! /bin/bash
set -e
set -x

dep_version() {
    local source=$1
    local target=$2

    cd "$source"
    local dep_hash=$(go mod graph | grep $source | grep $target | head -n 1 | cut -d ' ' -f2 | cut -d '@' -f2 | cut -d '-' -f3)
    echo "$dep_hash"
}


checkout_version() {
    local repo=$1
    local hash=$2

    cd "$repo"
    git checkout --quiet "$hash"
}

replace_dep_with_local() {
    local repo=$1
    local dep_name=$2

    cd "$repo"
    local dep=$(go mod graph | grep $repo | grep $dep_name | head -n 1 | cut -d ' ' -f2 | cut -d '@' -f1)
    local module=$(echo "$dep" | cut -d'/' -f4-)

    go mod edit -replace "$dep=../$dep_name/$module"
    go mod tidy

    if [ -d "./api" ]; then
        cd "./api"
        go mod edit -replace "$dep=../../$dep_name/$module"
        go mod tidy
    fi
    if [ -d "./apis" ]; then
        cd "./apis"
        go mod edit -replace "$dep=../../$dep_name/$module"
        go mod tidy
    fi
}


repo=$1

echo "update submodules according of the dependencies in $repo"

for submodule in $(git submodule status | cut -d ' ' -f3); do
    if [ "$repo" = "$submodule" ]; then
        continue
    fi

    version=$(dep_version "$repo" "$submodule")
    if [ "$version" != "" ]; then
        echo "checking out $submodule@$version"
        _=$(checkout_version "$submodule" "$version")
        _=$(replace_dep_with_local "$repo" "$submodule")
    fi
done

