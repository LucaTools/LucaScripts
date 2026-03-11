#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load 'test_helper/common'

setup() {
    common_setup
}

# ---------------------------------------------------------------------------
# Executable removal
# ---------------------------------------------------------------------------

@test "executable: removes Luca binary when it exists" {
    # uninstall.sh uses TOOL_NAME=Luca (uppercase), so binary is $INSTALL_DIR/Luca
    touch "$TEST_INSTALL_DIR/Luca"

    run bash "$REPO_ROOT/uninstall.sh"

    assert_success
    assert [ ! -f "$TEST_INSTALL_DIR/Luca" ]
    assert_output --partial "executable has been removed"
}

@test "executable: graceful when binary does not exist" {
    run bash "$REPO_ROOT/uninstall.sh"

    assert_success
    assert_output --partial "executable not found"
}

# ---------------------------------------------------------------------------
# Shell hook removal (bash)
# ---------------------------------------------------------------------------

@test "bashrc: removes hook line and comment when present" {
    cp "$FIXTURE_DIR/bashrc_with_hook" "$TEST_HOME/.bashrc"

    run bash "$REPO_ROOT/uninstall.sh"

    assert_success
    assert_output --partial "Shell hook removed"
    run grep -c "shell_hook.sh" "$TEST_HOME/.bashrc"
    assert_output "0"
}

@test "bashrc: no-op when hook is not in .bashrc" {
    echo 'export FOO=bar' > "$TEST_HOME/.bashrc"

    run bash "$REPO_ROOT/uninstall.sh"

    assert_success
    assert_output --partial "No shell hook found"
}

@test "bashrc: no-op when .bashrc does not exist" {
    # .bashrc does not exist; TEST_HOME/.bashrc was not created

    run bash "$REPO_ROOT/uninstall.sh"

    assert_success
    assert_output --partial "Shell configuration file not found"
}

# ---------------------------------------------------------------------------
# Shell hook removal (zsh)
# ---------------------------------------------------------------------------

@test "zshrc: removes hook from .zshrc" {
    cp "$FIXTURE_DIR/bashrc_with_hook" "$TEST_HOME/.zshrc"
    export SHELL=/bin/zsh

    run env SHELL=/bin/zsh bash "$REPO_ROOT/uninstall.sh"

    assert_success
    assert_output --partial "Shell hook removed"
    run grep -c "shell_hook.sh" "$TEST_HOME/.zshrc"
    assert_output "0"
}

@test "unsupported shell: warns but exits 0" {
    run env SHELL=/bin/fish bash "$REPO_ROOT/uninstall.sh"

    assert_success
    assert_output --partial "Unsupported shell"
}

# ---------------------------------------------------------------------------
# Tool directory removal
# ---------------------------------------------------------------------------

@test "tool dir: removes ~/.luca directory entirely" {
    mkdir -p "$TEST_HOME/.luca/tools"
    touch "$TEST_HOME/.luca/some_config"

    run bash "$REPO_ROOT/uninstall.sh"

    assert_success
    assert [ ! -d "$TEST_HOME/.luca" ]
    assert_output --partial "Tool directory has been removed"
}

@test "tool dir: graceful when ~/.luca does not exist" {
    rm -rf "$TEST_HOME/.luca"

    run bash "$REPO_ROOT/uninstall.sh"

    assert_success
    assert_output --partial "Tool directory not found"
}
