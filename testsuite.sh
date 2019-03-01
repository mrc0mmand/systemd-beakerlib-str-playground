#!/bin/bash

set -e

. "$(dirname "$0")/setup-env.sh"

ANSIBLE_ARGS=()
TEST_ARTIFACTS="${TEST_ARTIFACTS:-$PWD/artifacts-$(date --iso=minutes)}"

if [[ ! -z $1 ]]; then
    ANSIBLE_ARGS+=(--extra-vars="fmf_filter='$1'")
fi

# Cleanup artifact directories, so we get the most relevant test results
rm -fr /tmp/artifacts
if [[ -e $TEST_ARTIFACTS ]]; then
    rm -fr "$TEST_ARTIFACTS"
fi

export TEST_ARTIFACTS
ansible-playbook "${ANSIBLE_ARGS[@]}" systemd/tests.yml
