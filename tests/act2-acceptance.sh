#!/usr/bin/env bash
set -Eeuo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail(){ printf '[FAIL] %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Static checks for Act 2 BGP script
# ---------------------------------------------------------------------------

script="$root/scripts/mission-act2-bgp.sh"

# Syntax check
bash -n "$script" || fail "$script has syntax errors"

# Strict mode
grep -q 'set -Eeuo pipefail' "$script" || fail "$script lacks strict mode"

# mls1 prefix convention
grep -q 'mls1' "$script" || fail "$script lacks mls1-prefixed resource names"

# Evidence output reference
grep -q 'results' "$script" || fail "$script lacks evidence output (results/ reference)"

# No unsafe host-wide operations
if grep -nE '(^|[[:space:];&|(])(pkill|killall|ip6?tables|nft)[[:space:]]' "$script"; then
  fail 'Unsafe host-wide operation found in Act 2 script'
fi

# No em dashes in user-facing content
em_dash="$(printf '\342\200\224')"
if grep -rn "$em_dash" "$root/scripts/mission-act2-bgp.sh" "$root/docs/lab-07-first-ebgp-session.md" "$root/labs/act2-bgp/" 2>/dev/null; then
  fail 'Em dash found in Act 2 user-facing content'
fi

# Version consistency (tr -d '\r' handles Windows line endings on WSL2 mounts)
release_version="$(tr -d '\r' < "$root/VERSION" | tr -d '\n')"
script_version="$("$script" --version | tr -d '\r' | tr -d '\n')"
[[ "$script_version" == "$release_version" ]] || fail "Act 2 runner version ($script_version) does not match VERSION file ($release_version)"

# Lab structure checks
[[ -d "$root/labs/act2-bgp/lab01" ]] || fail "labs/act2-bgp/lab01 directory missing"
[[ -f "$root/labs/act2-bgp/lab01/docker-compose.yml" ]] || fail "lab01 docker-compose.yml missing"
[[ -f "$root/labs/act2-bgp/lab01/checks.json" ]] || fail "lab01 checks.json missing"
[[ -f "$root/labs/act2-bgp/lab01/r1/frr.conf" ]] || fail "lab01 r1/frr.conf missing"
[[ -f "$root/labs/act2-bgp/lab01/r2/frr.conf" ]] || fail "lab01 r2/frr.conf missing"
[[ -f "$root/labs/act2-bgp/lab01/r1/daemons" ]] || fail "lab01 r1/daemons missing"
[[ -f "$root/labs/act2-bgp/lab01/r2/daemons" ]] || fail "lab01 r2/daemons missing"

# Docker Compose project name enforces mls1 prefix (checked in the runner script)
grep -q 'PREFIX="mls1-bgp"' "$root/scripts/mission-act2-bgp.sh" || fail "Runner script lacks mls1-bgp project prefix"

# checks.json must be valid JSON structure (basic bracket check)
local_checks="$root/labs/act2-bgp/lab01/checks.json"
[[ "$(head -c1 "$local_checks")" == "[" ]] || fail "checks.json does not start with ["
grep -q '"type"' "$local_checks" || fail "checks.json lacks type fields"
grep -q '"description"' "$local_checks" || fail "checks.json lacks description fields"

# Lab guide must exist and have a predict section
[[ -f "$root/docs/lab-07-first-ebgp-session.md" ]] || fail "Lab 07 guide missing"
grep -qi 'predict' "$root/docs/lab-07-first-ebgp-session.md" || fail "Lab 07 guide lacks a prediction prompt"

# FRR configs must reference the correct AS numbers and peer IPs
grep -q '65001' "$root/labs/act2-bgp/lab01/r1/frr.conf" || fail "r1 frr.conf missing AS 65001"
grep -q '65002' "$root/labs/act2-bgp/lab01/r2/frr.conf" || fail "r2 frr.conf missing AS 65002"
grep -q '10.1.12.3' "$root/labs/act2-bgp/lab01/r1/frr.conf" || fail "r1 frr.conf missing peer IP 10.1.12.3"
grep -q '10.1.12.2' "$root/labs/act2-bgp/lab01/r2/frr.conf" || fail "r2 frr.conf missing peer IP 10.1.12.2"

printf '[PASS] Act 2 BGP static acceptance contract\n'
