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

if grep -R -nE 'pkill|killall|ip route (add|del|replace) default|iptables|nft (add|delete|flush)' "$root/scripts"; then
  fail 'Unsafe host-wide operation found'
fi
if grep -R -n $'\u2014' "$root" --include='*.md' --include='*.sh'; then
  fail 'Em dash found in user-facing content'
fi
[[ $(find "$root/docs" -maxdepth 1 -name 'lab-*.md' | wc -l) -eq 6 ]] || fail 'Expected six Act 1 lab guides'
for lab in 01 02 03 04 05 06; do
  grep -qi 'predict' "$root/docs/lab-$lab"-*.md || fail "Lab $lab lacks a prediction prompt"
done
"$root/scripts/mission-act1-labs.sh" --version | grep -qx '1.0.0'
"$root/scripts/mission-layer2-capstone.sh" --version | grep -qx '1.0.0'
printf '[PASS] Static acceptance contract\n'