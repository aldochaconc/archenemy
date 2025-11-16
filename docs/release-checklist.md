# v1.0.0 Release Checklist

Use this list before tagging/publishing the release. Keep it in git so every run is auditable.

## Automated verifications
- [ ] `bash -n installation/boot.sh`
- [ ] `shellcheck -x installation/boot.sh`
- [ ] `scripts/verify-defaults.sh`
- [ ] `git status -sb` shows only expected untracked folders (`ae-cli/`, `installation/defaults/` overrides if any).

## Manual smoke tests
- [ ] Phase 1 dry-run inside live env/chroot (mock `/mnt` with temp root, confirm sentinel registration).
- [ ] Phase 2 dry-run on installed system (run `installation/boot.sh` post reboot, confirm packages/cleanup/reboot flow, watchers enabled).
- [ ] Validate `ae-refresh-*.path` watchers: `systemctl --user status ae-refresh-hyprland.path` etc.

## Documentation updates
- [ ] README Quick Start + Module Topology reflect current module list.
- [ ] `docs/progress.md` finalized (no pending TODOs).
- [ ] `docs/defaults-audit.md` marked verified.
- [ ] Summarize risks/known limitations in release notes (lack of full hardware coverage, sentinel reliance, etc.).

## Tagging steps
- [ ] Run `git log --oneline origin/dev..` to review delta.
- [ ] Bump `version` file.
- [ ] Create annotated tag `git tag -a v1.0.0 -m "v1.0.0"`.
- [ ] Push branch + tag (`git push origin v1.0.0 && git push origin v1.0.0 --tags`).

## Post-release
- [ ] Open follow-up issues (cli integration, sentinel UX, hardware matrix).
- [ ] Archive logs/artifacts from validation run.
