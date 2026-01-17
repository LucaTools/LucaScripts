#!/bin/bash

# Luca Installation Script
# This script downloads and installs the Luca executable and sets up shell hooks
# for directory-specific PATH management.

# =============================================================================
# CONFIGURATION VARIABLES
# =============================================================================

TOOL_NAME="Luca"
BIN_NAME="luca"
INSTALL_DIR="/usr/local/bin"
TOOL_FOLDER=".luca"
VERSION_FILE="${PWD}/.luca-version"
ORGANIZATION="LucaTools"
REPOSITORY_URL="https://github.com/LucaTools/Luca"
TOOL_DIR="$HOME/$TOOL_FOLDER"
SHELL_HOOK_SCRIPT_PATH="$TOOL_DIR/shell_hook.sh"
SHELL_HOOK_SCRIPT_URL="https://raw.githubusercontent.com/LucaTools/LucaScripts/HEAD/shell_hook.sh"

# =============================================================================
# TOOL VERSION DETECTION
# =============================================================================

# Check existence of version file
if [ ! -f "$VERSION_FILE" ]; then
    echo "Missing $VERSION_FILE. Fetching the latest version"
    # Fetch latest release version from GitHub API
    REQUIRED_EXECUTABLE_VERSION=$(curl -LSsf "https://api.github.com/repos/$ORGANIZATION/$TOOL_NAME/releases/latest" | grep '"tag_name":' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
    
    if [ -z "$REQUIRED_EXECUTABLE_VERSION" ]; then
        echo "ERROR: Could not fetch latest version from $REPOSITORY_URL"
        echo "Please check your internet connectivity."
        exit 1
    fi
    
    echo "Using latest version: $REQUIRED_EXECUTABLE_VERSION"
else
    echo "Using version from $VERSION_FILE"
    REQUIRED_EXECUTABLE_VERSION=$(cat "$VERSION_FILE")
fi

# Function to validate SemVer format
validate_semver() {
    local version="$1"
    
    if [ -z "$version" ]; then
        return 1
    fi
    
    # Basic SemVer validation: should match pattern like 1.2.3, 1.2.3-alpha, v1.2.3
    if ! echo "$version" | grep -qE '^v?[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?$'; then
        echo "ERROR: Invalid version format '$version'. Expected SemVer format (e.g., 1.2.3 or v1.2.3)"
        return 1
    fi
    return 0
}

if [ -n "$REQUIRED_EXECUTABLE_VERSION" ]; then
    if ! validate_semver "$REQUIRED_EXECUTABLE_VERSION"; then
        exit 1
    fi
fi

# Ensure we have a valid version to install
if [ -z "$REQUIRED_EXECUTABLE_VERSION" ]; then
    echo "ERROR: $TOOL_NAME version not found in $VERSION_FILE file nor a valid release exists at $REPOSITORY_URL"
    exit 1
fi

echo "Target version: $REQUIRED_EXECUTABLE_VERSION"

# =============================================================================
# OPERATING SYSTEM DETECTION
# =============================================================================

# Temporary filename for the downloaded zip (set based on OS detection)
TEMP_EXECUTABLE_ZIP_FILENAME=""

# Detect the operating system and set appropriate download filename
if [ "$(uname -s)" = "Darwin" ]; then
    OS="macos"
    TEMP_EXECUTABLE_ZIP_FILENAME="Luca-macOS.zip"
    echo "Detected macOS system"
elif [ -f "/etc/os-release" ]; then
    OS="linux"
    TEMP_EXECUTABLE_ZIP_FILENAME="Luca-Linux.zip"
    echo "Detected Linux system"
else
    OS="unknown"
    echo "ERROR: Unsupported operating system."
    echo "This script supports macOS and Linux only."
    exit 1
fi

# =============================================================================
# VERSION CHECK - SKIP IF ALREADY UP TO DATE
# =============================================================================

EXECUTABLE_FILE="$INSTALL_DIR/$BIN_NAME"

# Check if Luca is already installed and up-to-date
if [ -f "$EXECUTABLE_FILE" ]; then
    echo "Found existing $TOOL_NAME installation at $EXECUTABLE_FILE"
    
    # Get the currently installed version
    EXISTING_EXECUTABLE_VERSION=$($EXECUTABLE_FILE --version 2>/dev/null)
    
    # Compare versions to avoid unnecessary reinstallation
    if [ "$EXISTING_EXECUTABLE_VERSION" = "$REQUIRED_EXECUTABLE_VERSION" ]; then
        echo "✅ $TOOL_NAME version $REQUIRED_EXECUTABLE_VERSION is already up to date."
        SKIP_INSTALLATION=true
    else
        echo "Current version: $EXISTING_EXECUTABLE_VERSION"
        echo "Updating to version: $REQUIRED_EXECUTABLE_VERSION"
        SKIP_INSTALLATION=false
    fi
else
    echo "No existing installation found. Proceeding with fresh installation..."
    SKIP_INSTALLATION=false
fi

# =============================================================================
# DEPENDENCY CHECK AND INSTALLATION
# =============================================================================

# Ensure curl is available for downloading (Linux systems may not have it by default)
if [ "$OS" = "linux" ]; then
    if ! command -v curl >/dev/null 2>&1; then
        echo "Installing curl dependency..."
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update
            apt-get install -y curl
        elif command -v yum >/dev/null 2>&1; then
            yum install -y curl
        else
            echo "ERROR: Cannot install curl automatically. Please install curl manually and retry."
            exit 1
        fi
    else
        echo "✅ curl is already available"
    fi
fi

# Skip the download and installation if version is already current
if [ "$SKIP_INSTALLATION" = "true" ]; then
    echo "Skipping $TOOL_NAME download and installation..."
    exit 0
fi
    
# =============================================================================
# LUCA DOWNLOAD AND INSTALLATION
# =============================================================================

echo "📥 Downloading $TOOL_NAME ($REQUIRED_EXECUTABLE_VERSION)..."

# Download the appropriate version for the detected OS
# Use the updated URL pointing to the new S3 bucket
curl -LSsf --output "./$TEMP_EXECUTABLE_ZIP_FILENAME" \
    "$REPOSITORY_URL/releases/download/$REQUIRED_EXECUTABLE_VERSION/$TEMP_EXECUTABLE_ZIP_FILENAME"

DOWNLOAD_SUCCESS=$?
if [ $DOWNLOAD_SUCCESS -ne 0 ]; then
    echo "❌ ERROR: Could not download $TOOL_NAME ($REQUIRED_EXECUTABLE_VERSION)."
    echo "Please check your internet connection and verify the version exists."
    exit 1
fi

echo "✅ Download completed successfully"

# =============================================================================
# EXTRACTION AND INSTALLATION
# =============================================================================

echo "📦 Extracting $TEMP_EXECUTABLE_ZIP_FILENAME..."

# Extract the downloaded zip file quietly
if ! unzip -o -qq "./$TEMP_EXECUTABLE_ZIP_FILENAME" -d ./; then
    echo "❌ ERROR: Failed to extract $TEMP_EXECUTABLE_ZIP_FILENAME"
    rm -f "./$TEMP_EXECUTABLE_ZIP_FILENAME"
    exit 1
fi

echo "✅ Extraction completed"

# Clean up the downloaded zip file
rm "./$TEMP_EXECUTABLE_ZIP_FILENAME"
echo "🧹 Cleaned up temporary files"

# =============================================================================
# SYSTEM INSTALLATION WITH PRIVILEGE HANDLING
# =============================================================================

# Helper function to run commands with sudo only if needed
# This checks if the install directory is writable before using sudo
sudo_if_install_dir_not_writeable() {
    local command="$1"
    if [ -w "$INSTALL_DIR" ]; then
        # Directory is writable, run without sudo
        sh -c "$command"
    else
        # Directory requires elevated privileges
        echo "🔐 Administrator privileges required for installation to $INSTALL_DIR"
        sudo sh -c "$command"
    fi
}

# Create install directory if it doesn't exist
if [ ! -d "$INSTALL_DIR" ]; then
    echo "📁 Creating install directory: $INSTALL_DIR"
    sudo_if_install_dir_not_writeable "mkdir -p $INSTALL_DIR"
fi

# Move the executable to the install directory and make it executable
echo "🚀 Installing $TOOL_NAME to $INSTALL_DIR..."
sudo_if_install_dir_not_writeable "mv $TOOL_NAME $EXECUTABLE_FILE"
sudo_if_install_dir_not_writeable "chmod +x $EXECUTABLE_FILE"

echo "✅ $TOOL_NAME ($REQUIRED_EXECUTABLE_VERSION) successfully installed to $INSTALL_DIR"

# =============================================================================
# SHELL HOOK SETUP
# =============================================================================

echo "🔧 Setting up shell hook for directory-specific PATH management..."

# Create the tool directory
echo "📁 Creating tool directory: $TOOL_DIR"
mkdir -p "$TOOL_DIR"

# Download the shell hook script
echo "📥 Downloading shell hook script..."
curl -LSsf --output "$SHELL_HOOK_SCRIPT_PATH" "$SHELL_HOOK_SCRIPT_URL"

HOOK_DOWNLOAD_SUCCESS=$?
if [ $HOOK_DOWNLOAD_SUCCESS -ne 0 ]; then
    echo "❌ WARNING: Could not download shell hook script from $SHELL_HOOK_SCRIPT_URL"
    echo "You can manually download it later or the tool may still work without hooks"
    echo "Continuing with installation..."
else
    echo "✅ Shell hook script downloaded successfully to $SHELL_HOOK_SCRIPT_PATH"

    # Make the shell hook script executable
    chmod +x "$SHELL_HOOK_SCRIPT_PATH"
    
    # Source the shell_hook.sh script to install the shell hook into current shell
    echo "🔗 Installing shell hook into your shell configuration..."
    if [ -f "$SHELL_HOOK_SCRIPT_PATH" ]; then
        # shellcheck source=/dev/null
        . "$SHELL_HOOK_SCRIPT_PATH"
    fi
fi

# =============================================================================
# INSTALLATION COMPLETE
# =============================================================================

echo ""
echo "🎉 Luca installation completed successfully!"
echo ""
echo "📋 Installation Summary:"
echo "   • Executable: $EXECUTABLE_FILE"
echo "   • Version: $REQUIRED_EXECUTABLE_VERSION"
echo "   • Shell Hook: $SHELL_HOOK_SCRIPT_PATH"
echo ""
echo "💡 To start using Luca:"

# Detect the current shell and set the appropriate RC file
SHELL_PROFILE=""

case "$SHELL" in
*/bash)
    SHELL_PROFILE="$HOME/.bashrc"
    ;;
*/zsh)
    SHELL_PROFILE="$HOME/.zshrc"
    ;;
*)
    echo "WARNING: Unsupported shell: $SHELL"
    echo "Manual setup may be required. Supported shells: bash, zsh"
    exit 1
    ;;
esac

echo "   1. Restart your terminal or run: source $SHELL_PROFILE"
echo "   2. Run: $BIN_NAME --help"
echo ""