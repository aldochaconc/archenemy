#!/bin/bash
################################################################################
# STEP 2: DOTFILES SETUP
################################################################################
#
# Goal: Establish the user's dotfiles foundation. This step creates the
#       `~/.config/dotfiles` directory and performs a one-time copy of all
#       default configurations from the installer's repository into it.
#
#       This ensures that the user's configuration is completely detached
#       from the Archenemy installation files. The user is free to version
#       control, modify, or even delete this `dotfiles` directory without
#       affecting the installer's source.
#
#       NOTE: This installer will NOT use symlinks. The intention is to provide
#       a clean starting point. Users who wish to manage their dotfiles via
#       symlinking can implement that on their own after the installation.
#
run_step_2_setup_dotfiles() {
  log_info "Starting Step 2: Dotfiles Setup..."

  # --- Sub-step 2.1: Create the user's dotfiles directory ---
  _create_dotfiles_directory

  # --- Sub-step 2.2: Copy default configurations to dotfiles directory ---
  _copy_defaults_to_dotfiles

  log_success "Step 2: Dotfiles Setup completed."
}

#
# Creates the main directory for the user's customizable configurations.
#
_create_dotfiles_directory() {
  log_info "Creating user dotfiles directory at ~/.config/dotfiles..."
  mkdir -p "$HOME/.config/dotfiles"
}

#
# Performs a recursive copy of all files and directories from the installer's
# 'defaults' directory into the user's `~/.config/dotfiles` directory.
#
_copy_defaults_to_dotfiles() {
  log_info "Copying default configs to dotfiles directory..."
  cp -r "$ARCHENEMY_PATH/default/." "$HOME/.config/dotfiles/"
}
