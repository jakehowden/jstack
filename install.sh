#!/usr/bin/env bash
set -e
DEST="$HOME/Documents/Github/jstack"
if [ -d "$DEST/.git" ]; then
  git -C "$DEST" pull
else
  mkdir -p "$(dirname "$DEST")"
  git clone git@github.com:jakehowden/jstack.git "$DEST"
fi
"$DEST/setup"
