#!/bin/bash
#
# Makefile - makefile for gbdt
#
# Copyright (C) 2018  Christian Garbs <mitch@cgarbs.de>
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

BASH_SOURCES := gbdt test.sh

.PHONY: test

all: test

clean:
	rm -f *~

test: testsuite shellcheck

testsuite:
	./test.sh

shellcheck:
	@if shellcheck -V >/dev/null 2>&1; then \
		for FILE in $(BASH_SOURCES); do shellcheck "$$FILE" && echo "$$FILE no shellcheck warnings" || exit 1; done; \
	else \
		echo shellcheck binary is missing; \
	fi
