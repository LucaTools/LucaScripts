#!/usr/bin/env bash

# Resolve paths relative to this file
_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$_COMMON_DIR/.." && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
FIXTURE_DIR="$TESTS_DIR/fixtures"

common_setup() {
    export TESTS_DIR REPO_ROOT FIXTURE_DIR

    export TEST_HOME="$BATS_TEST_TMPDIR/home"
    export TEST_INSTALL_DIR="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$TEST_HOME/.luca" "$TEST_INSTALL_DIR"

    # Override HOME so scripts write to temp dir instead of real home
    export HOME="$TEST_HOME"

    # Override INSTALL_DIR so scripts install to temp dir (requires `:- default` patch)
    export INSTALL_DIR="$TEST_INSTALL_DIR"

    # Override SHELL so scripts don't exit 1 on unsupported shell detection
    export SHELL=/bin/bash

    # Prepend mocks to PATH so they shadow real commands
    export PATH="$TESTS_DIR/test_helper/mocks:$TEST_INSTALL_DIR:$PATH"

    # Log file for mock invocations
    export MOCK_CALL_LOG="$BATS_TEST_TMPDIR/mock_calls.log"
    touch "$MOCK_CALL_LOG"

    # Sentinel file for sudo mock
    export MOCK_SUDO_SENTINEL="$BATS_TEST_TMPDIR/sudo_calls.log"

    # Clear all mock control variables
    unset GITHUB_TOKEN
    unset MOCK_CURL_BEHAVIOR
    unset MOCK_GIT_REPO_ROOT
    unset MOCK_LUCA_VERSION
    unset MOCK_LUCA_INSTALL_EXIT_CODE
    unset MOCK_UNAME_OUTPUT
    unset MOCK_UNZIP_BEHAVIOR

    # Run scripts from temp dir so VERSION_FILE (${PWD}/.luca-version) resolves here
    cd "$BATS_TEST_TMPDIR"
}
