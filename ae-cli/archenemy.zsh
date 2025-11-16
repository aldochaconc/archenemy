#!/usr/bin/env zsh
#
# Archenemy ZSH Integration
# Adds ae CLI to PATH and provides shell function wrapper

# Add Archenemy CLI to PATH if not already there
ARCHENEMY_CLI_DIR="${HOME}/.config/archenemy/ae-cli"
if [[ -d "$ARCHENEMY_CLI_DIR" ]] && [[ ":$PATH:" != *":$ARCHENEMY_CLI_DIR:"* ]]; then
  export PATH="$ARCHENEMY_CLI_DIR:$PATH"
fi

# Shell function wrapper (optional, for convenience)
ae() {
  command ae "$@"
}
