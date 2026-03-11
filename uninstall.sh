#!/bin/bash

# Luca Uninstallation Script
# This script removes the Luca executable and its associated shell hooks

# =============================================================================
# CONFIGURATION VARIABLES
# =============================================================================

TOOL_NAME="Luca"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
TOOL_FOLDER=".luca"
TOOL_DIR="$HOME/$TOOL_FOLDER"
SHELL_HOOK_SCRIPT_PATH="$TOOL_DIR/shell_hook.sh"
EXECUTABLE_FILE="$INSTALL_DIR/$TOOL_NAME"

# =============================================================================
# TERMINAL COLORS
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

print_header() {
    echo -e "\n${BLUE}==============================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}==============================================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️ $1${NC}"
}

# Helper function to run commands with sudo only if needed
sudo_if_install_dir_not_writeable() {
    local command="$1"
    if [ -w "$INSTALL_DIR" ]; then
        # Directory is writable, run without sudo
        sh -c "$command"
    else
        # Directory requires elevated privileges
        print_info "Administrator privileges required to remove files from $INSTALL_DIR"
        sudo sh -c "$command"
    fi
}

# =============================================================================
# CHECK FOR EXISTING INSTALLATION
# =============================================================================

print_header "CHECKING FOR EXISTING INSTALLATION"

if [ -f "$EXECUTABLE_FILE" ]; then
    print_info "Found $TOOL_NAME installation at $EXECUTABLE_FILE"
    
    # Get the currently installed version
    EXISTING_EXECUTABLE_VERSION=$($EXECUTABLE_FILE --version 2>/dev/null)
    
    if [ -n "$EXISTING_EXECUTABLE_VERSION" ]; then
        print_info "Current version: $EXISTING_EXECUTABLE_VERSION"
    fi
else
    print_warning "No $TOOL_NAME installation found at $EXECUTABLE_FILE"
fi

if [ -d "$TOOL_DIR" ]; then
    print_info "Found tool directory at $TOOL_DIR"
else
    print_warning "No tool directory found at $TOOL_DIR"
fi

# =============================================================================
# REMOVE EXECUTABLE
# =============================================================================

print_header "REMOVING $TOOL_NAME EXECUTABLE"

if [ -f "$EXECUTABLE_FILE" ]; then
    print_info "Removing $EXECUTABLE_FILE..."
    sudo_if_install_dir_not_writeable "rm -f $EXECUTABLE_FILE"
    
    if [ ! -f "$EXECUTABLE_FILE" ]; then
        print_success "$TOOL_NAME executable has been removed"
    else
        print_error "Failed to remove $TOOL_NAME executable"
    fi
else
    print_warning "$TOOL_NAME executable not found at $EXECUTABLE_FILE"
fi

# =============================================================================
# REMOVE SHELL HOOK
# =============================================================================

print_header "REMOVING SHELL HOOKS"

# Detect the current shell and set the appropriate RC file
SHELL_RC_FILE=""
HOOK_LINE="[[ -s \"\$HOME/$TOOL_FOLDER/shell_hook.sh\" ]] && source \"\$HOME/$TOOL_FOLDER/shell_hook.sh\""

case "$SHELL" in
    */bash)
        SHELL_RC_FILE="$HOME/.bashrc"
        print_info "Detected Bash shell, checking $SHELL_RC_FILE"
        ;;
    */zsh)
        SHELL_RC_FILE="$HOME/.zshrc"
        print_info "Detected Zsh shell, checking $SHELL_RC_FILE"
        ;;
    *)
        print_warning "Unsupported shell: $SHELL"
        print_warning "Manual cleanup may be required. Supported shells: bash, zsh"
        ;;
esac

# Remove shell hook reference from RC file if it exists
if [ -n "$SHELL_RC_FILE" ] && [ -f "$SHELL_RC_FILE" ]; then
    if grep -Fq "$HOOK_LINE" "$SHELL_RC_FILE"; then
        print_info "Found hook in $SHELL_RC_FILE, removing..."
        
        # Create a temporary file
        temp_file=$(mktemp)
        
        # Remove the hook line and its comment
        grep -v -F "# Initialize $TOOL_NAME shell hook" "$SHELL_RC_FILE" | grep -v -F "$HOOK_LINE" > "$temp_file"
        
        # Replace the original file with our modified version
        mv "$temp_file" "$SHELL_RC_FILE"
        
        print_success "Shell hook removed from $SHELL_RC_FILE"
    else
        print_info "No shell hook found in $SHELL_RC_FILE"
    fi
else
    print_warning "Shell configuration file not found: $SHELL_RC_FILE"
fi

# =============================================================================
# REMOVE TOOL DIRECTORY
# =============================================================================

print_header "REMOVING TOOL DIRECTORY"

if [ -d "$TOOL_DIR" ]; then
    print_info "Removing tool directory at $TOOL_DIR..."
    rm -rf "$TOOL_DIR"
    
    if [ ! -d "$TOOL_DIR" ]; then
        print_success "Tool directory has been removed"
    else
        print_error "Failed to remove tool directory at $TOOL_DIR"
        print_info "You may need to manually remove it with: rm -rf $TOOL_DIR"
    fi
else
    print_info "Tool directory not found at $TOOL_DIR"
fi

# =============================================================================
# UNINSTALLATION COMPLETE
# =============================================================================

print_header "UNINSTALLATION COMPLETE"

echo ""
print_success "$TOOL_NAME has been uninstalled from your system"
echo ""
print_info "To complete the uninstallation, please restart your terminal or run:"
echo "source $SHELL_RC_FILE"
echo ""
