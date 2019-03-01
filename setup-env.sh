#!/bin/bash

set -e

# STR copies tests over to /var/str which breaks the internal Beakerlib library
# lookup. Let's workaround it.
BEAKERLIB_LIB_BASE="/usr/share/beakerlib-libraries"
[ ! -d "$BEAKERLIB_LIB_BASE" ] && mkdir -p "$BEAKERLIB_LIB_BASE"
mkdir "$BEAKERLIB_LIB_BASE/systemd"

TEST_REPO_ROOT="$(dirname "$0")"
ln -s "$TEST_REPO_ROOT/systemd/Library" "$BEAKERLIB_LIB_BASE/Library"
