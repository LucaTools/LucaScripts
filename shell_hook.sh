#!/bin/bash

# =============================================================================
# CONFIGURATION VARIABLES
# =============================================================================

TOOL_NAME="Luca"
TOOL_FOLDER=".luca"

# =============================================================================
# LUCA SHELL HOOK
# =============================================================================
# 
# This script provides directory-specific PATH management for $TOOL_NAME.
# It automatically adds/removes tool directories from PATH as you navigate
# between directories, enabling seamless tool version switching.
#
# Features:
# - Automatic PATH management on directory change
# - Idempotent operations (safe to run multiple times)
# - Support for both Bash and Zsh shells
# - Prevention of PATH duplication
#
# Installation:
# This script is automatically sourced by supported shell configurations
# when $TOOL_NAME is installed.
# =============================================================================

# =============================================================================
# CORE PATH MANAGEMENT FUNCTION
# =============================================================================

# This function adds tool_bin_dir to PATH if it exists and isn't already there.
# It is designed to be idempotent and prevent PATH duplication.
# When navigating to subdirectories of a project, it keeps the project's tool path in PATH.
update_path() {
  # Look for the active tools directory in the current location
  local tool_bin_dir="$(pwd)/$TOOL_FOLDER/active"
  local current_pwd="$(pwd)"

  # Only proceed if the tool directory exists in the current directory
  if [ -d "$tool_bin_dir" ]; then
    # Check if tool_bin_dir is already in PATH to avoid duplicates
    case ":$PATH:" in
      *":$tool_bin_dir:"*) 
        # Already in PATH, do nothing (idempotent behavior)
        return 0
        ;;
      *)
        # Not in PATH, add it to the front for priority
        export PATH="$tool_bin_dir:$PATH"
        # Optional: Uncomment the line below for debugging
        # echo "$TOOL_NAME: Added $tool_bin_dir to PATH"
        ;;
    esac
  else
    # Current directory doesn't have .luca/active
    # Check if there are any .luca/active entries in PATH that should be cleaned up
    if [[ ":$PATH:" == *"/$TOOL_FOLDER/active:"* ]]; then
      local p
      local new_path=""
      local current_path="$PATH"
      
      while [ -n "$current_path" ]; do
        p="${current_path%%:*}"
        
        if [ "$current_path" = "$p" ]; then
            current_path=""
        else
            current_path="${current_path#*:}"
        fi

        if [[ "$p" == *"/$TOOL_FOLDER/active" ]]; then
          # This is a tool directory entry - check if we should keep it
          # Get the project root (parent of .luca/active)
          local project_root="${p%/$TOOL_FOLDER/active}"
          # Keep this entry if current directory is the project root or a subdirectory of it
          if [[ "$current_pwd" == "$project_root" || "$current_pwd" == "$project_root/"* ]]; then
            new_path="${new_path:+$new_path:}$p"
          fi
          # Otherwise, skip this entry (effectively removing it from PATH)
        else
          # Not a tool directory, keep it in PATH
          new_path="${new_path:+$new_path:}$p"
        fi
      done
      export PATH="$new_path"
    fi
  fi
}

# =============================================================================
# SHELL CONFIGURATION INSTALLATION
# =============================================================================

# This function is used by the install process to add the hook to the shell's RC file.
# It automatically detects the shell type and modifies the appropriate configuration file.
install_shell_hook() {
  local shell_rc_file
  local hook_line="[[ -s \"\$HOME/$TOOL_FOLDER/shell_hook.sh\" ]] && source \"\$HOME/$TOOL_FOLDER/shell_hook.sh\""

  # Detect the current shell and set the appropriate RC file
  case "$SHELL" in
    */bash)
      shell_rc_file="$HOME/.bashrc"
      # echo "Detected Bash shell, using $shell_rc_file"
      ;;
    */zsh)
      shell_rc_file="$HOME/.zshrc"
      # echo "Detected Zsh shell, using $shell_rc_file"
      ;;
    *)
      echo "WARNING: Unsupported shell: $SHELL"
      echo "Manual setup may be required. Supported shells: bash, zsh"
      return 1
      ;;
  esac

  # Add the source line to the RC file if it's not already there
  if ! grep -Fxq "$hook_line" "$shell_rc_file" 2>/dev/null; then
    # Create the RC file if it doesn't exist
    touch "$shell_rc_file"
    
    # Add our hook with proper formatting
    {
      echo ""
      echo "# Initialize $TOOL_NAME shell hook (added by $TOOL_NAME installer)"
      echo "$hook_line"
    } >> "$shell_rc_file"
    
    echo "✅ Shell hook installed in $shell_rc_file"
    echo "💡 Please restart your shell or run: source $shell_rc_file"
  # else
  #   echo "ℹ️  Shell hook already present in $shell_rc_file"
  fi
}

# =============================================================================
# SHELL HOOK REGISTRATION
# =============================================================================
# This code runs every time the script is sourced (i.e., on new terminals).
# It registers the 'update_path' function to run before each prompt,
# enabling automatic PATH updates when navigating between directories.

case "$SHELL" in
  */bash)
    # For Bash, we add our function to the beginning of PROMPT_COMMAND.
    # This ensures it runs before the prompt is displayed.
    # We also check to avoid adding it multiple times in the same session.
    if [[ ! "$PROMPT_COMMAND" =~ "update_path" ]]; then
      PROMPT_COMMAND="update_path;${PROMPT_COMMAND}"
      # Optional: Uncomment for debugging
      # echo "$TOOL_NAME: Bash hook registered"
    fi
    ;;
  */zsh)
    # For Zsh, we use the standard 'add-zsh-hook' to add our function
    # to the 'precmd' hook, which runs before each prompt.
    # This is the clean, Zsh-native way to hook into prompt rendering.
    autoload -U add-zsh-hook 2>/dev/null || true
    if command -v add-zsh-hook >/dev/null 2>&1; then
      add-zsh-hook precmd update_path
      # Optional: Uncomment for debugging
      # echo "$TOOL_NAME: Zsh hook registered"
    fi
    ;;
  *)
    # For unsupported shells, we silently skip hook registration
    # The script can still be manually sourced if needed
    ;;
esac

# =============================================================================
# AUTO-INSTALLATION TRIGGER
# =============================================================================
# This section automatically triggers the installation when the script is sourced
# (but not when it's executed directly). This allows the installation script to
# simply source this file to complete the shell integration setup.

# Check if the script is being sourced (not executed directly)
# In bash: ${BASH_SOURCE[0]} != "$0" when sourced
# In zsh: we need a different approach because $0 behavior is different
if [[ -n "$BASH_VERSION" && "${BASH_SOURCE[0]}" != "$0" ]] || [[ -n "$ZSH_VERSION" && "${ZSH_EVAL_CONTEXT}" == *:file:* ]]; then
  # Script is being sourced, so run the installation
  install_shell_hook
  
  # Update the PATH immediately for the current directory
  update_path
fi