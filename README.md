# archenemy Installer Documentation

This document serves as the technical specification and reference for the archenemy installation system. It defines the architecture, standards, and detailed implementation of each installation step.

## Project Rules

### Origin and Philosophy

archenemy evolves from omarchy, adopting a KISS (Keep It Simple, Stupid) approach. The installer is self-documenting: each script describes what it does without requiring navigation through numerous bin scripts to understand the workflow.

### Code Standards

- **Environment Variables**: All environment variables are unified and declared in `installation/boot.sh`. Each function must use local variables to avoid polluting the global environment.
- **shellcheck Compliance**: All scripts must pass shellcheck validation. Paths, functions, and commands are properly quoted and validated.
- **Safe Scripting**: Use guards, conditionals, and Linux commands to validate compatibility during installation. Apply `set -euo pipefail` for error handling.
- **Standardization**: The installer follows a standardized process up to the theming stage, ensuring consistency across installations.

### Design Decisions

- **No External Dependencies**: Avoid external mirrors and hardcoded paths. All assets are contained within the repository.
- **No Incremental Updates**: The installer does not support migrations or incremental updates. It is designed for clean installations.
- **Dotfiles as Placeholder**: The `dotfiles` directory is a placeholder for users to initialize their own dotfile management.
- **bin Directory Deprecation**: The `bin` directory is being phased out. Functions previously in `bin` are moved to their corresponding step scripts.

### Documentation Standards

- **Language**: All documentation and inline comments must be in English.
- **Style**: Technical, concise, non-verbose. Documentation explains code without conversational embellishments.
- **Comprehensiveness**: Every function, variable, command, and section must be thoroughly documented to enable LLMs and AI assistants to understand and modify the code without ambiguity.
- **References**: Use clear references between files and functions to maintain traceability.

### Project Naming

The project is named `archenemy` (all lowercase).

## Installation Architecture

### Orchestrator: `installation/boot.sh`

The main entry point after repository cloning. Defines global environment variables, error handling, logging, and executes installation steps in sequence.

**Responsibilities**:

- Declare and export global environment variables
- Define logging primitives (`log_info`, `log_success`, `log_error`)
- Set up error trapping with `_handle_error`
- Source and execute Steps 1-10 from `installation/steps/`

### Helper Library: `installation/helpers.sh`

Shared utility functions used across multiple installation steps.

**Functions**:

- `_install_pacman_packages`: Install packages via pacman
- `_install_aur_packages`: Install packages via yay (AUR helper)
- `_get_kernel_headers`: Detect and return appropriate kernel headers package
- `_has_gpu`: Check for GPU presence by vendor
- `_has_nvidia_open_gpu`: Check for NVIDIA GPUs compatible with open-source drivers
- `_create_desktop_entry`: Generate .desktop files for TUI applications
- `_create_webapp_entry`: Generate .desktop files for web applications
- `_enable_service`: Enable systemd services (with chroot awareness)

## Installation Steps

Each step is a self-contained script with a single entry point function (`run_step_N_*`). Steps are executed sequentially by the orchestrator.

---

### Step 1: Bootstrap

**Name**: Bootstrap
**File**: `installation/steps/1_bootstrap.sh`
**Entry Point**: `run_step_1_bootstrap()`

**Description**: Displays welcome splash screen and loads shared helper library.

**Requirements**:

- Repository already cloned at `$ARCHENEMY_PATH` (done by `install.sh`)
- Internet connection
- `pacman` package manager available
- User has `sudo` privileges

**Solution**: Displays ANSI art splash screen, sources `installation/helpers.sh` to make all helper functions available.

**Functions**:

- `_display_splash()`: Displays ANSI art welcome banner
- `_load_installation_helpers()`: Sources `installation/helpers.sh`

---

### Step 2: Dotfiles Setup

**Name**: Dotfiles Setup
**File**: `installation/steps/2_dotfiles.sh`
**Entry Point**: `run_step_2_setup_dotfiles()`

**Description**: Creates user dotfiles directory and performs one-time copy of default configurations.

**Requirements**:

- Repository cloned at `$ARCHENEMY_PATH`
- `$ARCHENEMY_PATH/default/` directory exists

**Solution**: Creates `~/.config/dotfiles/` and recursively copies all files from `$ARCHENEMY_PATH/default/` into it. This ensures user configurations are detached from installer source.

**Functions**:

- `_create_dotfiles_directory()`: Creates `~/.config/dotfiles/`
- `_copy_defaults_to_dotfiles()`: Recursively copies `$ARCHENEMY_PATH/default/.` to `~/.config/dotfiles/`

---

### Step 3: System Preparation

**Name**: System Preparation
**File**: `installation/steps/3_system_prep.sh`
**Entry Point**: `run_step_3_prepare_system()`

**Description**: Configures base system prerequisites: pacman, GPG, temporary sudo privileges, and AUR helper installation.

**Requirements**:

- Base Arch Linux installation
- Internet connection
- User with sudo access

**Solution**: Optimizes pacman configuration, sets up GPG for package signature verification, grants temporary passwordless sudo for installation commands, disables mkinitcpio hooks temporarily, installs `base-devel` and `yay`.

**Functions**:

- `_configure_pacman()`: Copies archenemy pacman.conf and mirrorlist, runs full system update
- `_configure_system_gpg()`: Copies GPG dirmngr.conf to `/etc/gnupg/`
- `_setup_first_run_privileges()`: Creates `/etc/sudoers.d/archenemy-first-run` with passwordless rules
- `_disable_mkinitcpio_hooks()`: Temporarily renames mkinitcpio hooks to `.disabled`
- `_install_base_packages()`: Installs `base-devel` group
- `_install_aur_helper()`: Clones and builds `yay` from AUR

---

### Step 4: Bootloader & Display

**Name**: Bootloader & Display
**File**: `installation/steps/4_bootloader.sh`
**Entry Point**: `run_step_4_configure_bootloader()`

**Description**: Configures bootloader (Limine), boot splash (Plymouth), and display manager (SDDM). Re-enables mkinitcpio hooks before driver installation.

**Requirements**:

- System preparation completed
- Limine bootloader installed (or installable via pacman)
- Btrfs filesystem (for Snapper integration)

**Solution**: Configures Plymouth theme, sets up SDDM autologin, configures Limine with Snapper for snapshot boot entries, defines mkinitcpio hooks with btrfs-overlayfs support, re-enables mkinitcpio hooks.

**Functions**:

- `_configure_plymouth()`: Installs Plymouth, copies archenemy theme, sets as default
- `_configure_sddm()`: Installs SDDM, creates autologin configuration for current user with Hyprland session, enables sddm.service
- `_configure_limine_and_snapper()`: Installs Limine and Snapper, creates mkinitcpio hooks configuration, detects Limine config path (EFI vs BIOS), configures Snapper for root and home, tweaks Snapper limits, re-enables mkinitcpio hooks, updates Limine

---

### Step 5: Drivers & Hardware

**Name**: Drivers & Hardware
**File**: `installation/steps/5_drivers.sh`
**Entry Point**: `run_step_5_drivers_and_hardware()`

**Description**: Detects and installs hardware drivers: networking, peripherals, and GPU drivers (Intel, AMD, NVIDIA).

**Requirements**:

- mkinitcpio hooks re-enabled (from Step 4)
- Internet connection
- `lspci` available for hardware detection

**Solution**: Configures iwd for wireless networking, disables networkd-wait-online to prevent boot delays, sets wireless regulatory domain, enables Bluetooth and CUPS services, disables USB autosuspend, detects GPUs via `lspci` and installs appropriate drivers with kernel modules and initramfs regeneration.

**Functions**:

- `_setup_networking()`: Installs iwd, wireless-regdb, nss-mdns; enables iwd.service; masks networkd-wait-online; sets wireless regulatory domain via ipinfo.io
- `_setup_peripherals()`: Installs bluez, cups, avahi; enables bluetooth, cups, avahi-daemon, cups-browsed services; disables USB autosuspend via modprobe.d
- `_install_intel_drivers()`: Checks for Intel GPU via `_has_gpu "intel"`, installs intel-media-driver and libva-intel-driver
- `_install_amd_drivers()`: Checks for AMD GPU, gets kernel headers via `_get_kernel_headers()`, installs Mesa stack, AMDGPU drivers, Vulkan, configures amdgpu modeset, adds amdgpu to mkinitcpio MODULES, regenerates initramfs
- `_install_nvidia_drivers()`: Checks for NVIDIA GPU, selects nvidia-open-dkms or nvidia-dkms via `_has_nvidia_open_gpu()`, installs drivers and utilities, configures nvidia_drm modeset, handles hybrid graphics (Intel/AMD iGPU + NVIDIA dGPU), adds modules to mkinitcpio in correct order, regenerates initramfs

---

### Step 6: Desktop Software

**Name**: Desktop Software
**File**: `installation/steps/6_software.sh`
**Entry Point**: `run_step_6_install_software()`

**Description**: Installs user-facing software: fonts, icons, core applications, TUIs, webapps, and system services like Docker.

**Requirements**:

- `yay` AUR helper installed (from Step 3)
- Repository cloned with assets

**Solution**: Installs fonts and icons from repository and pacman, configures Zsh as default shell with Oh My Zsh, enables Docker service and adds user to docker group, installs and creates desktop entries for TUIs (lazydocker, lazyjournal) and webapps (GitHub, Discord), generates first-run desktop helper script.

**Functions**:

- `_install_assets()`: Installs font packages, copies custom fonts to `~/.local/share/fonts`, copies icons to `~/.local/share/icons`, runs `fc-cache`
- `_configure_zsh()`: Installs zsh and oh-my-zsh-git, copies zsh config files from `$ARCHENEMY_PATH/default/zsh/`, copies .zshrc, changes user shell to zsh
- `_configure_system_services()`: Installs Docker, enables docker.service, adds user to docker group, configures Docker daemon with log rotation, runs updatedb, configures faster shutdown timeout
- `_install_and_configure_tuis()`: Installs TUI packages from AUR, creates desktop entries via `_create_desktop_entry()`
- `_install_and_configure_webapps()`: Installs Chromium, creates webapp desktop entries via `_create_webapp_entry()`
- `_create_first_run_runner()`: Generates `$ARCHENEMY_PATH/bin/archenemy-first-run` script with post-boot tasks (power config, firewall, DNS, theme, notifications)

---

### Step 7: User Configuration

**Name**: User Configuration
**File**: `installation/steps/7_user_config.sh`
**Entry Point**: `run_step_7_apply_user_config()`

**Description**: Applies user-specific configurations: dotfiles, GTK themes, application themes, Git settings, system tweaks, MIME types, keyring setup.

**Requirements**:

- Dotfiles copied to `~/.config/dotfiles/` (from Step 2)
- Desktop packages installed (from Step 6)

**Solution**: Copies configuration files from dotfiles directory to active config locations, applies GTK and icon themes via gsettings, configures application-specific themes, applies Git user settings from environment variables, applies system tweaks (sudo retries, keyboard layout detection), sets MIME types for default applications, creates unlocked default keyring, schedules first-run tasks.

**Functions**:

- `_apply_base_config()`: Copies core configs (hypr, alacritty, bashrc) from `~/.config/dotfiles/` to `~/.config/`
- `_create_theme_directory_structure()`: Creates `~/.config/archenemy/current/` with theme_path and background_path pointers
- `_apply_gtk_theme()`: Installs gnome-themes-extra and yaru-icon-theme, sets GTK theme to Adwaita-dark and icon theme to Yaru-blue via gsettings, updates icon cache
- `_apply_app_specific_themes()`: Copies theme files for btop and mako from dotfiles to active config
- `_apply_user_preferences()`: Configures Git user.name and user.email from `$ARCHENEMY_USER_NAME` and `$ARCHENEMY_USER_EMAIL`
- `_apply_system_tweaks()`: Sets sudo passwd_tries to 10, detects keyboard layout from vconsole.conf and applies to Hyprland config
- `_apply_mimetypes()`: Updates desktop database, sets default applications for images (imv), PDFs (evince), web browser (chromium), videos (mpv)
- `_setup_default_keyring()`: Creates Default_keyring.keyring in `~/.local/share/keyrings/` with unlocked settings
- `_schedule_first_run_tasks()`: Creates `~/.local/state/archenemy/first-run.mode` sentinel file

---

### Step 8: Services Configuration

**Name**: Services Configuration
**File**: `installation/steps/8_services.sh`
**Entry Point**: `run_step_8_configure_services()`

**Description**: Configures system services: firewall (UFW), DNS resolver (systemd-resolved), power management.

**Requirements**:

- All packages installed
- User has sudo access

**Solution**: Installs and configures UFW firewall with default deny policy and Docker-specific rules, creates systemd-resolved symlink for `/etc/resolv.conf`, detects battery and sets appropriate power profile.

**Functions**:

- `_configure_firewall()`: Installs ufw and ufw-docker, sets default policies, allows specific ports (53317 UDP/TCP), allows Docker DNS traffic, enables ufw.service, installs ufw-docker integration, reloads firewall
- `_configure_dns_resolver()`: Creates symlink `/etc/resolv.conf` -> `/run/systemd/resolve/stub-resolv.conf`
- `_configure_power_management()`: Installs power-profiles-daemon, detects battery presence via `/sys/class/power_supply/BAT*`, sets profile to balanced (laptop) or performance (desktop), enables omarchy-battery-monitor.timer if battery present

---

### Step 9: Cleanup

**Name**: Cleanup
**File**: `installation/steps/9_cleanup.sh`
**Entry Point**: `run_step_9_cleanup()`

**Description**: Cleans up temporary installer artifacts and restores default system configurations.

**Requirements**:

- Installation completed through Step 8

**Solution**: Restores original pacman configuration, removes temporary installer sudoers rules.

**Functions**:

- `_run_pacman_cleanup()`: Copies default pacman.conf and mirrorlist from `$ARCHENEMY_PATH/default/pacman/` to `/etc/pacman.conf` and `/etc/pacman.d/mirrorlist`
- `_cleanup_installer_sudo_rules()`: Removes `/etc/sudoers.d/archenemy-first-run`

---

### Step 10: Reboot

**Name**: Reboot
**File**: `installation/steps/10_reboot.sh`
**Entry Point**: `run_step_10_reboot()`

**Description**: Displays completion message, sends desktop notifications, and prompts user to reboot.

**Requirements**:

- All installation steps completed

**Solution**: Grants temporary passwordless reboot permission, sends welcome notifications, displays archenemy logo, prompts for reboot.

**Functions**:

- `_allow_passwordless_reboot()`: Creates `/etc/sudoers.d/99-archenemy-installer-reboot` with passwordless reboot permission
- `_display_finished_message()`: Installs libnotify, sends notify-send messages (update system, keybindings, wifi setup if offline), displays logo from `$ARCHENEMY_PATH/logo.txt`, prompts user to reboot, executes `sudo reboot` if confirmed

## LLM Implementation Guidelines

This section establishes a mandatory protocol for LLMs to apply code modifications to the archenemy project. Following this protocol ensures consistency across documentation, code, and architecture.

### Modification Protocol

All code changes MUST follow this sequential, 5-phase workflow:

#### Phase 1: Investigation

Before making any changes, perform a complete analysis of the current implementation:

1. **Read Current Implementation**

   - Read the entire target file/function
   - Identify all functions, variables, and their types
   - Document current parameter passing methods
   - Note all global vs local variable usage

2. **Map Dependencies**

   - List all files that source or call the target code
   - Identify all functions the target code calls
   - Document data flow: inputs → processing → outputs
   - Map execution order and conditional branches

3. **Analyze Error Handling**

   - Document current error handling strategy
   - Identify missing error checks
   - Note validation gaps
   - List guard conditions present/missing

4. **Identify References**
   - Search for all references to the target in:
     - `README.md`
     - All step scripts
     - Helper scripts
     - Configuration files

#### Phase 2: Analysis

Evaluate the current implementation for issues:

1. **Code Quality Issues**

   - Naming inconsistencies (check against conventions)
   - Missing guards or validations
   - Error handling gaps
   - Incompatible variable types
   - Hardcoded paths or values
   - Missing local variable declarations

2. **shellcheck Compliance**

   - Run `shellcheck -x` on target file
   - Document all warnings and errors
   - Plan fixes for each issue

3. **Impact Assessment**
   - Identify all dependent code requiring updates
   - Assess risk level of proposed changes
   - Plan backward compatibility if needed

#### Phase 3: Design

Plan the implementation before writing code:

1. **Define Changes**

   - Write technical specification of changes
   - Define new variable names (follow conventions below)
   - Specify new function signatures
   - Plan error messages

2. **Plan Guards and Validations**

   - List required input validations
   - Define error conditions to handle
   - Specify guard clauses needed
   - Plan fallback behaviors

3. **Update Plan**
   - List all files requiring modification
   - Define modification sequence
   - Specify documentation updates needed

#### Phase 4: Implementation Order

**CRITICAL**: Changes MUST be applied in this exact sequence. Deviation from this order breaks consistency.

**Step 1: Update README.md FIRST**

Before touching any code:

- Update the relevant step's Requirements section if prerequisites change
- Update the Solution section if approach changes
- Update or add function descriptions in the Functions list
- Document architectural decisions if structure changes
- Add new sections if introducing new concepts

**Step 2: Update Target Script/Function**

Only after README is updated:

- Apply code changes
- Add/update inline documentation for every function:
  ```bash
  #
  # Brief description of what the function does.
  #
  # Arguments:
  #   $1: Description of first parameter
  #   $2: Description of second parameter
  #
  # Returns:
  #   Description of return value/exit code
  #
  # Side Effects:
  #   - List any file system changes
  #   - List any environment modifications
  #   - List any external commands executed
  #
  function_name() {
    local param1="$1"
    local param2="$2"
    # ... implementation
  }
  ```
- Declare all variables as `local` unless they must be global
- Add error handling for all failure points
- Follow shellcheck recommendations

**Step 3: Update Dependent Files**

After target is updated:

- Update all scripts that call modified functions
- Update variable references throughout codebase
- Update `source` statements if paths changed
- Update `shellcheck source=` directives if needed

**Step 4: Verify Consistency**

Final check before completion:

- Run `shellcheck -x` on all modified files
- Verify README matches implementation
- Confirm naming conventions followed
- Check all references updated

#### Phase 5: Validation

Mandatory final validation:

1. **Linter Validation**

   ```bash
   shellcheck -x install.sh installation/boot.sh installation/steps/*.sh installation/helpers.sh
   ```

2. **Reference Validation**

   - Search for old function/variable names
   - Verify no broken imports
   - Check documentation consistency

3. **Convention Compliance**
   - Verify variable naming conventions
   - Check function naming conventions
   - Confirm error handling present

### Documentation Synchronization Rules

**Rule 1: Documentation First**

README.md MUST be updated BEFORE code changes. This serves as:

- Design specification that guides implementation
- Historical record of architectural decisions
- Source of truth for current system state

**Rule 2: Inline Documentation Requirements**

Every function must have complete documentation:

- **Purpose**: One-sentence description
- **Parameters**: Document each argument
- **Returns**: Document return values/exit codes
- **Side Effects**: Document file changes, env modifications, external commands

**Rule 3: Architectural Decisions**

Any structural change must be documented:

- Moving files → Update "Installation Architecture" section
- Renaming functions → Update relevant step's "Functions" list
- Changing data flow → Update step's "Solution" section
- Adding steps → Create new step entry with full specification

### Code Quality Requirements

**Variable Naming Conventions**:

- Global exports: `ARCHENEMY_*` (UPPER_CASE)
- Local variables: `lowercase_with_underscores`
- Private functions: `_function_name` (underscore prefix)
- Public entry points: `run_step_N_descriptive_name`
- Constants: `READONLY_VALUE` (UPPER_CASE)

**Error Handling Requirements**:

- Every script: `set -euo pipefail` at the top
- External inputs: Validate before use
- File operations: Check existence first
- Command execution: Verify command exists
- Network operations: Handle timeouts/failures
- Error messages: Use `log_error` with context

**Guard and Validation Patterns**:

```bash
# Check command availability
if ! command -v git &>/dev/null; then
  log_error "git is required but not installed"
  exit 1
fi

# Verify file existence
if [[ ! -f "$config_file" ]]; then
  log_error "Config file not found: $config_file"
  exit 1
fi

# Validate directory
if [[ ! -d "$target_dir" ]]; then
  log_error "Directory does not exist: $target_dir"
  exit 1
fi

# Check for root/sudo
if [[ $EUID -eq 0 ]]; then
  log_error "This script must not be run as root"
  exit 1
fi

# Network connectivity
if ! ping -c 1 -W 1 1.1.1.1 >/dev/null 2>&1; then
  log_error "No network connectivity"
  exit 1
fi
```

**shellcheck Compliance**:

- Quote all variable expansions: `"$var"` not `$var`
- Use `[[ ]]` for tests, not `[ ]`
- Avoid useless `cat`, use redirections
- Handle word splitting properly
- Use `command -v` not `which`
- Declare functions before use

### Example: Complete Modification Workflow

This example demonstrates adding a new validation function to Step 3 (System Preparation).

**Scenario**: Add a function to verify available disk space before installation.

**Phase 1: Investigation**

```bash
# Read current implementation
cat installation/steps/3_system_prep.sh

# Identify dependencies
grep -r "_install_base_packages" installation/

# Check README
grep -A 10 "Step 3: System Preparation" README.md
```

**Phase 2: Analysis**

- Current implementation lacks disk space validation
- No guard against insufficient space
- Should run before package installation
- Requires `df` command (available in coreutils)

**Phase 3: Design**

```
Function name: _verify_disk_space
Parameters: None (uses / partition)
Minimum required: 10GB
Error handling: Exit if insufficient
Location: Before _install_base_packages call
```

**Phase 4: Implementation**

Step 1 - Update README.md:

```markdown
### Step 3: System Preparation

**Functions**:

- `_configure_pacman()`: ...
- `_configure_system_gpg()`: ...
- `_verify_disk_space()`: Checks available disk space on root partition, requires minimum 10GB free
- `_setup_first_run_privileges()`: ...
```

Step 2 - Update 3_system_prep.sh:

```bash
#
# Verifies that sufficient disk space is available for installation.
# Requires minimum 10GB free on root partition.
#
# Returns:
#   0 if sufficient space available
#   1 if insufficient space
#
_verify_disk_space() {
  log_info "Checking available disk space..."
  local required_gb=10
  local available_gb

  # Get available space in GB
  available_gb=$(df / | awk 'NR==2 {print int($4/1024/1024)}')

  if [[ $available_gb -lt $required_gb ]]; then
    log_error "Insufficient disk space. Required: ${required_gb}GB, Available: ${available_gb}GB"
    return 1
  fi

  log_info "Disk space check passed: ${available_gb}GB available"
  return 0
}

run_step_3_prepare_system() {
  log_info "Starting Step 3: System Preparation..."

  # --- Sub-step 3.1: Verify disk space ---
  _verify_disk_space

  # --- Sub-step 3.2: Configure pacman and system repositories ---
  _configure_pacman

  # ... rest of function
}
```

Step 3 - Update dependent files:

- None in this case (new function)

Step 4 - Verify consistency:

- README lists new function
- Function has complete documentation
- Uses local variables
- Has error handling
- Follows naming conventions

**Phase 5: Validation**

```bash
shellcheck -x installation/steps/3_system_prep.sh
grep "_verify_disk_space" README.md
```

This workflow ensures:

- Documentation updated before code
- Complete inline documentation
- Proper error handling
- Naming conventions followed
- All changes validated
