#!/bin/bash

set -e

. "$(dirname "$0")/setup-env.sh"

ANSIBLE_ARGS="${ANSIBLE_ARGS:-}"
TEST_ARTIFACTS="${TEST_ARTIFACTS:-$PWD/artifacts}"

if [[ ! -z $1 ]]; then
    ANSIBLE_ARGS+="-e \"fmf_filter='$1'\""
fi

export TEST_ARTIFACTS
ansible-playbook $ANSIBLE_ARGS systemd/tests.yml
