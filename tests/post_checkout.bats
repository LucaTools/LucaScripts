#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load 'test_helper/common'

setup() {
    common_setup
    # Create a fake git repo root used by most tests
    export FAKE_REPO="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$FAKE_REPO/.git/hooks"
    export MOCK_GIT_REPO_ROOT="$FAKE_REPO"
    # Set up the luca call log
    export MOCK_LUCA_CALL_LOG="$BATS_TEST_TMPDIR/luca_calls.log"
    touch "$MOCK_LUCA_CALL_LOG"
}

# ---------------------------------------------------------------------------
# Checkout type guard
# ---------------------------------------------------------------------------

@test "type guard: file checkout (type=0) exits 0 immediately" {
    run "$REPO_ROOT/post-checkout" prev_ref new_ref 0

    assert_success
    assert_output ""
}

@test "type guard: missing third argument defaults to 0 and exits 0" {
    run "$REPO_ROOT/post-checkout" prev_ref new_ref

    assert_success
    assert_output ""
}

@test "type guard: branch checkout (type=1) proceeds" {
    # With no Lucafile, script exits 0 silently after proceeding past the guard
    run "$REPO_ROOT/post-checkout" prev_ref new_ref 1

    assert_success
}

# ---------------------------------------------------------------------------
# Lucafile detection
# ---------------------------------------------------------------------------

@test "lucafile: no Lucafile in repo root exits 0 silently" {
    run "$REPO_ROOT/post-checkout" prev_ref new_ref 1

    assert_success
    refute_output --partial "synchronizing"
}

@test "lucafile: Lucafile exists triggers synchronization message" {
    cp "$FIXTURE_DIR/Lucafile" "$FAKE_REPO/Lucafile"

    run "$REPO_ROOT/post-checkout" prev_ref new_ref 1

    assert_success
    assert_output --partial "Found Lucafile, synchronizing"
}

@test "lucafile: git root undetermined exits 0 with warning" {
    unset MOCK_GIT_REPO_ROOT

    run "$REPO_ROOT/post-checkout" prev_ref new_ref 1

    assert_success
    assert_output --partial "Could not determine repository root"
}

# ---------------------------------------------------------------------------
# Luca installation check
# ---------------------------------------------------------------------------

@test "luca present: curl NOT called to install when luca already in PATH" {
    cp "$FIXTURE_DIR/Lucafile" "$FAKE_REPO/Lucafile"
    # luca mock is already in PATH via common_setup

    run "$REPO_ROOT/post-checkout" prev_ref new_ref 1

    assert_success
    # curl should not have been invoked for install.sh
    if [ -f "$MOCK_CALL_LOG" ]; then
        refute grep -q "install.sh" "$MOCK_CALL_LOG" 2>/dev/null || true
    fi
}

@test "luca absent: curl called to install when luca not in PATH" {
    cp "$FIXTURE_DIR/Lucafile" "$FAKE_REPO/Lucafile"
    # Build a PATH that has git/curl mocks but NOT luca
    local no_luca_bin="$BATS_TEST_TMPDIR/no_luca_bin"
    mkdir -p "$no_luca_bin"
    for mock in curl git sudo uname unzip; do
        ln -sf "$TESTS_DIR/test_helper/mocks/$mock" "$no_luca_bin/$mock"
    done

    # Intentionally omit /usr/local/bin to ensure real luca is not found
    run env PATH="$no_luca_bin:/usr/bin:/bin" \
        "$REPO_ROOT/post-checkout" prev_ref new_ref 1

    assert_output --partial "installing"
}

# ---------------------------------------------------------------------------
# luca install invocation
# ---------------------------------------------------------------------------

@test "luca install: called with correct args on happy path" {
    cp "$FIXTURE_DIR/Lucafile" "$FAKE_REPO/Lucafile"

    run "$REPO_ROOT/post-checkout" prev_ref new_ref 1

    assert_success
    assert_output --partial "Tools synchronized successfully"
    run grep "luca install --quiet --no-install-post-checkout-git-hook" "$MOCK_LUCA_CALL_LOG"
    assert_success
}

@test "luca install: non-zero exit warns but post-checkout exits 0" {
    cp "$FIXTURE_DIR/Lucafile" "$FAKE_REPO/Lucafile"
    export MOCK_LUCA_INSTALL_EXIT_CODE=1

    run "$REPO_ROOT/post-checkout" prev_ref new_ref 1

    assert_success
    assert_output --partial "Some tools may have failed"
}

# ---------------------------------------------------------------------------
# Luca version check
# ---------------------------------------------------------------------------

@test "version check: luca version matches .luca-version, curl NOT called to reinstall" {
    cp "$FIXTURE_DIR/Lucafile" "$FAKE_REPO/Lucafile"
    echo "v1.0.0" > "$FAKE_REPO/.luca-version"  # matches MOCK_LUCA_VERSION default

    run "$REPO_ROOT/post-checkout" prev_ref new_ref 1

    assert_success
    refute_output --partial "mismatch"
    refute_output --partial "installing"
}

@test "version check: luca version mismatch triggers reinstall with mismatch message" {
    cp "$FIXTURE_DIR/Lucafile" "$FAKE_REPO/Lucafile"
    echo "v2.0.0" > "$FAKE_REPO/.luca-version"  # differs from MOCK_LUCA_VERSION (v1.0.0)

    run "$REPO_ROOT/post-checkout" prev_ref new_ref 1

    assert_output --partial "version mismatch"
    assert_output --partial "v1.0.0"
    assert_output --partial "v2.0.0"
}

@test "version check: no .luca-version file skips version check" {
    cp "$FIXTURE_DIR/Lucafile" "$FAKE_REPO/Lucafile"
    # No .luca-version file created

    run "$REPO_ROOT/post-checkout" prev_ref new_ref 1

    assert_success
    refute_output --partial "mismatch"
}
