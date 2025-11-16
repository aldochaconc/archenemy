# v1.0.0 Progress Log

Temporary notebook to cache decisions and tasks while consolidating version 1.0.0. Every entry must allow anyone to regain context without browsing commit history.

## Module checklist

| Surface                        | Status     | Scope / Includes                                                                                        | Key notes                                                                   |
| ------------------------------ | ---------- | -------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| `installation/commons/`        | Ready       | Shared helpers invoked from `system.sh`, `bootloader`, `drivers`, etc.                                   | Inline docs + lint complete; stage for commit after risk review.            |
| `installation/system.sh`       | Pending    | Main orchestrator; entry point calling `bootloader.sh`, `desktop.sh`, and the rest of the installer.     | Must preserve logical order and handle global flags.                        |
| `installation/packages/`       | Pending    | `core`, `pacman`, `aur`, `apps` lists plus the `packages.sh` script that ties them together.             | Watch for duplicates and script cross dependencies.                         |
| `installation/bootloader.*`    | Pending    | `bootloader.sh`, the `bootloader/` directory, `mkinitcpio` hooks, plymouth themes.                       | Confirm referenced assets and config paths exist.                           |
| `installation/drivers.*`       | Pending    | `drivers.sh` plus `drivers/` subfolders (GPU, input, firmware).                                          | Validate hardware detection logic and minimal package sets.                 |
| `installation/desktop.*`       | Pending    | `desktop.sh`, `defaults/`, `installation/defaults/`, Hypr/graphics scripts, dotfiles.                   | Keep assets and installer behavior in sync.                                 |
| `installation/cleanup.sh`/`reboot.sh` | Pending    | Final cleanup and reboot scripts, sentinel services.                                                     | Ensure they clear logs/tmp and control final machine state.                 |
| `defaults/`                    | Pending    | Dotfiles, assets, systemd user services, wallpapers, icons.                                              | Confirm scripts install them into the expected paths.                       |

*(Add/remove rows as progress changes; mark the Status column as `In Progress` or `Done` when applicable.)*

## Activity log

- **2025-11-16 17:10 -03** Branch `v1.0.0` created to encapsulate the stable release work.
- **2025-11-16 17:15 -03** Added this log in `docs/progress.md` to cache decisions and module checklist.
- **2025-11-16 17:15 -03** TODO: build a detailed inventory per module before starting commits.
- **2025-11-16 17:18 -03** Inline documentation rules defined for every new or modified script.
- **2025-11-16 17:20 -03** Quality checklist added to mitigate untested regressions after the rewrite.
- **2025-11-16 17:22 -03** Proactive decision guide published to standardize refactors and cleanups.
- **2025-11-16 17:25 -03** Decision log usage hardened (mandatory reading, aggressive pattern enforcement) and verification flow documented.
- **2025-11-16 17:30 -03** Progress log migrated to English to match repository language requirements.
- **2025-11-16 17:31 -03** Context loaded — branch `v1.0.0`, `pwd=/home/crystal/Work/archenemy`, `AE_ROOT=<unset>`, `XDG_CONFIG_HOME=/home/crystal/.config`.
- **2025-11-16 17:32 -03** Module `installation/commons/` flagged as In Progress; baseline listing via `ls installation/commons` shows `common.sh`, `config.sh`, `core.sh`, `env.sh`, `packages.sh`, `sentinel.sh`, `systemd.sh`.
- **2025-11-16 17:33 -03** Added suggestions queue and clarified that the “Immediate next steps” list is refreshed on every work block.
- **2025-11-16 17:35 -03** Reviewed each helper in `installation/commons/` via `sed -n '1,200p'` to map structure; detected missing context headers, variable glossaries, and inline comments across the module.
- **2025-11-16 17:37 -03** Ran `git show origin/dev:installation/common.sh` to compare legacy helpers; confirmed functionality parity (logging, phase detection, package/systemd helpers) but documentation patterns still pending.
- **2025-11-16 17:38 -03** Defined commons work plan: add inline docs per file, then run `bash -n installation/commons/*.sh` and `shellcheck -x installation/commons/*.sh` with results logged.
- **2025-11-16 17:40 -03** Added context headers, variable glossaries, and precondition notes across `installation/commons/*.sh`.
- **2025-11-16 17:41 -03** Ran `bash -n installation/commons/*.sh` and `shellcheck -x installation/commons/*.sh`; resolved SC1091 info messages by pointing shellcheck directives to project-root paths.
- **2025-11-16 17:48 -03** Commons risk review: no outstanding TODOs beyond pending commit; readiness set to “Ready” in module table.
- **2025-11-16 17:48 -03** Next focus: prepare documentation/testing plan for `installation/system.sh` mirroring the process used for commons (add top-level header + variable glossary, document each `_system_*` helper, then run `bash -n installation/system.sh` and `shellcheck -x installation/system.sh`).

## Immediate next steps

*(This list is refreshed at the beginning of each working block; update it whenever priorities change so it always reflects the current sprint.)*

1. Stage and prepare the commons-only commit (verify `git diff --stat installation/commons docs/progress.md` and capture tests in the message).
2. Apply the documented header/glossary/comment updates to `installation/system.sh`.
3. Run `bash -n installation/system.sh` and `shellcheck -x installation/system.sh`, logging outcomes + risks.

## Suggestions queue

- Use this section to record missing processes, configurations, commands, or helper functions that should exist but are not yet implemented.
- Each entry should include timestamp, scope, suggested action, and whether it blocks current work.
- When a suggestion is addressed, annotate the entry with the commit or log line that resolved it, then archive or remove it.
- **2025-11-16 17:35 -03** — Scope: `installation/commons/*.sh`. Action: add context headers + variable glossaries + flow comments per inline rules. Status: blocking for commons sign-off. **Resolved 2025-11-16 17:40 -03** — inline docs added, see activity log entry for timestamp.

## Baseline checklist

- **Environment verified**: before touching code, log the active branch (`git branch --show-current`), `pwd`, and any critical variables (`$AE_ROOT`, `$XDG_CONFIG_HOME`, etc.) to ensure reproducibility.
- **Critical paths mapped**: record directories/files involved in each task (`installation/commons`, `installation/system.sh`, `defaults/...`) and their relationships; cross-link new dependencies in the module table.
- **Pre-analysis**: document the commands used to understand the state (`rg`, `fd`, `shellcheck`, `bash -n`, legacy vs new diffs). Enables repeating the sweep if the session is lost.
- **Log format**: every entry must include local timestamp, scope (module/file), decision or finding, and remaining actions. Prefix pending tasks with `TODO:` for easy grepping.
- **Command trace**: whenever a script runs or is simulated, capture the command and rationale in the log. Avoid running anything without notes.
- **Final validations**: before committing a module, log which tests/lints ran, which files were staged (`git add` scope), and what was intentionally left out.

## Decision log requirements

- Before any verification, read this document end-to-end and add a log line like “Context loaded — <time>”.
- Every rule here is mandatory; if an exception is required, justify it in the log and capture a corrective action.
- Follow existing patterns aggressively: if a file lacks the adopted pattern (headers, helpers, layout), refactor immediately or log a blocking TODO before proceeding.
- Do not accept half-baked code: if a module misses any section (inline docs, checklists, risks), block the commit and record what is pending.

## Inline documentation rules

- **Context header**: each script must start with a commented block describing goal, preconditions, and expected outcome. Language must stay impersonal, technical, and sober.
- **Variable glossary**: before first use, list meaningful variables with the format `# VAR=meaning`, clarifying type (string/list) and origin (input, env, local computation).
- **Flow comments**: before complex blocks (loops, conditionals, pipes) write one sentence about what is being validated or transformed. Focus on the “why”, not the literal command.
- **Command references**: when invoking tools with obscure flags (`pacstrap`, `mkinitcpio`, `hyprctl`), explain the intent and, if relevant, reference the configuration file involved.
- **Style consistency**: use `# ` prefix, avoid sarcasm/emojis/personal tone. Keep lines <100 chars to aid readability.
- **Mandatory updates**: no PR/commit passes unless new work follows these rules. Add a log note when a file becomes compliant.

## Rewrite quality checklist

- **Compare against legacy**: even though `omarchy` was removed, use `git show origin/dev -- <path>` to confirm key behaviors were preserved.
- **Minimum self-checks**: run `bash -n`, `shellcheck -x`, and scripts under `set -euo pipefail` with mocks whenever feasible. Log results and limitations.
- **Validate dependencies**: keep an explicit inventory of binaries/packages used by each module. If a package vanished from official repos, note alternatives or TODOs before committing.
- **Controlled simulations**: rely on chroot or containers before executing real installers; record commands and artifacts produced for reproducibility.
- **Cross-review**: review every commit against the log and inline-doc checklists; if something does not apply (e.g., binary assets), state why to avoid gaps.
- **Known risks**: include a “Risks” subsection per module in the log, describing potential failures due to missing real tests. Update it when closing each commit so nobody assumes it is safe.

## Proactive decision guide

- **Unused functions**: if `rg -n <func>` shows no callers, either remove it or move it to a sandbox file tagged “TODO: evaluate future use”. Log the action.
- **Wrapper simplification**: when a function wraps a trivial command, consider inlining it with a descriptive comment. If kept, justify (e.g., future extension).
- **Redundant variables**: consolidate variables that duplicate data (`TARGET_DIR` vs `DEST_DIR`). Before removing, scan all scripts with `rg` and note the avoided breakage.
- **Parameters and flags**: if a script supports flags nobody uses, drop them and log the migration info in both the log and README. If uncertain, mark the flag as experimental via TODO.
- **Potential errors**: treat untested scripts as fragile. Enable `set -euo pipefail` and add `trap` debugging when touching critical modules.
- **Prioritization**: tackle modules that unblock others first (`installation/commons`, `installation/system.sh`). Every refactor proposal must list impacted dependencies and a verification plan.

## Recommended verification flow

1. **Load context**: read `docs/progress.md`, confirm branch (`git status -sb`), `pwd`, and critical env vars. Log the entry.
2. **Pick a module**: mark its row as `In Progress`, record its scope (files, scripts, package lists).
3. **Inventory & patterns**: list functions, commands, and configs involved. Ensure they follow current patterns; refactor or note blocking TODOs.
4. **Compare vs legacy & dependencies**: use `git show origin/dev -- <path>` to confirm parity, review dependencies (packages, binaries), and log differences.
5. **Inline documentation**: add/update headers, variable glossaries, and flow comments per the rules.
6. **Checks**: run `bash -n`, `shellcheck`, simulations, or other relevant tests. Capture commands and outcomes, including limitations.
7. **Update log & risks**: describe changes, TODOs, and risks. If anything stays incomplete, label it explicitly.
8. **Prepare commit**: `git add` only the module files, inspect `git diff --cached`, ensure documentation is complete. Use messages like `feat(<module>): ...`.
9. **Close module**: mark the table row as `Done` (or leave `Pending` with notes), link the commit in the log, then move to the next unlocked module.
