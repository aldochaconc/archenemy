#!/bin/bash
# archenemy post-installation prompt injected into /etc/profile.d
# shellcheck disable=SC2016

if [ ! -t 1 ] || [ -n "${ARCHENEMY_POST_PROMPT_SHOWN:-}" ]; then
  return
fi
ARCHENEMY_POST_PROMPT_SHOWN=1
SENTINEL="{{SENTINEL_PATH}}"
BOOT_SH="{{BOOT_PATH}}"

if [ ! -f "$SENTINEL" ]; then
  return
fi

cat <<'MSG'

============================================================
Archenemy phase 1 detected. Continue with post-install setup?
This will resume installation/boot.sh in post-install mode.
You may want to sync the repo first:
  cd ~/.config/archenemy && git pull
============================================================

MSG

read -r -p "Continue now? [Y/n] " answer
case "$answer" in
  n|N) echo "You can rerun later with: $BOOT_SH"; return ;;
esac

"$BOOT_SH"
status=$?
if [ $status -eq 0 ]; then
  rm -f "$SENTINEL"
else
  echo "Phase 2 failed (exit $status). See /var/log/archenemy-install.log"
fi
