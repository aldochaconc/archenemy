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
This will run ARCHENEMY_PHASE=postinstall installation/boot.sh
============================================================

MSG

read -r -p "Continue now? [Y/n] " answer
case "$answer" in
  n|N) echo "You can rerun later with: ARCHENEMY_PHASE=postinstall $BOOT_SH"; return ;;
esac

ARCHENEMY_PHASE=postinstall "$BOOT_SH"
status=$?
if [ $status -eq 0 ]; then
  rm -f "$SENTINEL"
else
  echo "Phase 2 failed (exit $status). See /var/log/archenemy-install.log"
fi
