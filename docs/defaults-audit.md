# Defaults Audit

This file summarizes the verification of every artifact under `installation/defaults/`.
Goal: ensure every directory/file has a consumer in `installation/*.sh` or the runtime,
and no path points to legacy assets.

## System defaults (`installation/defaults/system`)

- Files: `pacman/pacman.conf`, `pacman/mirrorlist`, `gpg/dirmngr.conf`,
  `sudoers/archenemy-first-run`, `power/systemd/user/battery-monitor.{service,timer}`.
- Consumers:
  - `installation/system.sh` -> `SYSTEM_DEFAULTS_DIR/pacman/*`, `.../gpg/dirmngr.conf`.
  - `installation/system.sh` -> `SYSTEM_POWER_UNITS_DIR` (`power/systemd/user`).
  - `installation/cleanup.sh` -> restores pacman.conf/mirrorlist from `defaults/system/pacman`.
  - `installation/system.sh` + `cleanup.sh` -> `sudoers/archenemy-first-run`.
- Checks run:
  - `find installation/defaults/system -type f | sort`.
  - `bash -n installation/system.sh installation/cleanup.sh`.
  - `shellcheck -x installation/system.sh installation/cleanup.sh`.

## Bootloader defaults (`installation/defaults/bootloader`)

- Files: `mkinitcpio/archenemy_hooks.conf`, plymouth theme directory, SDDM templates.
- Consumers: `installation/bootloader/lib.sh`, `plymouth.sh`, `sddm.sh`, `limine.sh`.
  - Verified shellcheck directives now point to repo paths.
- Checks:
  - `ls installation/defaults/bootloader/{plymouth,sddm,mkinitcpio}`.
  - `bash -n installation/bootloader.sh installation/bootloader/*.sh`.
  - `shellcheck -x installation/bootloader.sh installation/bootloader/*.sh`.

## Desktop defaults (`installation/defaults/desktop`)

- Config tree provides dotfiles under `.../config`, optional home overrides under `.../home`.
- Consumers: `installation/desktop.sh` (`DESKTOP_CONFIG_DEFAULTS`, `DESKTOP_HOME_DEFAULTS`).
- Watchers: `config/systemd/user/ae-refresh-{hyprland,walker,waybar}.{path,service}` match
  `DESKTOP_CONFIG_WATCHERS` array.
- Checks:
  - `ls installation/defaults/desktop/{config,home}`.
  - `rg --files installation/defaults/desktop/config/systemd/user | sort`.
  - `bash -n installation/desktop.sh`; `shellcheck -x installation/desktop.sh`.

## Applications defaults (`installation/defaults/applications`)

- Contains `.desktop` launchers (including `hidden/`) and icon assets under `icons/`.
- Consumer: `installation/apps.sh` (rsync to `~/.local/share/applications` and icons dir).
- Checks:
  - `ls installation/defaults/applications | head`.
  - `bash -n installation/apps.sh`; `shellcheck -x installation/apps.sh`.

## Sentinel defaults (`installation/defaults/sentinel`)

- File: `postinstall-profile.sh`.
- Consumer: `installation/commons/sentinel.sh`.
- Verified via `find installation/defaults/sentinel -type f`.

## Summary

- Every defaults subtree has explicit consumers. During the rewrite all legacy
  `installation/steps/*` paths were removed (confirmed via `rg --files installation`).
- All scripts referencing defaults now include module headers + shellcheck-friendly paths
  and passed `bash -n` + `shellcheck -x`.
- Remaining work: monitor `README.md` (manual edits) and ensure `install.sh`
  references the new structure (tracked separately).
