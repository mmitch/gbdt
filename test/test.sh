#!/bin/bash
set -e

DIR=`mktemp -d`

status()
{
    echo ">> $@"
}

error_out()
{
    status "test script was interrupted"
    status "temporary directory \`$DIR' was not cleaned"
    status "investigate and delete at your leisure"
    trap '' ERR
    exit 1
}

trap error_out ERR

#################################################################

# we don't have a -c parameter to set the config file yet,
# so make something up...
status "tempdir is \`$DIR'"
status 'setting up test'
CONFIG=$DIR/gbdtrc
GBDT=$DIR/gbdt
sed "s,~/.gbdt,$CONFIG," < ../gbdt > $GBDT
chmod +x $GBDT

status 'initialize git'
REPO=$DIR/git-repo
mkdir $REPO
GIT="git -C $REPO"
$GIT init
REPOFILE=$REPO/file
echo 'initial' > $REPOFILE
$GIT add $REPOFILE
$GIT commit -m 'initial commit'

status "create config"

#################################################################

status 'removing temporary directory'
rm -rf "$DIR"

status 'successful exit'
exit 0
