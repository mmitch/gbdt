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

assert_dir()
{
    local ENV="[$1]"
    shift

    local TESTDIR STATE
    for TESTDIR in "$@"; do
	if [ -d "$TESTDIR" ]; then
	    STATE='OK'
	else
	    if [ -e "$TESTDIR" ]; then
		STATE='file exists, but is no directory'
	    else
		STATE='missing directory'
	    fi
	fi
	printf "%-7s checking directory \`…%s' : %s\n" $ENV ${TESTDIR/$DIR} $STATE
	[ $STATE = OK ]
    done
}

assert_nofile()
{
    local ENV="[$1]"
    shift

    local TESTFILE STATE
    for TESTFILE in "$@"; do
	if [ ! -e "$TESTFILE" ]; then
	    STATE='OK'
	else
	    if [ -d "$TESTDIR" ]; then
		STATE='unwanted file exists (directory)'
	    else
		STATE='unwanted file exists'
	    fi
	fi
	printf "%-7s checking missing file \`…%s' : %s\n" $ENV ${TESTFILE/$DIR} $STATE
	[ $STATE = OK ]
    done
}

assert_content()
{
    local ENV="[$1]" TESTFILE="$2" EXPECTED="$3"

    local STATE
    if [ -e "$TESTFILE" ]; then
	ACTUAL="$(cat "$TESTFILE")"
	if [ "$ACTUAL" = "$EXPECTED" ]; then
	    STATE='OK'
	else
	    printf -v STATE "expected content = \`%s', actual content = \`%s'" "$EXPECTED" "$ACTUAL"
	fi
    else
	STATE='missing file'
    fi
    
    printf "%-7s checking file content \`…%s' : %s\n" $ENV ${TESTFILE/$DIR} $STATE
    [ $STATE = OK ]
}

trap error_out ERR

#
# missing tests:
# - config:
#   - GIT_BRANCH
#   - TAG_REGEXP
#   - post_deploy()

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

status 'create config'
PDIR=$DIR/prod
SDIR=$DIR/stage
(
    echo GIT_REPO=$REPO
    echo PRODUCTION_DIR=$PDIR
    echo STAGING_DIR=$SDIR
) > $CONFIG

status 'TEST: env init'
$GBDT prod init
$GBDT stage init
PFILE=$PDIR/file
SFILE=$SDIR/file
assert_dir prod  $PDIR
assert_content prod  $PDIR/file 'initial'
assert_dir stage $SDIR
assert_content stage $SDIR/file 'initial'

status 'TEST: stage stop'
$GBDT stage stop
assert_nofile stage $SDIR


#################################################################

status 'removing temporary directory'
rm -rf "$DIR"

status 'successful exit'
exit 0
