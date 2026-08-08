#!/usr/bin/env bash
set -Eeuo pipefail

# Act 2 BGP smoke test: requires Docker.
# Starts lab01, verifies BGP sessions, collects evidence, then destroys.

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
runner="$root/scripts/mission-act2-bgp.sh"
fail(){ printf '[FAIL] %s\n' "$*" >&2; exit 1; }
ok(){ printf '[PASS] %s\n' "$*"; }
cleanup(){ "$runner" destroy lab01 >/dev/null 2>&1 || true; }

# Always clean up on exit
trap cleanup EXIT

# Doctor check
"$runner" doctor || fail "Doctor check failed"
ok "Doctor passed"

# Prep (pull image if not cached)
"$runner" prep || fail "Prep (image pull) failed"
ok "FRR image ready"

# Build lab01
"$runner" build lab01 || fail "Build lab01 failed"
ok "Lab01 built and BGP converged"

# Verify lab01
output="$("$runner" verify lab01)" || fail "Verify lab01 failed"
echo "$output"
echo "$output" | grep -q '6/6 checks passed' || fail "Not all checks passed"
ok "All 6 checks passed"

# Evidence collection
"$runner" evidence lab01 || fail "Evidence collection failed"
# Find the most recent results directory
latest="$(find "$root/results" -maxdepth 1 -type d -name '*act2-lab01*' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)" || true
[[ -d "$latest" ]] || fail "No results directory created"
[[ -f "$latest/manifest.txt" ]] || fail "No manifest.txt in evidence"
[[ -f "$latest/r1-bgp-summary.txt" ]] || fail "No r1-bgp-summary.txt in evidence"
[[ -f "$latest/r2-bgp-table.txt" ]] || fail "No r2-bgp-table.txt in evidence"
[[ -s "$latest/r1-bgp-summary.txt" ]] || fail "r1-bgp-summary.txt is empty"
ok "Evidence collected with manifest"

# Verify evidence content
grep -q 'Established' "$latest/r1-bgp-summary.txt" 2>/dev/null || \
  grep -q 'pfxRcd' "$latest/r1-bgp-summary.txt" 2>/dev/null || \
  grep -q '10.1.12.2' "$latest/r1-bgp-summary.txt" 2>/dev/null || \
  fail "r1 BGP summary does not contain expected peer information"
ok "Evidence contains valid BGP state"

# Destroy
"$runner" destroy lab01 || fail "Destroy lab01 failed"
ok "Lab01 destroyed cleanly"

# Confirm containers are gone
if docker ps --format '{{.Names}}' | grep -q 'mls1-bgp-lab01'; then
  fail "mls1-bgp-lab01 containers still running after destroy"
fi
ok "No mls1-bgp containers remain"

printf '\n[PASS] Act 2 BGP smoke test complete: failed 0, skipped 0\n'
