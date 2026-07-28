#!/usr/bin/env bash
# Runtime smoke test. Static checks cannot prove that a kernel builds these
# topologies, so this actually runs every lab and reports a pass or fail table.
#
#   sudo ./tests/smoke.sh          run everything
#   sudo ./tests/smoke.sh act1     labs 01 to 05 only
#   sudo ./tests/smoke.sh capstone lab 06 only
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
act1="$root/scripts/mission-act1-labs.sh"
cap="$root/scripts/mission-layer2-capstone.sh"
scope="${1:-all}"
case "$scope" in
  all|act1|capstone) ;;
  *) printf 'Usage: sudo bash tests/smoke.sh [all|act1|capstone]\n' >&2; exit 2 ;;
esac
pass=0; failn=0; skipped=0; results=()

cleanup_all(){
  local lab
  for lab in lab01 lab02 lab03 lab04 lab05; do bash "$act1" "$lab" destroy >/dev/null 2>&1 || true; done
  bash "$cap" destroy >/dev/null 2>&1 || true
}
trap 'printf "\nInterrupted. Removing lab objects.\n"; cleanup_all; exit 130' INT TERM

leak_check(){
  local leaks
  leaks="$( { ip netns list 2>/dev/null | awk '{print $1}' | grep '^mls1' || true; ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | cut -d@ -f1 | grep '^mls1' || true; } )"
  if [[ -n "$leaks" ]]; then
    results+=("FAIL  cleanup left objects behind"); failn=$((failn+1))
    printf -- '----- leaked objects -----\n%s\n' "$leaks"
  else
    results+=("PASS  no mls1 objects left behind"); pass=$((pass+1))
  fi
}

[[ ${EUID:-$(id -u)} -eq 0 ]] || { printf 'Run with sudo.\n' >&2; exit 1; }

run(){
  local label="$1"; shift
  local out rc
  out="$("$@" 2>&1)"; rc=$?
  if (( rc == 0 )); then
    results+=("PASS  $label"); pass=$((pass+1)); return 0
  fi
  results+=("FAIL  $label"); failn=$((failn+1))
  printf -- '----- %s -----\n%s\n' "$label" "$(printf '%s\n' "$out" | tail -15)"
  return 1
}
skip(){ results+=("SKIP  $1"); skipped=$((skipped+1)); }

if [[ "$scope" == all || "$scope" == act1 ]]; then
  for lab in lab01 lab02 lab03 lab04 lab05; do
    if run "$lab build" bash "$act1" "$lab" build; then
      run "$lab verify" bash "$act1" "$lab" verify
      case "$lab" in
        lab01)
          run "$lab request" bash "$act1" "$lab" request
          run "$lab capture" bash "$act1" "$lab" capture
          ;;
        lab02)
          run "$lab inspect" bash "$act1" "$lab" inspect
          run "$lab capture" bash "$act1" "$lab" capture
          ;;
        lab03)
          run "$lab capture" bash "$act1" "$lab" capture
          run "$lab break" bash "$act1" "$lab" break
          run "$lab fix" bash "$act1" "$lab" fix
          run "$lab evidence" bash "$act1" "$lab" evidence
          ;;
        lab04)
          run "$lab broadcast" bash "$act1" "$lab" broadcast
          run "$lab unknown" bash "$act1" "$lab" unknown
          run "$lab capture" bash "$act1" "$lab" capture
          ;;
        lab05)
          run "$lab flush" bash "$act1" "$lab" flush
          run "$lab resolve" bash "$act1" "$lab" resolve
          run "$lab capture" bash "$act1" "$lab" capture
          ;;
      esac
    else
      skip "$lab documented commands"
    fi
    run "$lab destroy" bash "$act1" "$lab" destroy
  done
fi

if [[ "$scope" == all || "$scope" == capstone ]]; then
  if run "lab06 doctor" bash "$cap" doctor && run "lab06 build" bash "$cap" build; then
    run "lab06 verify" bash "$cap" verify
    run "lab06 topology" bash "$cap" topology
    for demo in port-roles vlan-boundaries fdb-learning unknown-unicast broadcast-domain; do
      run "lab06 demo $demo" bash "$cap" demo "$demo"
    done
    for demo in root-election trunk-pruning pvid-mismatch mac-move path-cost link-failover; do
      # A stateful demo that failed still needs fix, or every later demo is poisoned.
      run "lab06 demo $demo" bash "$cap" demo "$demo" || true
      run "lab06 fix after $demo" bash "$cap" fix
    done
    run "lab06 verify after all demos" bash "$cap" verify
    run "lab06 evidence" bash "$cap" evidence
  else
    for demo in port-roles vlan-boundaries fdb-learning unknown-unicast broadcast-domain \
                root-election trunk-pruning pvid-mismatch mac-move path-cost link-failover; do
      skip "lab06 demo $demo"
    done
    skip "lab06 verify"
  fi
  run "lab06 destroy" bash "$cap" destroy
fi

cleanup_all
leak_check

printf '\n===== smoke results =====\n'
printf '%s\n' "${results[@]}"
printf '=========================\npassed %d, failed %d, skipped %d\n' "$pass" "$failn" "$skipped"
(( failn == 0 && skipped == 0 ))
