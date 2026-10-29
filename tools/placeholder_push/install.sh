#!/bin/sh
# Installs the pre-push hook that swaps art for placeholder textures on GitHub pushes.
set -e
root=$(git rev-parse --show-toplevel)
hooks=$(git rev-parse --git-path hooks)
mkdir -p "$hooks"
if [ -e "$hooks/pre-push" ] && ! grep -q placeholder_push "$hooks/pre-push"; then
    echo "An unrelated pre-push hook already exists at $hooks/pre-push; not overwriting." >&2
    exit 1
fi
ln -sf "$root/tools/placeholder_push/pre-push" "$hooks/pre-push"
chmod +x "$root/tools/placeholder_push/pre-push" "$root/tools/placeholder_push/placeholder_push.py"
echo "Installed pre-push hook -> $hooks/pre-push"
