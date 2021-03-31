#!/usr/bin/env bash

##
# Script run on the server to deploy the latest code. $1 should be the directory where the code will
# be checked out, built, and then served from.

set -o nounset
set -o errexit
set -o pipefail

WORK_DIR=$1

if [ -z "$WORK_DIR" ]; then     # Should never happen, but guard the rm below
    echo "You must provide a target directory"
    exit 1
fi

if [ ! -d "$WORK_DIR" ]; then
    echo "Making $WORK_DIR"
    mkdir $WORK_DIR
    git clone . $WORK_DIR
elif [ ! -d "$WORK_DIR/.git" ]; then
    echo "$WORK_DIR is not a git repository. It should be a clone of this repo"
    exit 1
else
    echo "$WORK_DIR already exists and is a repo"
fi

cd $WORK_DIR

git fetch origin

echo "Resetting HEAD to origin/master:" $(git rev-parse origin/master)
git reset --hard origin/master

echo "Building latest server"
dune build

# TODO: Convert into systemd unit and start/restart after build
dune exec src/rsspoetry.exe data/
