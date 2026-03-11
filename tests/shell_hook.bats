#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load 'test_helper/common'

setup() {
    common_setup
}

# ---------------------------------------------------------------------------
# update_path() — adding entries
# ---------------------------------------------------------------------------

@test "update_path: adds .luca/tools to PATH when directory exists" {
    local project="$BATS_TEST_TMPDIR/project"
    mkdir -p "$project/.luca/tools"

    run bash -c "
        export HOME='$TEST_HOME'
        export SHELL=/bin/bash
        cd '$project'
        source '$REPO_ROOT/shell_hook.sh'
        update_path
        echo \"\$PATH\"
    "

    assert_output --partial "$project/.luca/tools"
}

@test "update_path: idempotent — does not duplicate PATH entry" {
    local project="$BATS_TEST_TMPDIR/project"
    mkdir -p "$project/.luca/tools"

    run bash -c "
        export HOME='$TEST_HOME'
        export SHELL=/bin/bash
        cd '$project'
        source '$REPO_ROOT/shell_hook.sh' >/dev/null 2>&1
        update_path
        update_path
        # Count occurrences of the tools dir in PATH
        echo \"\$PATH\" | tr ':' '\n' | grep -c '\.luca/tools' || echo 0
    "

    assert_output "1"
}

@test "update_path: PATH unchanged when no .luca/tools in current dir" {
    local empty_dir="$BATS_TEST_TMPDIR/empty"
    mkdir -p "$empty_dir"

    run bash -c "
        export HOME='$TEST_HOME'
        export SHELL=/bin/bash
        cd '$empty_dir'
        source '$REPO_ROOT/shell_hook.sh'
        original_path=\$PATH
        update_path
        if [ \"\$PATH\" = \"\$original_path\" ]; then echo unchanged; else echo changed; fi
    "

    assert_output --partial "unchanged"
}

# ---------------------------------------------------------------------------
# update_path() — cleanup of stale entries
# ---------------------------------------------------------------------------

@test "update_path: removes stale .luca/tools entry when navigating away" {
    local project_a="$BATS_TEST_TMPDIR/project_a"
    local empty_dir="$BATS_TEST_TMPDIR/other"
    mkdir -p "$project_a/.luca/tools" "$empty_dir"

    run bash -c "
        export HOME='$TEST_HOME'
        export SHELL=/bin/bash
        cd '$project_a'
        source '$REPO_ROOT/shell_hook.sh'
        update_path
        cd '$empty_dir'
        update_path
        echo \"\$PATH\"
    "

    refute_output --partial "$project_a/.luca/tools"
}

@test "update_path: keeps .luca/tools entry when in subdirectory of project" {
    local project="$BATS_TEST_TMPDIR/myproject"
    local subdir="$project/src/lib"
    mkdir -p "$project/.luca/tools" "$subdir"

    run bash -c "
        export HOME='$TEST_HOME'
        export SHELL=/bin/bash
        cd '$project'
        source '$REPO_ROOT/shell_hook.sh'
        update_path
        cd '$subdir'
        update_path
        echo \"\$PATH\"
    "

    assert_output --partial "$project/.luca/tools"
}

@test "update_path: non-luca PATH entries are never removed" {
    local empty_dir="$BATS_TEST_TMPDIR/empty"
    mkdir -p "$empty_dir"

    run bash -c "
        export HOME='$TEST_HOME'
        export SHELL=/bin/bash
        export PATH=\"/usr/local/bin:/usr/bin:\$PATH\"
        cd '$empty_dir'
        source '$REPO_ROOT/shell_hook.sh'
        update_path
        echo \"\$PATH\"
    "

    assert_output --partial "/usr/local/bin"
    assert_output --partial "/usr/bin"
}

# ---------------------------------------------------------------------------
# install_shell_hook() — bash
# ---------------------------------------------------------------------------

@test "install_shell_hook: appends hook line to .bashrc" {
    run bash -c "
        export HOME='$TEST_HOME'
        export SHELL=/bin/bash
        source '$REPO_ROOT/shell_hook.sh'
    "

    assert [ -f "$TEST_HOME/.bashrc" ]
    run grep -c "shell_hook.sh" "$TEST_HOME/.bashrc"
    assert_output "1"
}

@test "install_shell_hook: creates .bashrc if it does not exist" {
    # .bashrc does not exist in TEST_HOME
    assert [ ! -f "$TEST_HOME/.bashrc" ]

    run bash -c "
        export HOME='$TEST_HOME'
        export SHELL=/bin/bash
        source '$REPO_ROOT/shell_hook.sh'
    "

    assert [ -f "$TEST_HOME/.bashrc" ]
}

@test "install_shell_hook: idempotent — hook line appears exactly once after two sources" {
    bash -c "
        export HOME='$TEST_HOME'
        export SHELL=/bin/bash
        source '$REPO_ROOT/shell_hook.sh'
    "
    bash -c "
        export HOME='$TEST_HOME'
        export SHELL=/bin/bash
        source '$REPO_ROOT/shell_hook.sh'
    "

    run grep -c "shell_hook.sh" "$TEST_HOME/.bashrc"
    assert_output "1"
}

# ---------------------------------------------------------------------------
# install_shell_hook() — zsh
# ---------------------------------------------------------------------------

@test "install_shell_hook: appends hook line to .zshrc for zsh" {
    run bash -c "
        export HOME='$TEST_HOME'
        export SHELL=/bin/zsh
        source '$REPO_ROOT/shell_hook.sh'
    "

    assert [ -f "$TEST_HOME/.zshrc" ]
    run grep -c "shell_hook.sh" "$TEST_HOME/.zshrc"
    assert_output "1"
}

@test "install_shell_hook: returns 1 for unsupported shell" {
    run bash -c "
        export HOME='$TEST_HOME'
        export SHELL=/bin/fish
        source '$REPO_ROOT/shell_hook.sh'
        install_shell_hook
        echo exit:\$?
    "

    assert_output --partial "exit:1"
}

# ---------------------------------------------------------------------------
# Shell hook registration
# ---------------------------------------------------------------------------

@test "bash registration: update_path added to PROMPT_COMMAND on source" {
    run bash -c "
        export HOME='$TEST_HOME'
        export SHELL=/bin/bash
        source '$REPO_ROOT/shell_hook.sh'
        echo \"\$PROMPT_COMMAND\"
    "

    assert_output --partial "update_path"
}

@test "bash registration: update_path not added twice on double source" {
    run bash -c "
        export HOME='$TEST_HOME'
        export SHELL=/bin/bash
        source '$REPO_ROOT/shell_hook.sh' >/dev/null 2>&1
        source '$REPO_ROOT/shell_hook.sh' >/dev/null 2>&1
        echo \"\$PROMPT_COMMAND\" | tr ';' '\n' | grep -c 'update_path'
    "

    assert_output "1"
}
