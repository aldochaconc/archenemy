#!/bin/bash
################################################################################
# STEP 1: BOOTSTRAP
################################################################################
#
# Goal: Display the welcome splash screen and load the shared helper library.
#       This step prepares the environment for the subsequent installation steps
#       by making all helper functions available.
#
# Note: The repository cloning is handled by install.sh, the external entry point.
#       This step assumes the repository is already cloned and boot.sh is being
#       executed from within it.
#
run_step_1_bootstrap() {
  log_info "Starting Step 1: Bootstrap..."

  # --- Sub-step 1.1: Display welcome splash screen ---
  _display_splash

  # --- Sub-step 1.2: Load the installation helper library ---
  _load_installation_helpers

  log_success "Step 1: Bootstrap completed."
}

#
# Displays the initial ANSI art splash screen.
#
_display_splash() {
  local ansi_art='
 .S_SSSs     .S_sSSs      sSSs   .S    S.     sSSs   .S_sSSs      sSSs   .S_SsS_S.    .S S.
.SS~SSSSS   .SS~YS%%b    d%%SP  .SS    SS.   d%%SP  .SS~YS%%b    d%%SP  .SS~S*S~SS.  .SS SS.
S%S   SSSS  S%S    S%b  d%S     S%S    S%S  d%S     S%S    S%b  d%S     S%S  Y  S%S  S%S S%S
S%S    S%S  S%S    S%S  S%S     S%S    S%S  S%S     S%S    S%S  S%S     S%S     S%S  S%S S%S
S%S SSSS%S  S%S    d*S  S&S     S%S SSSS%S  S&S     S%S    S&S  S&S     S%S     S%S  S%S S%S
S&S  SSS%S  S&S   .S*S  S&S     S&S  SSS&S  S&S_Ss  S&S    S&S  S&S_Ss  S&S     S&S   SS SS
S&S    S&S  S&S_sdSSS   S&S     S&S    S&S  S&S~SP  S&S    S&S  S&S~SP  S&S     S&S    S S
S&S    S&S  S&S~YSY%b   S&S     S&S    S&S  S&S     S&S    S&S  S&S     S&S     S&S    SSS
S*S    S&S  S*S    S%b  S*b     S*S    S*S  S*b     S*S    S*S  S*b     S*S     S*S    S*S
S*S    S*S  S*S    S%S  S*S.    S*S    S*S  S*S.    S*S    S*S  S*S.    S*S     S*S    S*S
S*S    S*S  S*S    S&S   SSSbs  S*S    S*S   SSSbs  S*S    S*S   SSSbs  S*S     S*S    S*S
SSS    S*S  S*S    SSS    YSSP  SSS    S*S    YSSP  S*S    SSS    YSSP  SSS     S*S    S*S
       SP   SP                         SP           SP                          SP     SP
       Y    Y                          Y            Y                           Y      Y
                                                                                              '
  clear
  echo -e "\n$ansi_art\n"
}

#
# Loads the consolidated helper library once the repository exists locally.
# This makes all shared helper functions available to the subsequent installation
# steps.
#
_load_installation_helpers() {
  local helper_file="$ARCHENEMY_PATH/installation/helpers.sh"

  if [[ ! -f "$helper_file" ]]; then
    log_error "Required helper library not found at $helper_file"
    exit 1
  fi

  # shellcheck source=/dev/null
  source "$helper_file"
  log_info "Installation helpers loaded."
}
