#!/usr/bin/env bash
# Fast local syntax check across every shell file in the repo — no
# containers, runs in under a second. Use this while iterating; test/run.sh
# is the full integration test that actually executes install.sh.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

status=0

echo "==> bash -n (*.sh, *.bash)"
while IFS= read -r -d '' f; do
  if bash -n "$f" 2>&1; then
    echo "  OK   $f"
  else
    echo "  FAIL $f"
    status=1
  fi
done < <(find . -path ./.git -prune -o \( -name '*.sh' -o -name '*.bash' \) -print0)

if command -v zsh >/dev/null 2>&1; then
  echo "==> zsh -n (*.zsh)"
  while IFS= read -r -d '' f; do
    if zsh -n "$f" 2>&1; then
      echo "  OK   $f"
    else
      echo "  FAIL $f"
      status=1
    fi
  done < <(find . -path ./.git -prune -o -name '*.zsh' -print0)
else
  echo "==> zsh not installed locally — skipping zsh -n (test/run.sh still covers this inside containers)"
fi

exit $status
