#!/bin/bash

# change CWD
parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd "$parent_path"

release_path="./releases/$1"

# Check if release already exists
if [ -d "${release_path}" ]; then
    read -p "Release already exists. Would you like to continue ? (y or n) : " -n 1 -r
    echo    # (optional) move to a new line
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
       exit
    fi
fi

# create zip
mkdir "${release_path}"
zip -r "${release_path}/timber-corp-reinforcements-$1.zip" "./reinforcements"
