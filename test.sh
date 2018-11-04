#!/bin/bash
#
# test.sh - integration tests for gbdt
#
# Copyright (C) 2016,2018  Christian Garbs <mitch@cgarbs.de>
# Licensed under GNU GPL v3 or later.
#
# This file is part of gbdt, see https://github.com/mmitch/gbdt
#
# gbdt is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# gbdt is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with gbdt.  If not, see <http://www.gnu.org/licenses/>.
#

set -e

DIR=$(mktemp -d --tmpdir gbdt-unittest-XXXXXXXX)

# setup colors
if tput sgr0 >/dev/null 2>&1; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    WHITE=$(tput setaf 7)
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
else
    RED=
    GREEN=
    YELLOW=
    WHITE=
    BOLD=
    RESET=
fi

status()
{
    echo "${BOLD}${YELLOW}>> ${*}${RESET}"
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

    if [ "$STATE" = OK ]; then
	printf "${BOLD}${GREEN}%s${WHITE} : %-7s %s${RESET}\n" 'OK' "[$ENV]" "$TEXT"
    else
	printf "${BOLD}${RED}%s${WHITE} : %-7s %s : ${RED}%s${RESET}\n" '!!' "[$ENV]" "$TEXT" "$STATE"
	error_out
    fi

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
    
    do_assertion "$ENV" "checking file content \`…${TESTFILE/$DIR}'" "$STATE"
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
sed "s,~/.gbdt,$CONFIG," < gbdt > "$GBDT"
chmod +x "$GBDT"

status 'initialize git'
REPO=$DIR/git-repo
mkdir "$REPO"
GIT="git -C $REPO"
$GIT init
REPOFILE=$REPO/file
echo 'initial' > "$REPOFILE"
$GIT add "$REPOFILE"
$GIT commit -m 'initial commit'

status 'create config'
PDIR=$DIR/prod
SDIR=$DIR/stage
(
    echo GIT_REPO="$REPO"
    echo PRODUCTION_DIR="$PDIR"
    echo STAGING_DIR="$SDIR"
) > "$CONFIG"

status 'TEST: no environment exists'
assert_nofile prod  "$PDIR"
assert_nofile stage "$SDIR"

status 'TEST: [prod] env init'
$GBDT prod init
assert_dir prod  "$PDIR"
assert_nofile stage "$SDIR"
assert_content prod  "$PDIR"/file 'initial'

status 'TEST: [stage] env init'
$GBDT stage init
assert_dir prod  "$PDIR"
assert_dir stage "$SDIR"
assert_content prod  "$PDIR"/file 'initial'
assert_content stage "$SDIR"/file 'initial'

status 'create two new commits with tags'
echo 'v1' > "$REPOFILE"
$GIT commit -m 'v1' "$REPOFILE"
$GIT tag 'v1'
echo 'v2' > "$REPOFILE"
$GIT commit -m 'v2' "$REPOFILE"
$GIT tag 'v2'

status 'TEST: tags'
TAGFILE=$DIR/tag.tmp
$GBDT tags | wc -l > "$TAGFILE"
assert_content tag_count "$TAGFILE" '2'
$GBDT tags | grep v1 > "$TAGFILE"
assert_content tag_v1 "$TAGFILE" 'v1'
$GBDT tags | grep v2 > "$TAGFILE"
assert_content tag_v2 "$TAGFILE" 'v2'

status 'TEST: [prod] roll forward to tag v2'
$GBDT prod deploy v2
assert_dir prod  "$PDIR"
assert_dir stage "$SDIR"
assert_content prod  "$PDIR"/file 'v2'
assert_content stage "$SDIR"/file 'initial'

status 'TEST: [stage] roll forward to tag v2'
$GBDT stage deploy v2
assert_dir prod  "$PDIR"
assert_dir stage "$SDIR"
assert_content prod  "$PDIR"/file 'v2'
assert_content stage "$SDIR"/file 'v2'

status 'TEST: [prod] combined status'
STATUSFILE=$DIR/status.tmp
$GBDT status | grep ^production: | sed 's/^.*branch/branch/' > "$STATUSFILE"
assert_content prod "$STATUSFILE" "branch \`master' at \`v2'"

status 'TEST: [stage] combined status'
$GBDT status | grep ^staging: | sed 's/^.*branch/branch/' > "$STATUSFILE"
assert_content prod "$STATUSFILE" "branch \`master' at \`v2'"

status 'TEST: [stage] roll backwards to tag v1'
$GBDT stage deploy v1
assert_dir prod  "$PDIR"
assert_dir stage "$SDIR"
assert_content prod  "$PDIR"/file 'v2'
assert_content stage "$SDIR"/file 'v1'

status 'TEST: [prod] roll backwards to tag v1'
$GBDT prod deploy v1
assert_dir prod  "$PDIR"
assert_dir stage "$SDIR"
assert_content prod  "$PDIR"/file 'v1'
assert_content stage "$SDIR"/file 'v1'

status 'TEST: [prod] status'
$GBDT status | grep ^production: | sed 's/^.*branch/branch/' > "$STATUSFILE"
assert_content prod "$STATUSFILE" "branch \`master' at \`v1'"

status 'TEST: [stage] status'
$GBDT status | grep ^staging: | sed 's/^.*branch/branch/' > "$STATUSFILE"
assert_content prod "$STATUSFILE" "branch \`master' at \`v1'"

status 'create new commit without tag'
echo 'v3' > "$REPOFILE"
$GIT commit -m 'v3' "$REPOFILE"

status 'TEST: [stage] roll forward to newest untagged commit (v3)'
$GBDT stage deploy
assert_dir prod  "$PDIR"
assert_dir stage "$SDIR"
assert_content prod  "$PDIR"/file 'v1'
assert_content stage "$SDIR"/file 'v3'

status 'TEST: [stage] stop'
$GBDT stage stop
assert_nofile stage "$SDIR"

#################################################################

status 'removing temporary directory'
rm -rf "$DIR"

status 'successful exit'
exit 0
