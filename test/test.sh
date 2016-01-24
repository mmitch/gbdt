#!/bin/bash
set -e

DIR=`mktemp -d`

# setup colors
if tput sgr0 >/dev/null 2>&1; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
else
    RED=
    GREEN=
    YELLOW=
    BOLD=
    RESET=
fi

status()
{
    echo "${BOLD}${YELLOW}>> ${@}${RESET}"
}

error_out()
{
    status "${RED}test script was interrupted"
    status "${RED}temporary directory \`$DIR' was not cleaned"
    status "${RED}investigate and delete at your leisure"
    trap '' ERR
    exit 1
}

trap error_out ERR

do_assertion()
{
    local ENV="$1" TEXT="$2" STATE="$3"

    local COLORSTATE
    if [ "$STATE" = OK ]; then
	COLORSTATE="${GREEN}${STATE}${RESET}"
    else
	COLORSTATE="${RED}${STATE}${RESET}"
    fi

    printf "${BOLD}%-7s %s : %s\n" "[$ENV]" "$TEXT" "$COLORSTATE"
    [ "$STATE" = OK ] || error_out
}

assert_dir()
{
    local ENV="$1"
    shift

    local TESTDIR STATE
    for TESTDIR in "$@"; do
	if [ -d "$TESTDIR" ]; then
	    STATE="OK"
	else
	    if [ -e "$TESTDIR" ]; then
		STATE="file exists, but is no directory"
	    else
		STATE="missing directory"
	    fi
	fi
	do_assertion "$ENV" "checking directory \`…${TESTDIR/$DIR}'" "$STATE"
    done
}

assert_nofile()
{
    local ENV="$1"
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
	do_assertion "$ENV" "checking missing file \`…${TESTFILE/$DIR}'" "$STATE"
    done
}

assert_content()
{
    local ENV="$1" TESTFILE="$2" EXPECTED="$3"

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
    
    do_assertion "$ENV" "checking fole content \`…${TESTFILE/$DIR}'" "$STATE"
}

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
assert_dir prod  $PDIR
assert_dir stage $SDIR
PFILE=$PDIR/file
SFILE=$SDIR/file
assert_content prod  $PDIR/file 'initial'
assert_content stage $SDIR/file 'initial'

status 'create two new versions with tags'
echo 'v1' > $REPOFILE
$GIT commit -m 'v1' $REPOFILE
$GIT tag 'v1'
echo 'v2' > $REPOFILE
$GIT commit -m 'v2' $REPOFILE
$GIT tag 'v2'

status 'TEST: roll forward to tag'
$GBDT prod deploy v2
$GBDT stage deploy v2
assert_dir prod  $PDIR
assert_dir stage $SDIR
assert_content prod  $PDIR/file 'v2'
assert_content stage $SDIR/file 'v2'

status 'TEST: combined status'
$GBDT status | grep ^production: | grep "branch \`master' at \`v2'"
$GBDT status | grep ^staging: | grep "branch \`master' at \`v2'"

status 'TEST: roll backwards to tag'
$GBDT prod deploy v1
$GBDT stage deploy v1
assert_dir prod  $PDIR
assert_dir stage $SDIR
assert_content prod  $PDIR/file 'v1'
assert_content stage $SDIR/file 'v1'

status 'TEST: production status'
$GBDT prod status | grep ^production: | grep "branch \`master' at \`v1'"

status 'TEST: stage status'
$GBDT stage status | grep ^staging: | grep "branch \`master' at \`v1'"

status 'TEST: tags'
TAGFILE=$DIR/tag.tmp
$GBDT tags | wc -l > $TAGFILE
assert_content tag_count $TAGFILE '2'
$GBDT tags | grep v1 > $TAGFILE
assert_content tag_v1 $TAGFILE 'v1'
$GBDT tags | grep v2 > $TAGFILE
assert_content tag_v2 $TAGFILE 'v2'

status 'TEST: stage stop'
$GBDT stage stop
assert_nofile stage $SDIR

#################################################################

status 'removing temporary directory'
rm -rf "$DIR"

status 'successful exit'
exit 0
