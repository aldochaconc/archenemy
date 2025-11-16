# Archenemy

Modular installer for opinionated Arch Linux deployments. Every subsystem exposes `installation/<module>.sh` with its defaults under `installation/defaults/<module>`. The orchestrator (`installation/boot.sh`) executes those modules in a deterministic order for the preinstall and postinstall phases.

## Quick Start

1. Prepare an Arch base install (root filesystem + user) or boot the live ISO and mount `/mnt` as usual.
2. Fetch the repo and run the bootstrapper:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/aldochaconc/archenemy/dev/install.sh | bash
   ```
3. Phase 1 (preinstall) runs inside the live environment/chroot. When it finishes you will see a sentinel prompt on login explaining how to resume Phase 2 (postinstall) from the target system.
4. After rebooting into the installed system, log in on a TTY and run `installation/boot.sh` to finish Phase 2 before launching the graphical session.

### Sentinel Workflow
- Sentinel registration/removal now happens via the helpers in `installation/commons/sentinel.sh` and is invoked automatically from `boot.sh`.

### Phase Order
- Phase 1 (live environment/chroot): `system → packages → bootloader → drivers → desktop → apps`
- Phase 2 (postinstall from the target system): `system → bootloader → desktop → apps → packages → cleanup → reboot`

## Configuration & Customisation

- Global knobs (kernel flavour, preferred GPU driver, session names) live in `installation/commons/config.sh`. Override environment variables before invoking `install.sh` if you need non-default behaviour.
- Module defaults live under `installation/<module>/defaults`. To customise a subsystem, drop templates/assets there and consume them inside the module.
- The future `ae-cli` lives at `./ae-cli`. It is not wired into the installer yet but the folder documents CLI ideas and references borrowed from Omarchy.

## Module Topology

| Module/Tool  | Entry Point                  | Defaults Location                      | Purpose |
|--------------|------------------------------|----------------------------------------|---------|
| `system`     | `installation/system.sh`      | `installation/defaults/system`         | Pacman/GPG/sudo + security (UFW/SSH/DNS) + power profiles |
| `packages`   | `installation/packages.sh`    | `installation/packages/*.package`      | Installs curated pacman/AUR bundles |
| `bootloader` | `installation/bootloader.sh`  | `installation/defaults/bootloader`     | Plymouth, SDDM, Limine, Snapper |
| `drivers`    | `installation/drivers.sh`     | `installation/drivers/` (helpers)      | Networking services + Intel/AMD/NVIDIA stacks |
| `desktop`    | `installation/desktop.sh`     | `installation/defaults/{config,home}`  | Entire `.config` + dotfiles blueprint, GTK, keyring |
| `apps`       | `installation/apps.sh`        | `installation/defaults/applications`   | Desktop/webapp launchers + icons |
| `cleanup`    | `installation/cleanup.sh`     | `installation/defaults/system`         | Restores pacman + removes sudo rules |
| `reboot`     | `installation/reboot.sh`      | n/a                                    | Final prompt + notifications |
| Sentinel helper | built into `commons/sentinel.sh`      | `installation/sentinel/defaults`             | Registers/removes the postinstall prompt |

## Module Facts

### System
- Installs curated `pacman.conf` + mirrorlist, system GPG config, temporary sudoers entries, and bootstraps yay.
- Disables mkinitcpio hooks during heavy package installs to avoid redundant rebuilds.
- Applies firewall (UFW + ufw-docker), enables sshd, symlinks the resolver, configures power-profiles-daemon, and deploys the user-level battery monitor during postinstall.

### Packages
- Installs the curated bundles defined in `installation/packages/pacman.package` and `installation/packages/aur.package` so modules never need to call `_install_pacman_packages` for baseline dependencies.

### Bootloader
- Copies the Plymouth theme, renders SDDM autologin/branding, writes `limine.conf`, reinstalls Limine assets (EFI + BIOS), configures Snapper retention, and enables `limine-snapper-sync`.

### Drivers
- Installs networking packages (`iwd`, `wireless-regdb`, `nss-mdns`) and configures iwd/Avahi/CUPS/Bluetooth.
- Vendor submodules install the appropriate Mesa/NVIDIA stacks and rebuild the initramfs with the required modules.

### Desktop
- Copies the entire blueprint under `installation/defaults/desktop/config` into `~/.config` and applies home-level overrides from `installation/defaults/desktop/home` (shells, bashrc, etc.).
- Handles the extra system tweaks (Hypr keyboard sync, GTK/gsettings, keyring creation, mimetype defaults, bundled fonts/icons).
- Installs user-level `systemd` path units (`ae-refresh-hyprland/waybar/walker`) so `ae refresh …` runs automatically when blueprint configs change.

### Apps
- Ships `.desktop` entries and icons for curated PWAs/TUIs (Basecamp, Discord, Zoom, etc.).
- Refreshes the desktop database on every run (packages are provided by the Packages module).

### Cleanup
- Restores `pacman.conf` + mirrorlist from the system defaults and removes the temporary sudoers entry created during preinstall.

### Reboot
- Allows passwordless reboot, displays final notifications/logo, and prompts the operator to reboot.

### Sentinel Helper
- `commons/sentinel.sh` exposes `archenemy_register_sentinel`/`archenemy_remove_sentinel` helpers that modules call directly. Manual sentinel handling is no longer required.

## Logging & Diagnostics
- All modules use the common logging helpers. Output is appended to `/var/log/archenemy-install.log` (configure via `ARCHENEMY_INSTALL_LOG_FILE`).
- Pass `--dry-run` to `installation/boot.sh` to validate module sequencing without mutating the system.
- Run `shellcheck -x install.sh installation/boot.sh installation/commons/**/*.sh installation/*/*.sh` before committing changes.

## Developing New Modules
1. Create `installation/<module>/defaults` for assets and `<module>.sh` for logic.
2. Source `../commons/common.sh` and expose `run_<module>_preinstall`/`run_<module>_postinstall` wrappers that call into helper functions.
3. Document non-obvious functions using the `##################################################################` block comment style (NAME + purpose + notes).
4. Add your module to the boot sequence in `installation/boot.sh` and describe it in this README.
5. Place defaults inside `installation/defaults/<module>` (the Packages module consumes `installation/packages/*.package`).

## ae-cli
- The `ae-cli/` directory holds the CLI prototype copied from the Omarchy reference. It is intentionally decoupled until the installer stabilises. Use it as inspiration when building future tooling.
- Invoking `ae` inside the repo or installed tree exposes helper verbs (apps/media/system) so session toggles remain consistent with Hypr bindings.

## Reference Repo
- `omarchy-FOR-REFERENCE-ONLY/` remains untouched and serves purely as inspiration. All production logic has been migrated into the Archenemy modules.

## Current Worklog

1. Verify the new `ae-refresh-{hyprland,waybar,walker}.path` watchers on a fresh install (ensure they start even when `systemctl --user` is initially unavailable and document manual enable steps).
2. Smoke-test the refreshed postinstall sequence (`system → bootloader → desktop → apps → packages → cleanup → reboot`) so the desktop/app refreshers and ae-cli watchers run without manual intervention.
3. Summarise findings and next steps after the full trunk pass, including any ae-cli enhancements or installer adjustments detected during the review.
