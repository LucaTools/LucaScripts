#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load 'test_helper/common'

setup() {
    common_setup
}

# ---------------------------------------------------------------------------
# Version detection
# ---------------------------------------------------------------------------

@test "version: reads from .luca-version file" {
    echo "v1.2.3" > "$BATS_TEST_TMPDIR/.luca-version"

    run bash "$REPO_ROOT/install.sh"

    assert_output --partial "Using version from"
    assert_output --partial "Target version: v1.2.3"
}

@test "version: fetches latest from GitHub API when no version file" {
    run bash "$REPO_ROOT/install.sh"

    assert_output --partial "Missing"
    assert_output --partial "Fetching the latest version"
    assert_output --partial "v2.0.0"
}

@test "version: API returns empty object exits with error" {
    export MOCK_CURL_BEHAVIOR=api_empty

    run bash "$REPO_ROOT/install.sh"

    assert_failure
    assert_output --partial "ERROR: Could not fetch latest version"
}

@test "version: invalid semver in version file exits with error" {
    echo "not-a-version" > "$BATS_TEST_TMPDIR/.luca-version"

    run bash "$REPO_ROOT/install.sh"

    assert_failure
    assert_output --partial "Invalid version format"
}

@test "version: valid semver without v prefix is accepted" {
    echo "1.2.3" > "$BATS_TEST_TMPDIR/.luca-version"

    run bash "$REPO_ROOT/install.sh"

    assert_output --partial "Target version: 1.2.3"
}

@test "version: valid semver with prerelease tag is accepted" {
    echo "v1.2.3-beta.1" > "$BATS_TEST_TMPDIR/.luca-version"

    run bash "$REPO_ROOT/install.sh"

    assert_output --partial "Target version: v1.2.3-beta.1"
}

@test "version: GITHUB_TOKEN set prints authenticated request message" {
    echo "v2.0.0" > "$BATS_TEST_TMPDIR/.luca-version"

    run env GITHUB_TOKEN=mytoken bash "$REPO_ROOT/install.sh"

    assert_output --partial "Using GITHUB_TOKEN for authenticated GitHub API requests"
}

# ---------------------------------------------------------------------------
# OS detection
# ---------------------------------------------------------------------------

@test "os: Darwin detected as macOS" {
    echo "v2.0.0" > "$BATS_TEST_TMPDIR/.luca-version"
    # MOCK_UNAME_OUTPUT defaults to Darwin

    run bash "$REPO_ROOT/install.sh"

    assert_output --partial "Detected macOS"
}

@test "os: Linux detected via /etc/os-release" {
    if [ ! -f /etc/os-release ]; then
        skip "Requires /etc/os-release (Linux only)"
    fi
    echo "v2.0.0" > "$BATS_TEST_TMPDIR/.luca-version"
    export MOCK_UNAME_OUTPUT="Linux"

    run bash "$REPO_ROOT/install.sh"

    assert_output --partial "Detected Linux"
}

# ---------------------------------------------------------------------------
# Already up to date
# ---------------------------------------------------------------------------

@test "skip: already up-to-date version exits 0 without downloading" {
    echo "v2.0.0" > "$BATS_TEST_TMPDIR/.luca-version"
    export MOCK_LUCA_VERSION="v2.0.0"
    # Place a fake luca binary that returns v2.0.0
    cp "$TESTS_DIR/test_helper/mocks/luca" "$TEST_INSTALL_DIR/luca"

    run bash "$REPO_ROOT/install.sh"

    assert_success
    assert_output --partial "already up to date"
    # Verify curl was NOT called for a download
    refute_output --partial "Downloading"
}

@test "skip: different installed version proceeds with update" {
    echo "v2.0.0" > "$BATS_TEST_TMPDIR/.luca-version"
    export MOCK_LUCA_VERSION="v1.0.0"
    cp "$TESTS_DIR/test_helper/mocks/luca" "$TEST_INSTALL_DIR/luca"

    run bash "$REPO_ROOT/install.sh"

    assert_output --partial "Updating to version"
}

# ---------------------------------------------------------------------------
# Download and install
# ---------------------------------------------------------------------------

@test "install: happy path installs binary to INSTALL_DIR" {
    echo "v2.0.0" > "$BATS_TEST_TMPDIR/.luca-version"

    run bash "$REPO_ROOT/install.sh"

    assert_success
    assert_output --partial "successfully installed"
    assert [ -f "$TEST_INSTALL_DIR/luca" ]
}

@test "install: curl download failure exits with error" {
    echo "v2.0.0" > "$BATS_TEST_TMPDIR/.luca-version"
    export MOCK_CURL_BEHAVIOR=download_fail

    run bash "$REPO_ROOT/install.sh"

    assert_failure
    assert_output --partial "ERROR: Could not download"
}

@test "install: unzip failure exits with error and cleans up zip" {
    echo "v2.0.0" > "$BATS_TEST_TMPDIR/.luca-version"
    export MOCK_UNZIP_BEHAVIOR=fail

    run bash "$REPO_ROOT/install.sh"

    assert_failure
    assert_output --partial "ERROR: Failed to extract"
    # Zip file should have been cleaned up
    assert [ ! -f "$BATS_TEST_TMPDIR/Luca-macOS.zip" ]
}

# ---------------------------------------------------------------------------
# Shell hook setup
# ---------------------------------------------------------------------------

@test "shell_hook: download failure is non-fatal (exits 0)" {
    echo "v2.0.0" > "$BATS_TEST_TMPDIR/.luca-version"
    export MOCK_CURL_BEHAVIOR=shell_hook_fail

    run bash "$REPO_ROOT/install.sh"

    assert_success
    assert_output --partial "WARNING: Could not download shell hook"
}

# ---------------------------------------------------------------------------
# Git hook setup
# ---------------------------------------------------------------------------

@test "git: not in a git repo skips hook installation silently" {
    echo "v2.0.0" > "$BATS_TEST_TMPDIR/.luca-version"
    # MOCK_GIT_REPO_ROOT unset → mock git returns exit 128 (not a repo)

    run bash "$REPO_ROOT/install.sh"

    assert_success
    refute_output --partial "Git post-checkout hook installed"
}

@test "git: in a git repo installs post-checkout hook" {
    echo "v2.0.0" > "$BATS_TEST_TMPDIR/.luca-version"
    local git_root="$BATS_TEST_TMPDIR/fake_repo"
    mkdir -p "$git_root/.git/hooks"
    export MOCK_GIT_REPO_ROOT="$git_root"

    run bash "$REPO_ROOT/install.sh"

    assert_success
    assert_output --partial "Git post-checkout hook installed"
    assert [ -f "$git_root/.git/hooks/post-checkout" ]
}

@test "git: hook with Luca identifier already exists is skipped" {
    echo "v2.0.0" > "$BATS_TEST_TMPDIR/.luca-version"
    local git_root="$BATS_TEST_TMPDIR/fake_repo"
    mkdir -p "$git_root/.git/hooks"
    echo "# LUCA POST-CHECKOUT GIT HOOK" > "$git_root/.git/hooks/post-checkout"
    export MOCK_GIT_REPO_ROOT="$git_root"

    run bash "$REPO_ROOT/install.sh"

    assert_success
    assert_output --partial "Luca post-checkout hook already installed"
}

@test "git: foreign hook without Luca identifier warns and does not overwrite" {
    echo "v2.0.0" > "$BATS_TEST_TMPDIR/.luca-version"
    local git_root="$BATS_TEST_TMPDIR/fake_repo"
    mkdir -p "$git_root/.git/hooks"
    echo "#!/bin/sh\n# some other tool" > "$git_root/.git/hooks/post-checkout"
    export MOCK_GIT_REPO_ROOT="$git_root"

    run bash "$REPO_ROOT/install.sh"

    assert_success
    assert_output --partial "A post-checkout hook already exists"
    # Original hook content should be unchanged
    assert [ -f "$git_root/.git/hooks/post-checkout" ]
}
