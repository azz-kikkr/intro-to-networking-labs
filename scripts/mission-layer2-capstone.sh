#!/usr/bin/env bash
set -Eeuo pipefail

LAB="Mission Tech Lab 03"
STATE_DIR="/run/mls1-lab03"
SCENARIO_FILE="$STATE_DIR/scenario"
RESULTS_FILE="$STATE_DIR/results-dir"
LOG_DIR="$STATE_DIR/logs"

BR_CORE="mls1-g-core"
BR_EAST="mls1-g-east"
BR_WEST="mls1-g-west"
BR_EDGE="mls1-g-edge"
BRIDGES=("$BR_CORE" "$BR_EAST" "$BR_WEST" "$BR_EDGE")

NS_A="mls1-g-a"
NS_B="mls1-g-b"
NS_C="mls1-g-c"
NS_APP="mls1-g-app"
NAMESPACES=("$NS_A" "$NS_B" "$NS_C" "$NS_APP")

TRUNK_ROOTS=(mls1-g-cec mls1-g-cwc mls1-g-ewe mls1-g-wee)
ACCESS_ROOTS=(mls1-g-ap mls1-g-bp mls1-g-cp mls1-g-xp)
ALL_ROOT_LINKS=("${TRUNK_ROOTS[@]}" "${ACCESS_ROOTS[@]}")

C_RESET='\033[0m'; C_BOLD='\033[1m'; C_PURPLE='\033[38;5;141m'
C_GREEN='\033[38;5;114m'; C_ORANGE='\033[38;5;208m'; C_RED='\033[38;5;203m'
log(){ printf '%b[%s]%b %s\n' "$C_PURPLE" "$LAB" "$C_RESET" "$*"; }
ok(){ printf '%b[PASS]%b %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn(){ printf '%b[CHECK]%b %s\n' "$C_ORANGE" "$C_RESET" "$*"; }
fail(){ printf '%b[FAIL]%b %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
die(){ fail "$*"; exit 1; }
need_root(){ [[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run this command with sudo."; }
have(){ command -v "$1" >/dev/null 2>&1; }
exists(){ ip link show "$1" >/dev/null 2>&1; }
is_wsl2(){ grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null || grep -qi microsoft /proc/version 2>/dev/null; }

banner(){ cat <<'EOF'

MISSION TECH
LAB 03: THE LAYER 2 GRAND FINALE
Eleven open-source switching investigations on one bounded Linux campus fabric

EOF
}

usage(){ cat <<'EOF'
Usage:
  sudo ./mission-layer2-grand-finale.sh <command>

Start:
  install                  Install open-source dependencies
  doctor                   Validate WSL2, tools and bridge support
  build                    Create the four-switch campus fabric
  verify                   Prove the clean baseline
  topology                 Print the topology
  evidence                 Show the timestamped results directory

Grand finale investigations:
  demo root-election       Move the STP root from Core to West
  demo port-roles          Inspect forwarding and blocking port states
  demo vlan-boundaries     Prove VLAN 110 and VLAN 120 isolation
  demo fdb-learning        Flush, generate traffic and inspect MAC learning
  demo unknown-unicast     Capture a bounded unknown-unicast flood
  demo broadcast-domain    Prove broadcast stays inside VLAN 110
  demo trunk-pruning       Remove VLAN 110 from an active trunk
  demo pvid-mismatch       Put Host B's access port in the wrong VLAN
  demo mac-move            Move Host B to another switch port
  demo path-cost           Change STP cost and move the protected path
  demo link-failover       Cut an active trunk and observe recovery

Recovery:
  fix                      Repair the active stateful demonstration
  reset                    Rebuild the clean baseline
  destroy                  Remove every Lab 03 object and tracked PID
  help                     Show this help

The lab uses Linux kernel STP, not RSTP. Traffic is bounded and remains inside
mls1-prefixed network namespaces. No physical interface, WSL external link,
host route or host firewall is modified.
EOF
}

required=(ip bridge brctl tcpdump python3 ping timeout grep sed)
install_packages(){
  need_root; banner
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y iproute2 bridge-utils tcpdump python3 python3-scapy iputils-ping procps coreutils
  ok "Packages installed"
}

bridge_capability_test(){
  local t="mls1-g-test"
  ip link del "$t" >/dev/null 2>&1 || true
  ip link add "$t" type bridge >/dev/null 2>&1 || return 1
  ip link del "$t" >/dev/null 2>&1 || true
}

doctor(){
  need_root; banner
  local failed=0 cmd
  is_wsl2 && ok "WSL2 detected" || { fail "WSL2 was not detected"; failed=1; }
  [[ "$(readlink -f "$0")" != /mnt/* ]] && ok "Script runs from the Linux filesystem" || { fail "Move the script from /mnt/c into your Ubuntu home directory"; failed=1; }
  for cmd in "${required[@]}"; do have "$cmd" && ok "$cmd" || { fail "$cmd is missing"; failed=1; }; done
  python3 -c 'import scapy.all' >/dev/null 2>&1 && ok "Scapy" || { fail "Python Scapy is missing"; failed=1; }
  bridge_capability_test && ok "Linux bridge creation" || { fail "Cannot create a Linux bridge"; failed=1; }
  (( failed == 0 )) || die "Doctor checks failed"
  ok "Environment ready"
}

ensure_state(){ mkdir -p "$STATE_DIR" "$LOG_DIR"; chmod 700 "$STATE_DIR"; }
results_dir(){ [[ -f "$RESULTS_FILE" ]] && cat "$RESULTS_FILE" || true; }
create_results(){
  ensure_state
  local dir="$PWD/results/lab03-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$dir"
  printf '%s\n' "$dir" > "$RESULTS_FILE"
  if [[ -n ${SUDO_UID:-} && -n ${SUDO_GID:-} ]]; then chown -R "$SUDO_UID:$SUDO_GID" "$PWD/results" 2>/dev/null || true; fi
  printf '%s\n' "$dir"
}
evidence(){ need_root; local dir; dir="$(results_dir)"; [[ -n "$dir" ]] || die "Build the lab first."; printf '%s\n' "$dir"; find "$dir" -maxdepth 1 -type f -printf '  %f\n' | sort; }
record_output(){ local name="$1"; shift; local dir; dir="$(results_dir)"; [[ -n "$dir" ]] || die "Results directory is missing."; "$@" | tee "$dir/$name"; }

kill_pidfile(){
  local file="$1" pid
  [[ -f "$file" ]] || return 0
  pid="$(cat "$file" 2>/dev/null || true)"
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi
  rm -f "$file"
}

remove_vlan1(){ bridge vlan del dev "$1" vid 1 >/dev/null 2>&1 || true; }
set_bridge(){
  local br="$1" mac="$2" priority="$3"
  ip link add "$br" type bridge
  ip link set "$br" address "$mac"
  ip link set "$br" type bridge vlan_filtering 1 stp_state 1 priority "$priority" forward_delay 4 hello_time 1 max_age 6 ageing_time 120
  ip link set "$br" up
}
add_trunk(){
  local a="$1" b="$2" br_a="$3" br_b="$4"
  ip link add "$a" type veth peer name "$b"
  ip link set "$a" master "$br_a"; ip link set "$b" master "$br_b"
  ip link set "$a" up; ip link set "$b" up
  remove_vlan1 "$a"; remove_vlan1 "$b"
  bridge vlan add dev "$a" vid 110; bridge vlan add dev "$a" vid 120
  bridge vlan add dev "$b" vid 110; bridge vlan add dev "$b" vid 120
}
add_host(){
  local ns="$1" peer="$2" port="$3" br="$4" vid="$5" addr="$6" mac="$7"
  ip netns add "$ns"
  ip link add "$port" type veth peer name "$peer"
  ip link set "$peer" netns "$ns"; ip link set "$port" master "$br"; ip link set "$port" up
  remove_vlan1 "$port"; bridge vlan add dev "$port" vid "$vid" pvid untagged
  ip -n "$ns" link set lo up; ip -n "$ns" link set "$peer" name eth0
  ip -n "$ns" link set eth0 address "$mac"; ip -n "$ns" link set eth0 up
  ip -n "$ns" addr add "$addr" dev eth0
  ip netns exec "$ns" sysctl -qw net.ipv6.conf.all.disable_ipv6=1
}

restore_costs(){
  local port
  for port in mls1-g-cec mls1-g-cee mls1-g-cwc mls1-g-cww mls1-g-ewe mls1-g-eww mls1-g-wee mls1-g-wew; do
    exists "$port" && ip link set dev "$port" type bridge_slave cost 100 >/dev/null 2>&1 || true
  done
}
move_b(){
  local target="$1"
  bridge vlan del dev mls1-g-bp vid 110 >/dev/null 2>&1 || true
  ip link set mls1-g-bp nomaster
  ip link set mls1-g-bp master "$target"
  remove_vlan1 mls1-g-bp
  bridge vlan add dev mls1-g-bp vid 110 pvid untagged
  ip link set mls1-g-bp up
}
set_b_vlan(){
  local vid="$1"
  bridge vlan del dev mls1-g-bp vid 110 >/dev/null 2>&1 || true
  bridge vlan del dev mls1-g-bp vid 130 >/dev/null 2>&1 || true
  bridge vlan add dev mls1-g-bp vid "$vid" pvid untagged
}

start_app(){
  ensure_state
  ip netns exec "$NS_APP" python3 -m http.server 8080 --bind 10.120.0.50 >"$LOG_DIR/app.log" 2>&1 &
  printf '%s\n' "$!" > "$STATE_DIR/app.pid"
}

topology(){ cat <<'EOF'

                         mls1-g-core
                       /              \
              mls1-g-east -------- mls1-g-west
                  |                    |      \
           Host A VLAN 110      Host B 110   App 120
                                       |
                                 mls1-g-edge
                                       |
                                Host C VLAN 110

Core is the baseline STP root. Four tagged trunks form two redundant paths.
Host C is the witness for flooding. The application remains isolated in VLAN 120.
EOF
}

build(){
  need_root; banner; doctor >/dev/null || die "Doctor checks failed"
  destroy --quiet
  local dir; dir="$(create_results)"
  log "Creating four Linux switches"
  set_bridge "$BR_CORE" 02:00:00:00:30:01 4096
  set_bridge "$BR_EAST" 02:00:00:00:30:02 8192
  set_bridge "$BR_WEST" 02:00:00:00:30:03 12288
  set_bridge "$BR_EDGE" 02:00:00:00:30:04 16384
  log "Creating four VLAN-aware trunks"
  add_trunk mls1-g-cec mls1-g-cee "$BR_CORE" "$BR_EAST"
  add_trunk mls1-g-cwc mls1-g-cww "$BR_CORE" "$BR_WEST"
  add_trunk mls1-g-ewe mls1-g-eww "$BR_EAST" "$BR_WEST"
  add_trunk mls1-g-wee mls1-g-wew "$BR_WEST" "$BR_EDGE"
  log "Adding four isolated endpoints"
  add_host "$NS_A" mls1-g-ae mls1-g-ap "$BR_EAST" 110 10.110.3.11/24 02:00:00:00:31:0a
  add_host "$NS_B" mls1-g-be mls1-g-bp "$BR_WEST" 110 10.110.3.12/24 02:00:00:00:31:0b
  add_host "$NS_C" mls1-g-ce mls1-g-cp "$BR_EDGE" 110 10.110.3.13/24 02:00:00:00:31:0c
  add_host "$NS_APP" mls1-g-xe mls1-g-xp "$BR_WEST" 120 10.120.3.50/24 02:00:00:00:32:50
  start_app
  sleep 8
  rm -f "$SCENARIO_FILE"
  topology | tee "$dir/topology.txt"
  ok "Lab built"
  printf 'Evidence directory: %s\n' "$dir"
}

blocked_count(){ bridge link show | grep -E 'master mls1-g-(core|east|west|edge)' | grep -Ec 'state (blocking|disabled)' || true; }
scenario_active(){ [[ -s "$SCENARIO_FILE" ]]; }
require_clean(){ scenario_active && die "A demonstration is active. Run fix first." || true; }
record_scenario(){ ensure_state; printf '%s\n' "$1" > "$SCENARIO_FILE"; }

verify(){
  need_root; local br failed=0
  for br in "${BRIDGES[@]}"; do exists "$br" || die "Missing bridge: $br"; done
  require_clean
  (( $(blocked_count) >= 1 )) && ok "STP protects a redundant path" || { fail "No blocking port found"; failed=1; }
  ip netns exec "$NS_A" ping -c 2 -W 2 10.110.3.12 >/dev/null && ok "Host A reaches Host B in VLAN 110" || { fail "A to B failed"; failed=1; }
  ip netns exec "$NS_A" ping -c 2 -W 2 10.110.3.13 >/dev/null && ok "Host A reaches witness C in VLAN 110" || { fail "A to C failed"; failed=1; }
  if ip netns exec "$NS_A" ping -c 1 -W 1 10.120.3.50 >/dev/null 2>&1; then fail "VLAN isolation failed"; failed=1; else ok "VLAN 110 remains isolated from VLAN 120"; fi
  bridge vlan show dev mls1-g-bp | grep -Eq '110.*PVID.*Egress Untagged|110 PVID Egress Untagged' && ok "Host B access VLAN is 110" || { fail "Host B PVID is wrong"; failed=1; }
  (( failed == 0 )) || return 1
  ok "Grand finale baseline verified"
}

show_stp(){ bridge link show | grep -E 'master mls1-g-(core|east|west|edge)' || true; }
show_roots(){ for br in "${BRIDGES[@]}"; do printf '\n--- %s ---\n' "$br"; brctl showstp "$br" | sed -n '1,12p'; done; }

demo_root(){
  need_root; require_clean; record_scenario root-election
  local dir; dir="$(results_dir)"
  log "Lowering West priority so it wins root election"
  ip link set "$BR_WEST" type bridge priority 0
  sleep 8
  show_roots | tee "$dir/01-root-election.txt"
  warn "West is now root. Run fix to restore Core."
}
demo_roles(){ need_root; require_clean; record_output 02-port-roles.txt show_stp; ok "Forwarding and blocking states recorded"; }
demo_vlans(){
  need_root; require_clean; local dir; dir="$(results_dir)"
  { bridge vlan show; printf '\nA to B:\n'; ip netns exec "$NS_A" ping -c 2 -W 2 10.110.3.12; printf '\nA to App, expected to fail:\n'; ip netns exec "$NS_A" ping -c 1 -W 1 10.120.3.50 || true; } | tee "$dir/03-vlan-boundaries.txt"
  ok "VLAN boundary evidence recorded"
}
demo_fdb(){
  need_root; require_clean; local br dir; dir="$(results_dir)"
  for br in "${BRIDGES[@]}"; do bridge fdb flush br "$br" >/dev/null 2>&1 || true; done
  ip netns exec "$NS_A" ping -c 2 -W 2 10.110.3.12 >/dev/null
  { for br in "${BRIDGES[@]}"; do printf '\n--- %s ---\n' "$br"; bridge fdb show br "$br" | grep -vE 'permanent|self' || true; done; } | tee "$dir/04-fdb-learning.txt"
  ok "Dynamic source-MAC learning recorded"
}
scapy_send(){
  local ns="$1" dst="$2" payload="$3"
  ip netns exec "$ns" python3 - "$dst" "$payload" <<'PY'
import sys
from scapy.all import Ether, Raw, sendp
sendp(Ether(dst=sys.argv[1])/Raw(load=sys.argv[2].encode()), iface="eth0", count=1, verbose=False)
PY
}
demo_unknown(){
  need_root; require_clean; local dir pid; dir="$(results_dir)"
  : > "$dir/05-unknown-unicast.txt"
  ip netns exec "$NS_C" timeout 5 tcpdump -nn -e -l -c 1 -i eth0 'ether dst 02:00:00:de:ad:03' >"$dir/05-unknown-unicast.txt" 2>&1 & pid=$!
  printf '%s\n' "$pid" > "$STATE_DIR/capture.pid"; sleep 1
  scapy_send "$NS_A" 02:00:00:de:ad:03 MISSION-UNKNOWN
  wait "$pid" || true; rm -f "$STATE_DIR/capture.pid"
  grep -q '02:00:00:de:ad:03' "$dir/05-unknown-unicast.txt" || die "Witness C did not capture the unknown unicast"
  cat "$dir/05-unknown-unicast.txt"; ok "Unknown unicast flooded to witness C"
}
demo_broadcast(){
  need_root; require_clean; local dir pid_c pid_app; dir="$(results_dir)"
  : > "$dir/06-broadcast-vlan110.txt"; : > "$dir/06-broadcast-vlan120.txt"
  ip netns exec "$NS_C" timeout 5 tcpdump -nn -e -l -c 1 -i eth0 ether broadcast >"$dir/06-broadcast-vlan110.txt" 2>&1 & pid_c=$!
  ip netns exec "$NS_APP" timeout 5 tcpdump -nn -e -l -c 1 -i eth0 ether broadcast >"$dir/06-broadcast-vlan120.txt" 2>&1 & pid_app=$!
  printf '%s\n' "$pid_c" > "$STATE_DIR/capture-c.pid"; printf '%s\n' "$pid_app" > "$STATE_DIR/capture-app.pid"; sleep 1
  scapy_send "$NS_A" ff:ff:ff:ff:ff:ff MISSION-BROADCAST
  wait "$pid_c" || true; wait "$pid_app" || true
  rm -f "$STATE_DIR/capture-c.pid" "$STATE_DIR/capture-app.pid"
  grep -q 'MISSION-BROADCAST' "$dir/06-broadcast-vlan110.txt" || die "VLAN 110 witness missed the broadcast"
  if grep -q 'MISSION-BROADCAST' "$dir/06-broadcast-vlan120.txt"; then die "Broadcast leaked into VLAN 120"; fi
  cat "$dir/06-broadcast-vlan110.txt"; ok "Broadcast reached VLAN 110 witness and did not cross into VLAN 120"
}
demo_pruning(){
  need_root; require_clean; record_scenario trunk-pruning
  local dir; dir="$(results_dir)"
  bridge vlan del dev mls1-g-cww vid 110
  { bridge vlan show dev mls1-g-cww; ip netns exec "$NS_A" ping -c 2 -W 1 10.110.3.12 || true; } | tee "$dir/07-trunk-pruning.txt"
  warn "VLAN 110 is pruned from an active West trunk. Run fix."
}
demo_pvid(){
  need_root; require_clean; record_scenario pvid-mismatch
  local dir; dir="$(results_dir)"
  set_b_vlan 130
  { bridge vlan show dev mls1-g-bp; ip netns exec "$NS_A" ping -c 2 -W 1 10.110.3.12 || true; } | tee "$dir/08-pvid-mismatch.txt"
  warn "Host B is in the wrong access VLAN. Run fix."
}
demo_mac_move(){
  need_root; require_clean; record_scenario mac-move
  local dir; dir="$(results_dir)"
  move_b "$BR_EAST"; ip netns exec "$NS_B" ping -c 2 -W 2 10.110.3.11 >/dev/null || true
  { ip -br link show mls1-g-bp; bridge fdb show br "$BR_EAST" | grep '02:00:00:00:31:0b' || true; } | tee "$dir/09-mac-move.txt"
  warn "Host B moved without changing MAC or IP. Run fix."
}
demo_cost(){
  need_root; require_clean; record_scenario path-cost
  local dir; dir="$(results_dir)"
  log "Making the East-West path expensive"
  ip link set dev mls1-g-ewe type bridge_slave cost 500
  ip link set dev mls1-g-eww type bridge_slave cost 500
  sleep 8
  show_stp | tee "$dir/10-path-cost.txt"
  warn "STP recalculated with new costs. Run fix."
}
demo_failover(){
  need_root; require_clean; record_scenario link-failover
  local dir; dir="$(results_dir)"
  ip netns exec "$NS_A" ping -D -i 0.5 -w 30 10.110.3.12 >"$dir/11-link-failover-ping.txt" 2>&1 &
  printf '%s\n' "$!" > "$STATE_DIR/ping.pid"; sleep 2
  ip link set mls1-g-cwc down; sleep 8
  show_stp | tee "$dir/11-link-failover-stp.txt"
  warn "Core-West is down and the alternate path should forward. Run fix."
}

fix(){
  need_root; local scenario; scenario="$(cat "$SCENARIO_FILE" 2>/dev/null || true)"
  case "$scenario" in
    root-election) ip link set "$BR_WEST" type bridge priority 12288 ;;
    trunk-pruning) bridge vlan add dev mls1-g-cww vid 110 ;;
    pvid-mismatch) set_b_vlan 110 ;;
    mac-move) move_b "$BR_WEST" ;;
    path-cost) restore_costs ;;
    link-failover) ip link set mls1-g-cwc up; kill_pidfile "$STATE_DIR/ping.pid" ;;
    '') warn "No active demonstration. Applying baseline repairs." ;;
    *) warn "Unknown demonstration state: $scenario" ;;
  esac
  exists "$BR_CORE" && {
    ip link set mls1-g-cwc up >/dev/null 2>&1 || true
    bridge vlan add dev mls1-g-cww vid 110 >/dev/null 2>&1 || true
    ip link set "$BR_WEST" type bridge priority 12288 >/dev/null 2>&1 || true
    set_b_vlan 110 >/dev/null 2>&1 || true
    move_b "$BR_WEST" >/dev/null 2>&1 || true
    restore_costs
  }
  kill_pidfile "$STATE_DIR/ping.pid"; kill_pidfile "$STATE_DIR/capture.pid"
  kill_pidfile "$STATE_DIR/capture-c.pid"; kill_pidfile "$STATE_DIR/capture-app.pid"
  rm -f "$SCENARIO_FILE"; sleep 8; ok "Baseline restored"
}

destroy(){
  need_root; local quiet="${1:-}" ns link br
  [[ "$quiet" == --quiet ]] || log "Removing Lab 03"
  for file in app.pid ping.pid capture.pid capture-c.pid capture-app.pid; do kill_pidfile "$STATE_DIR/$file"; done
  for ns in "${NAMESPACES[@]}"; do ip netns del "$ns" >/dev/null 2>&1 || true; done
  for link in "${ALL_ROOT_LINKS[@]}"; do ip link del "$link" >/dev/null 2>&1 || true; done
  for br in "${BRIDGES[@]}"; do ip link del "$br" >/dev/null 2>&1 || true; done
  rm -rf "$STATE_DIR"
  [[ "$quiet" == --quiet ]] || ok "All Lab 03 objects removed. Evidence remains under results/."
}
reset(){ need_root; destroy --quiet; build; }

main(){
  case "${1:-help}" in
    install) install_packages ;; doctor) doctor ;; build) build ;; verify) verify ;; topology) topology ;; evidence) evidence ;;
    demo) case "${2:-}" in
      root-election) demo_root ;; port-roles) demo_roles ;; vlan-boundaries) demo_vlans ;; fdb-learning) demo_fdb ;;
      unknown-unicast) demo_unknown ;; broadcast-domain) demo_broadcast ;; trunk-pruning) demo_pruning ;;
      pvid-mismatch) demo_pvid ;; mac-move) demo_mac_move ;; path-cost) demo_cost ;; link-failover) demo_failover ;;
      *) die "Unknown demo. Run help for the eleven names." ;; esac ;;
    fix) fix ;; reset) reset ;; destroy) destroy ;; help|-h|--help) usage ;; *) usage; exit 1 ;;
  esac
}
main "$@"