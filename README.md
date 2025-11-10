# archenemy Installer Documentation

This document serves as the technical specification and reference for the archenemy installation system. It defines the architecture, standards, and detailed implementation of each installation step.

## Project Rules

### Origin and Philosophy

archenemy evolves from omarchy, adopting a KISS (Keep It Simple, Stupid) approach. The installer is self-documenting: each script describes what it does without requiring navigation through numerous bin scripts to understand the workflow.

### Code Standards

- **Environment Variables**: All environment variables are unified in `installation/boot.sh` and `installation/common.sh`. Each function must use local variables to avoid polluting the global environment.
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

Primary entry point once `install.sh` clones the repository. It exports the shared environment, wires error handling, and executes each step (`run_setup_*`) in sequence so shellcheck can resolve cross-step calls.

**Responsibilities**:

- Declare and export canonical environment variables (paths, repo metadata, user info)
- Set strict error handling (`set -euo pipefail`) and register `_handle_error`
- Source `installation/common.sh` to expose helpers/loggers to the rest of the run
- Source every script under `installation/steps/` and execute them in order (System Preparation → Bootloader → Drivers → Software → User Customization → Daemons → Cleanup → Reboot)

### Common Library: `installation/common.sh`

Single shared shell library imported by `boot.sh` and every step script.

**Responsibilities**:

- Export canonical directories (`ARCHENEMY_DEFAULTS_DIR`, `ARCHENEMY_USER_DOTFILES_DIR`, `ARCHENEMY_INSTALL_FILES_DIR`) and CLI toggles (dry-run)
- Provide `parse_cli_args`, `run_cmd`, and colorized logging helpers
- Offer thin wrappers for package installs (`_install_pacman_packages`, `_install_aur_packages`) and service management (`_enable_service`)
- Expose `_display_splash` so both the installer and post-install helpers can re-use the ANSI splash screen

Because every step sources this file via a relative path, shellcheck can follow function calls throughout the tree and canonical paths stay consistent.

## Installation Steps

### Path Conventions

The installer exposes a few canonical directories so every step references the same sources:

| Variable                             | Description                                                               |
| ------------------------------------ | ------------------------------------------------------------------------- |
| `ARCHENEMY_DEFAULTS_DIR`             | Repository defaults (system templates such as pacman, gpg, Plymouth)      |
| `ARCHENEMY_USER_DOTFILES_DIR`        | User-editable copy of `default/dotfiles` (synced to `~/.config/dotfiles`) |
| `ARCHENEMY_DEFAULTS_BASE_SYSTEM_DIR` | Step 1 assets (`pacman/`, `gpg/`, `sudoers/`)                             |
| `ARCHENEMY_DEFAULTS_BOOTLOADER_DIR`  | Step 2 assets (`plymouth/`, `sddm/`, `mkinitcpio/`)                       |
| `ARCHENEMY_DEFAULTS_DRIVERS_DIR`     | Step 3 driver assets (reserved)                                           |
| `ARCHENEMY_DEFAULTS_GRAPHICS_DIR`    | Step 4 Hyprland stack defaults (`hypr/`, `waybar/`, `backgrounds/`, etc.) |
| `ARCHENEMY_DEFAULTS_DOTFILES_DIR`    | Step 5 blueprint (`alacritty/`, `ghostty/`, `zsh/`, etc.)                 |
| `ARCHENEMY_DEFAULTS_DAEMONS_DIR`     | Step 6 daemon assets (`systemd/user` timers, etc.)                        |
| `ARCHENEMY_DEFAULTS_CLEANUP_DIR`     | Step 7 cleanup templates (reserved)                                       |

Each step sources `installation/common.sh` so these variables and the shared logging helpers are recognized by shellcheck.

Each step is a self-contained script with a single entry point function (`run_setup_*`). Steps are executed sequentially by the orchestrator and must source `installation/common.sh` so the path variables and logging helpers remain consistent.

Repository defaults are now grouped per step (`default/base_system`, `default/bootloader`, `default/graphics`, `default/dotfiles`, `default/daemons`, etc.). Each step copies only the directories it owns (e.g., Step 4 consumes `default/graphics/{hypr,waybar,mako,...}`, Step 5 reads `default/dotfiles/*`, Step 6 pulls timers from `default/daemons/systemd/user`), so there are no cross-step interdependencies and `default/dotfiles` remains the user blueprint.

> **Online Install Guard**  
> `install.sh` and `installation/boot.sh` now verify internet connectivity (ping/curl against Arch mirrors) before proceeding, matching the Arch Linux installation guide requirement for online installs and preventing mid-run failures (e.g., the ipinfo curl in the drivers step).

---

### Step 1: System Preparation

**Name**: System Preparation  
**File**: `installation/steps/base_system.sh`  
**Entry Point**: `run_setup_base_system()`

**Description**: Configures pacman, system GPG, temporary sudo rules, and developer toolchains so subsequent steps can run unattended.

**Requirements**:

- Base Arch Linux environment with sudo access
- Repository defaults under `$ARCHENEMY_DEFAULTS_DIR`
- Internet connectivity for package syncs

**TODO**: Installs repo-provided pacman configs, updates mirrors, applies system GPG defaults, grants passwordless sudo via installer templates, disables mkinitcpio hooks to avoid repeated rebuilds, installs `base-devel`, and builds the `yay` AUR helper.

**Functions**:

- `_configure_pacman()`: Installs pacman.conf and mirrorlist from `$ARCHENEMY_DEFAULTS_DIR/pacman` then runs `sudo pacman -Syu`
- `_configure_system_gpg()`: Deploys the repo `dirmngr.conf` to `/etc/gnupg`
- `_setup_first_run_privileges()`: Renders `/etc/sudoers.d/archenemy-first-run` using `$ARCHENEMY_INSTALL_FILES_DIR/sudoers/archenemy-first-run`
- `_configure_sudo_policy()`: Applies persistent sudo policy tweaks (e.g., `passwd_tries=10`)
- `_disable_mkinitcpio_hooks()`: Temporarily renames mkinitcpio pacman hooks to `.disabled`
- `_install_base_packages()`: Installs the `base-devel` group
- `_install_aur_helper()`: Clones, builds, and installs `yay`

---

### Step 2: Bootloader & Display

**Name**: Bootloader & Display  
**File**: `installation/steps/bootloader.sh`  
**Entry Point**: `run_setup_bootloader()`

**Description**: Sets up Plymouth, SDDM autologin, Limine, and Snapper, and re-enables mkinitcpio hooks in preparation for driver installs.

**Requirements**:

- Step 1 completed
- Defaults under `$ARCHENEMY_DEFAULTS_DIR/plymouth` and install files for SDDM/mkinitcpio
- Limine packages available

**TODO**: Installs Plymouth and copies the repo theme, installs/configures SDDM autologin from templates, configures Limine + Snapper (with retention tuning), deploys mkinitcpio hook snippets, re-enables mkinitcpio hooks, and runs `sudo limine-update`.

**Functions**:

- `_configure_plymouth()`: Installs Plymouth, copies the theme to `/usr/share/plymouth/themes/archenemy`, and sets it active
- `_configure_desktop_display_manager()`: Installs SDDM, renders `/etc/sddm.conf.d/autologin.conf`, enables `sddm.service`
- `_configure_limine_and_snapper()`: Installs Limine/Snapper, deploys mkinitcpio config fragments, finds the Limine config path (EFI/BIOS), creates Snapper configs for `/` and `/home`, adjusts retention, re-enables mkinitcpio hooks, updates Limine

---

### Step 3: Drivers & Hardware

**Name**: Drivers & Hardware  
**File**: `installation/steps/drivers.sh`  
**Entry Point**: `run_setup_drivers()`

**Description**: Installs networking/peripheral services and GPU drivers for Intel, AMD, and NVIDIA hardware, including hybrid configurations.

**Requirements**:

- mkinitcpio hooks re-enabled from Step 2
- `lspci` available
- Internet connectivity

**TODO**: Installs/starts iwd, tweaks wait-online, sets the wireless regulatory domain, installs Bluetooth + printing stacks, disables USB autosuspend, then probes GPUs via `_has_gpu` helpers to install vendor-specific drivers, adjust modprobe/mkinitcpio configs, and regenerate initramfs.

**Functions**:

- `_setup_networking()`: Installs `iwd`, `wireless-regdb`, `nss-mdns`; enables `iwd.service`; masks `systemd-networkd-wait-online`; sets regulatory domain with ipinfo.io
- `_setup_peripherals()`: Installs `bluez`, `bluez-utils`, `cups`, `avahi`; enables Bluetooth/CUPS services; writes USB autosuspend override
- `_install_intel_drivers()`: Installs Intel video acceleration packages when `_has_gpu "intel"` succeeds
- `_install_amd_drivers()`: Installs headers + Mesa stack + AMDGPU/Vulkan packages, enforces `amdgpu` modeset, injects module into mkinitcpio, regenerates initramfs
- `_install_nvidia_drivers()`: Chooses `nvidia-open-dkms` or `nvidia-dkms`, installs supporting utilities, configures DRM modeset, ensures hybrid modules load first, regenerates initramfs

Supporting helpers: `_get_kernel()`, `_get_kernel_headers()`, `_has_gpu()`, `_has_nvidia_open_gpu()`.

---

### Step 4: Graphics Environment

**Name**: Graphics Environment  
**File**: `installation/steps/graphics.sh`  
**Entry Point**: `run_setup_graphics()`

**Description**: Installs the Hyprland ecosystem (based on the official Hyprland docs and the Omarchy reference), copies the structural configs shipped under `default/graphics/{hypr,waybar,mako,walker,fcitx5,uwsm,backgrounds,fontconfig,chromium,...}` into `~/.config`, syncs the Hyprland keyboard layout with `/etc/vconsole.conf`, and configures the remaining UI assets (fonts, icons, GTK/GNOME defaults, MIME handlers, keyring) so the desktop boots with a complete baseline experience.

**Requirements**:

- Structural configs inside `$ARCHENEMY_DEFAULTS_GRAPHICS_DIR` (hypr, waybar, mako, walker, fcitx5, uwsm, elephant, backgrounds, fontconfig, chromium assets, etc.)
- `yay` bootstrapped during Step 1 (for Hyprland companions such as hyprsunset, walker, elephant)
- Access to `/etc/vconsole.conf` for keyboard layout sync

**TODO**:

- `_install_hyprland_stack()`: Installs Hyprland, hyprlock, hypridle, screenshot helpers, and deploys `default/graphics/hypr`
- `_install_session_management()`: Installs `uwsm` and copies `default/graphics/uwsm`
- `_install_waybar_stack()`: Installs Waybar and copies `default/graphics/waybar`
- `_install_notifications_stack()`: Installs mako + SwayOSD (libnotify, brightnessctl) and copies `default/graphics/{mako,swayosd}`
- `_install_input_method_configs()`: Installs fcitx5 packages and copies `default/graphics/fcitx5` + `default/graphics/environment.d`
- `_install_elephant_suite()`: Installs walker/elephant AUR helpers and copies `default/graphics/{elephant,walker}`
- `_install_visual_assets()`: Copies `default/graphics/{backgrounds,fontconfig}`, re-linking the default wallpaper
- `_configure_browser_defaults()`: Installs Chromium and copies `default/graphics/chromium*` plus `default/graphics/icons.theme`
- `_sync_hypr_keyboard_layout()`: Mirrors `/etc/vconsole.conf` (`XKBLAYOUT`) into `~/.config/hypr/hyprland.conf`
- `_install_fonts()` / `_install_icons()`: Installs bundled fonts/icons (FiraCode, Noto, repo icons)
- `_configure_gtk_gnome_defaults()`: Installs GTK themes plus GNOME fallback apps (nautilus, gnome-text-editor) and applies gsettings
- `_configure_mimetypes()`: Sets default handlers for common MIME types
- `_configure_default_keyring()`: Installs `gnome-keyring`/`polkit-gnome` and provisions an unlocked keyring

---

### Step 5: Dotfiles

**Name**: Dotfiles  
**File**: `installation/steps/dotfiles.sh`  
**Entry Point**: `run_setup_dotfiles()`

**Description**: Refreshes the detached dotfiles blueprint under `~/.config/dotfiles`, installs the shell/terminal packages required by that blueprint, copies the curated files into the live `~/.config`, wires optional TUIs/webapps through reusable helpers, and applies the remaining personalization (Git identity).

**Requirements**:

- Graphics stack installed (Step 4)
- Defaults under `$ARCHENEMY_DEFAULTS_DOTFILES_DIR`
- Optional: `ARCHENEMY_USER_NAME`, `ARCHENEMY_USER_EMAIL`

**TODO**:

- `_prepare_dotfiles_blueprint()`: Copies the curated directories/files (`alacritty`, `btop`, `git`, `lazygit`, `ghostty`, `kitty`, `bashrc`, `neovim.lua`, `starship.toml`, etc.) from `default/dotfiles` into `~/.config/dotfiles` without using broad globs
- `_install_shell_packages()`: Installs zsh, completion bundles, kitty, ghostty, and `oh-my-zsh-git`
- `_copy_dotfiles_to_config()`: Synchronizes the dotfiles blueprint into `~/.config`, replacing only the curated targets and reloading user systemd if available
- `_configure_zsh()` / `_configure_git()`: Applies the zsh config shipped under `default/dotfiles/zsh{,rc}` and sets Git identity from `ARCHENEMY_USER_NAME/EMAIL`
- `_create_desktop_entry()` / `_create_webapp_entry()`: Helper functions for future TUIs/webapps
- `_install_and_configure_tuis()` / `_install_and_configure_webapps()`: Blueprint hooks for registering TUIs/webapps alongside the dotfiles

---

### Step 6: Services Configuration

**Name**: Services Configuration  
**File**: `installation/steps/daemons.sh`  
**Entry Point**: `run_setup_daemons()`

**Description**: Finalizes core daemons: UFW firewall, systemd-resolved DNS, power profiles, and user-level monitors that must exist before the desktop session starts.

**Requirements**:

- Packages (`ufw`, `ufw-docker`, `power-profiles-daemon`) installable
- sudo privileges

**TODO**: Installs/configures UFW (with Docker allowances), links `/etc/resolv.conf` to the stub resolver, sets balanced/performance profiles via `powerprofilesctl`, deploys the bundled battery monitor systemd units into the user daemon tree, and applies structural system service tweaks such as faster shutdown timeouts.

**Functions**:

- `_configure_firewall()`: Installs UFW + ufw-docker, sets policies, opens installer-required ports, enables firewall service, reloads rules
- `_configure_dns_resolver()`: Symlinks `/etc/resolv.conf` to `/run/systemd/resolve/stub-resolv.conf`
- `_configure_power_management()`: Installs `power-profiles-daemon`, sets the profile based on battery detection, and calls `_deploy_battery_monitor_timer()`
- `_deploy_battery_monitor_timer()`: Copies `default/daemons/systemd/user/battery-monitor.{service,timer}` into `~/.config/systemd/user` and enables the timer when a user systemd session is active
- `_configure_system_services()`: Runs supplementary service tweaks (e.g., updatedb, systemd shutdown timeout)

---

### Step 7: Cleanup

**Name**: Cleanup  
**File**: `installation/steps/cleanup.sh`  
**Entry Point**: `run_cleanup()`

**Description**: Restores pacman defaults and removes installer-only sudo permissions.

**Requirements**:

- Steps 1–6 completed

**TODO**: Installs pacman.conf and mirrorlist from repo defaults and deletes `/etc/sudoers.d/archenemy-first-run`.

**Functions**:

- `_run_pacman_cleanup()`: Copies pacman defaults from `$ARCHENEMY_DEFAULTS_DIR/pacman` to `/etc/pacman*`
- `_cleanup_installer_sudo_rules()`: Removes the temporary sudoers file

---

### Step 8: Reboot

**Name**: Reboot  
**File**: `installation/steps/reboot.sh`  
**Entry Point**: `run_reboot()`

**Description**: Displays the completion message, emits desktop notifications, and provides a passwordless reboot shortcut for the final restart.

**Requirements**:

- All previous steps complete

**TODO**: Creates a temporary sudoers rule that permits `reboot` without a password, installs `libnotify`, sends reminders (update system, learn keybindings, set up Wi-Fi if offline), prints the ASCII logo, and prompts the user to reboot (calling `sudo reboot` if confirmed).

**Functions**:

- `_allow_passwordless_reboot()`: Writes `/etc/sudoers.d/99-archenemy-installer-reboot`
- `_display_finished_message()`: Installs `libnotify`, sends notifications, displays the logo, handles the reboot prompt

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
   shellcheck -x install.sh installation/boot.sh installation/common.sh installation/steps/*.sh
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
- Public entry points: `run_setup_descriptive_name`
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
