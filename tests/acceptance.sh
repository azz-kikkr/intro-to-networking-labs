#!/usr/bin/env bash
set -Eeuo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail(){ printf '[FAIL] %s\n' "$*" >&2; exit 1; }

for script in "$root"/scripts/*.sh; do
  bash -n "$script"
  grep -q 'set -Eeuo pipefail' "$script" || fail "$script lacks strict mode"
  grep -q 'mls1' "$script" || fail "$script lacks scoped resource names"
  grep -q 'results' "$script" || fail "$script lacks evidence output"
done

# Match invoked commands, not any mention of a word. The old pattern flagged
# read-only /proc paths and prose that merely named the host packet filter.
if grep -R -nE '(^|[[:space:];&|(])(pkill|killall|ip6?tables|nft)[[:space:]]|ip route (add|del|replace) default' "$root/scripts"; then
  fail 'Unsafe host-wide operation found'
fi
# Byte literal, so the check does not depend on the shell locale, and skip
# tests/ so the guard cannot match its own source.
em_dash="$(printf '\342\200\224')"
if grep -R -n --include='*.md' --include='*.sh' --exclude-dir=tests -e "$em_dash" "$root"; then
  fail 'Em dash found in user-facing content'
fi
[[ $(find "$root/docs" -maxdepth 1 -name 'lab-*.md' | wc -l) -eq 7 ]] || fail 'Expected seven lab guides (six Act 1 + one Act 2)'
for lab in 01 02 03 04 05 06; do
  grep -qi 'predict' "$root/docs/lab-$lab"-*.md || fail "Lab $lab lacks a prediction prompt"
done
grep -qi 'predict' "$root/docs/lab-07-first-ebgp-session.md" || fail "Lab 07 lacks a prediction prompt"
release_version="$(cat "$root/VERSION")"
[[ "$("$root/scripts/mission-act1-labs.sh" --version)" == "$release_version" ]] || fail 'Act 1 runner version does not match VERSION'
[[ "$("$root/scripts/mission-layer2-capstone.sh" --version)" == "$release_version" ]] || fail 'Capstone runner version does not match VERSION'
# Bridge timers must be expressed in hundredths of a second.
grep -q 'forward_delay 400' "$root/scripts/mission-layer2-capstone.sh" || fail 'Capstone bridge timers are not in centiseconds'
grep -q 'brctl' "$root/scripts/mission-layer2-capstone.sh" && fail 'Capstone still depends on deprecated bridge-utils'
printf '[PASS] Static acceptance contract\n'