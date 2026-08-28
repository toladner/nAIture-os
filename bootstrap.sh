#!/usr/bin/env bash
# One-command install of the naiture theme.
#
#   curl -fsSL https://raw.githubusercontent.com/toladner/nAIture-os/main/bootstrap.sh | bash
#   curl -fsSL .../bootstrap.sh | bash -s -- --islands
#
# Clones (or updates) the repo under ~/.local/share and runs install.sh with
# whatever flags you pass through. Needs no root.
set -euo pipefail

REPO_URL="${NAITURE_REPO:-https://github.com/toladner/nAIture-os.git}"
DEST="${NAITURE_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/nAIture-os}"
BRANCH="${NAITURE_BRANCH:-main}"

say()  { printf '\033[38;2;106;191;217m::\033[0m %s\n' "$*"; }
die()  { printf '\033[38;2;242;113;106m!!\033[0m %s\n' "$*" >&2; exit 1; }

command -v git >/dev/null 2>&1 || die "git is required. Install it, then re-run."

if [[ -d "$DEST/.git" ]]; then
  say "updating $DEST"
  git -C "$DEST" fetch --quiet origin "$BRANCH"
  git -C "$DEST" checkout --quiet "$BRANCH"
  git -C "$DEST" reset --hard --quiet "origin/$BRANCH"
else
  say "cloning into $DEST"
  mkdir -p "$(dirname "$DEST")"
  git clone --quiet --depth 1 --branch "$BRANCH" "$REPO_URL" "$DEST"
fi

cd "$DEST"
say "checking prerequisites"
./scripts/preflight.sh || die "prerequisites missing — see above"

say "installing"
./install.sh "$@"

say "verifying"
./verify.sh
