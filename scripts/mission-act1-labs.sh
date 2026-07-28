#!/usr/bin/env bash
set -Eeuo pipefail

LAB_SUITE="Mission Tech Act 1 Labs"
VERSION="1.1.4"
STATE_ROOT="/run/mls1-act1"
RESULTS_ROOT="${PWD}/results"
CAPTURE_PID=""

log(){ printf '[%s] %s\n' "$LAB_SUITE" "$*"; }
ok(){ printf '[PASS] %s\n' "$*"; }
die(){ printf '[FAIL] %s\n' "$*" >&2; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }
need_root(){ [[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run this command with sudo."; }
exists_ns(){ ip netns list | awk '{print $1}' | grep -Fxq "$1"; }
exists_link(){ ip link show "$1" >/dev/null 2>&1; }

usage(){ cat <<'EOF'
Usage:
  sudo ./mission-act1-labs.sh <lab01|lab02|lab03|lab04|lab05> <command>

Common commands:
  install    Install the open-source packet tools
  doctor     Check required tools and namespace support
  build      Create only the selected lab topology
  verify     Prove the baseline with kernel evidence
  capture    Generate bounded traffic and save a timestamped PCAP
  evidence   Save readable kernel and packet summaries
  destroy    Remove only the selected lab resources

Lab-specific commands:
  lab01 request             Make the isolated HTTP request
  lab02 inspect             Show address and IPv4 header evidence
  lab03 break|fix           Remove or restore the route
  lab04 broadcast|unknown   Generate Layer 2 frames
  lab05 flush|resolve       Clear and rebuild the ARP entry
EOF
}

install_packages(){
  need_root
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y iproute2 iputils-ping tcpdump curl python3 traceroute
  ok "Packages installed"
}

doctor(){
  need_root
  local failed=0 tool test_ns="mls1-doctor"
  for tool in ip bridge tcpdump curl python3 timeout awk grep date sha256sum sysctl; do
    if have "$tool"; then ok "$tool"; else printf '[FAIL] Missing %s\n' "$tool" >&2; failed=1; fi
  done
  ip netns del "$test_ns" >/dev/null 2>&1 || true
  if ip netns add "$test_ns" >/dev/null 2>&1; then
    ip netns del "$test_ns"
    ok "Network namespace creation"
  else
    printf '[FAIL] Cannot create a network namespace\n' >&2
    failed=1
  fi
  local test_bridge="mls1-doctor-br"
  ip link del "$test_bridge" >/dev/null 2>&1 || true
  if ip link add "$test_bridge" type bridge >/dev/null 2>&1; then
    ip link del "$test_bridge"
    ok "Linux bridge creation"
  else
    printf '[FAIL] Cannot create a Linux bridge\n' >&2
    failed=1
  fi
  local nf
  for nf in /proc/sys/net/bridge/bridge-nf-call-iptables /proc/sys/net/bridge/bridge-nf-call-ip6tables; do
    [[ -r "$nf" ]] || continue
    if [[ "$(cat "$nf")" == "1" ]]; then
      printf '[CHECK] br_netfilter sends bridged traffic to iptables. A Docker FORWARD DROP policy can silently drop lab frames.\n'
      break
    fi
  done
  (( failed == 0 )) || die "Environment check failed."
  ok "Environment ready"
}

new_result(){
  local lab="$1" stamp
  stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
  RESULT_DIR="${RESULTS_ROOT}/${stamp}-${lab}"
  mkdir -p "$RESULT_DIR"
  chmod 755 "$RESULT_DIR"
  printf '%s\n' "$RESULT_DIR"
}

finish_result(){
  local dir="$1" lab="$2" pcap
  {
    printf 'lab=%s\n' "$lab"
    printf 'generated_utc=%s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    printf 'runner_version=%s\n' "$VERSION"
    for pcap in "$dir"/*.pcap; do
      [[ -f "$pcap" ]] || continue
      [[ -s "$pcap" ]] || die "Empty PCAP: $pcap"
      tcpdump -nn -r "$pcap" -c 1 >/dev/null 2>&1 || die "Unreadable PCAP: $pcap"
      sha256sum "$pcap"
    done
  } >"$dir/manifest.txt"
  if [[ -n ${SUDO_UID:-} && -n ${SUDO_GID:-} ]]; then
    chown -R "$SUDO_UID:$SUDO_GID" "$dir"
  fi
  chmod -R u+rwX,go+rX "$dir"
}

kill_tracked(){
  local file="$1" pid
  [[ -f "$file" ]] || return 0
  pid="$(cat "$file" 2>/dev/null || true)"
  if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  fi
  rm -f "$file"
}

bridge_ports(){ bridge link show | awk -v br="$1" '$0 ~ ("master " br " ") {sub(/@.*/,"",$2); sub(/:$/,"",$2); print $2}'; }
# "bridge fdb flush br BR" is rejected by the parser and bare "dev PORT" returns
# Operation not supported. "dev PORT master" is the form that works.
fdb_flush_bridge(){
  local br="$1" port failed=0
  while IFS= read -r port; do
    [[ -n "$port" ]] || continue
    # Modern path. "br BR" is rejected by the parser and bare "dev PORT"
    # defaults to self, which a bridge port does not implement.
    if bridge fdb flush dev "$port" master dynamic >/dev/null 2>&1; then continue; fi
    # iproute2 before 5.19 has no flush verb at all. This bridge_slave flag is
    # much older and clears every dynamic entry on the port in all VLANs.
    ip link set dev "$port" type bridge_slave fdb_flush >/dev/null 2>&1 || failed=1
  done < <(bridge_ports "$br")
  (( failed == 0 )) || die "Could not flush dynamic FDB entries on $br"
  if bridge fdb show br "$br" dynamic 2>/dev/null | grep -q .; then
    die "Dynamic FDB entries remain on $br after flush"
  fi
}
# Do not race tcpdump with a fixed sleep. Wait until it says it is listening.
wait_capture(){
  local logfile="$1" attempts=50
  while (( attempts > 0 )); do
    grep -q 'listening on' "$logfile" 2>/dev/null && return 0
    attempts=$((attempts-1)); sleep 0.2
  done
  die "tcpdump did not start listening: $logfile"
}
assert_in_pcap(){ grep -aq "$2" "$1" || die "$3"; }

wait_http(){
  local ns="$1" url="$2" attempts=20
  while (( attempts > 0 )); do
    if ip netns exec "$ns" curl -fsS --max-time 1 "$url" >/dev/null 2>&1; then return 0; fi
    attempts=$((attempts-1)); sleep 0.2
  done
  die "HTTP service did not become ready."
}

add_bridge_host(){
  local ns="$1" host_if="$2" bridge_if="$3" bridge="$4" address="$5" mac="$6"
  ip netns add "$ns"
  ip link add "$host_if" type veth peer name "$bridge_if"
  ip link set "$host_if" netns "$ns"
  ip link set "$bridge_if" master "$bridge"
  ip link set "$bridge_if" up
  ip -n "$ns" link set lo up
  ip -n "$ns" link set "$host_if" name eth0
  ip -n "$ns" link set eth0 address "$mac"
  ip -n "$ns" link set eth0 up
  ip -n "$ns" address add "$address" dev eth0
  ip netns exec "$ns" sysctl -qw net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1 || true
}

cleanup_lab01(){
  kill_tracked "$STATE_ROOT/lab01/server.pid"
  ip netns del mls1-l01-client >/dev/null 2>&1 || true
  ip netns del mls1-l01-server >/dev/null 2>&1 || true
  ip link del mls1-l01-br >/dev/null 2>&1 || true
  rm -rf "$STATE_ROOT/lab01"
}
build_lab01(){
  doctor >/dev/null
  cleanup_lab01
  mkdir -p "$STATE_ROOT/lab01/www"
  printf '%s\n' '<!doctype html><title>Packet proof</title><h1>The browser asked. The server answered.</h1>' >"$STATE_ROOT/lab01/www/index.html"
  ip link add mls1-l01-br type bridge; ip link set mls1-l01-br up
  add_bridge_host mls1-l01-client mls1-l01-c mls1-l01-cb mls1-l01-br 10.1.1.10/24 02:00:00:01:01:10
  add_bridge_host mls1-l01-server mls1-l01-s mls1-l01-sb mls1-l01-br 10.1.1.20/24 02:00:00:01:01:20
  ip netns exec mls1-l01-server python3 -m http.server 8080 --bind 10.1.1.20 --directory "$STATE_ROOT/lab01/www" >"$STATE_ROOT/lab01/server.log" 2>&1 &
  echo $! >"$STATE_ROOT/lab01/server.pid"
  wait_http mls1-l01-client http://10.1.1.20:8080/
  ok "Isolated browser-to-server analogue is ready"
}
request_lab01(){ ip netns exec mls1-l01-client curl -sS -D - --max-time 3 http://10.1.1.20:8080/; }
verify_lab01(){
  exists_ns mls1-l01-client || die "Run lab01 build first."
  local response
  response="$(request_lab01)" || die "The HTTP request itself failed."
  grep -q '200 OK' <<<"$response" || die "Expected HTTP 200 response."
  ip -n mls1-l01-client route show
  bridge fdb show br mls1-l01-br
  ok "HTTP, route and bridge evidence agree"
}
capture_lab01(){
  local dir; dir="$(new_result lab01)"
  ip -n mls1-l01-client neigh flush dev eth0 >/dev/null 2>&1 || true
  ip -n mls1-l01-server neigh flush dev eth0 >/dev/null 2>&1 || true
  fdb_flush_bridge mls1-l01-br
  timeout 8 tcpdump -U -ni mls1-l01-br -c 24 -w "$dir/browser-to-wire.pcap" 'arp or tcp port 8080' >"$dir/tcpdump.log" 2>&1 & CAPTURE_PID=$!
  wait_capture "$dir/tcpdump.log"; request_lab01 >"$dir/http-response.txt"; wait "$CAPTURE_PID" || true
  assert_in_pcap "$dir/browser-to-wire.pcap" 'HTTP/1.0 200' "No HTTP 200 response in the capture"
  tcpdump -nn -tttt -r "$dir/browser-to-wire.pcap" >"$dir/packets.txt" 2>/dev/null
  finish_result "$dir" lab01
  printf '%s\n' "Result: $dir"; ok "Bounded HTTP PCAP saved"
}
evidence_lab01(){ verify_lab01; capture_lab01; }

cleanup_lab02(){
  ip netns del mls1-l02-a >/dev/null 2>&1 || true; ip netns del mls1-l02-b >/dev/null 2>&1 || true
  ip link del mls1-l02-br >/dev/null 2>&1 || true; rm -rf "$STATE_ROOT/lab02"
}
build_lab02(){
  doctor >/dev/null
  cleanup_lab02; mkdir -p "$STATE_ROOT/lab02"; ip link add mls1-l02-br type bridge; ip link set mls1-l02-br up
  add_bridge_host mls1-l02-a mls1-l02-ae mls1-l02-ab mls1-l02-br 192.0.2.10/26 02:00:00:02:00:10
  add_bridge_host mls1-l02-b mls1-l02-be mls1-l02-bb mls1-l02-br 192.0.2.20/26 02:00:00:02:00:20
  ok "Two isolated hosts share 192.0.2.0/26"
}
inspect_lab02(){ ip -n mls1-l02-a -br address; ip -n mls1-l02-a route; ip netns exec mls1-l02-a ip route get 192.0.2.20; }
verify_lab02(){
  exists_ns mls1-l02-a || die "Run lab02 build first."
  ip netns exec mls1-l02-a ping -c 1 -W 1 192.0.2.20 >/dev/null || die "Peer is unreachable."
  inspect_lab02; ok "Address, prefix and connected route verified"
}
capture_lab02(){
  local dir; dir="$(new_result lab02)"
  ip -n mls1-l02-a neigh flush dev eth0 >/dev/null 2>&1 || true
  ip -n mls1-l02-b neigh flush dev eth0 >/dev/null 2>&1 || true
  timeout 6 tcpdump -U -ni mls1-l02-br -c 10 -w "$dir/ipv4-header.pcap" 'arp or icmp' >"$dir/tcpdump.log" 2>&1 & CAPTURE_PID=$!
  wait_capture "$dir/tcpdump.log"; ip netns exec mls1-l02-a ping -c 2 -W 1 192.0.2.20 >"$dir/ping.txt"; wait "$CAPTURE_PID" || true
  ip -n mls1-l02-a address >"$dir/address.txt"; ip -n mls1-l02-a route >"$dir/routes.txt"
  tcpdump -nn -vv -r "$dir/ipv4-header.pcap" >"$dir/packets.txt" 2>/dev/null
  finish_result "$dir" lab02
  printf '%s\n' "Result: $dir"; ok "IPv4 header evidence saved"
}
evidence_lab02(){ verify_lab02; capture_lab02; }

cleanup_lab03(){
  for ns in mls1-l03-left mls1-l03-router mls1-l03-right; do ip netns del "$ns" >/dev/null 2>&1 || true; done
  ip link del mls1-l03-lh >/dev/null 2>&1 || true; ip link del mls1-l03-rh >/dev/null 2>&1 || true; rm -rf "$STATE_ROOT/lab03"
}
build_lab03(){
  doctor >/dev/null
  cleanup_lab03; mkdir -p "$STATE_ROOT/lab03"
  for ns in mls1-l03-left mls1-l03-router mls1-l03-right; do ip netns add "$ns"; ip -n "$ns" link set lo up; done
  ip link add mls1-l03-lh type veth peer name mls1-l03-rl; ip link set mls1-l03-lh netns mls1-l03-left; ip link set mls1-l03-rl netns mls1-l03-router
  ip link add mls1-l03-rh type veth peer name mls1-l03-rr; ip link set mls1-l03-rh netns mls1-l03-right; ip link set mls1-l03-rr netns mls1-l03-router
  ip -n mls1-l03-left link set mls1-l03-lh name eth0; ip -n mls1-l03-right link set mls1-l03-rh name eth0
  ip -n mls1-l03-router link set mls1-l03-rl name left0; ip -n mls1-l03-router link set mls1-l03-rr name right0
  ip -n mls1-l03-left address add 192.0.2.10/26 dev eth0; ip -n mls1-l03-left link set eth0 up
  ip -n mls1-l03-router address add 192.0.2.1/26 dev left0; ip -n mls1-l03-router link set left0 up
  ip -n mls1-l03-router address add 192.0.2.65/26 dev right0; ip -n mls1-l03-router link set right0 up
  ip -n mls1-l03-right address add 192.0.2.70/26 dev eth0; ip -n mls1-l03-right link set eth0 up
  ip netns exec mls1-l03-router sysctl -qw net.ipv4.ip_forward=1
  ip -n mls1-l03-left route add 192.0.2.64/26 via 192.0.2.1
  ip -n mls1-l03-right route add 192.0.2.0/26 via 192.0.2.65
  ok "Two /26 networks and one isolated router are ready"
}
verify_lab03(){
  exists_ns mls1-l03-router || die "Run lab03 build first."
  ip netns exec mls1-l03-left ping -c 1 -W 1 192.0.2.70 >/dev/null || die "Routed peer is unreachable."
  ip -n mls1-l03-left route; ip -n mls1-l03-router route; ok "Both subnet boundaries and the route are verified"
}
break_lab03(){ ip -n mls1-l03-left route del 192.0.2.64/26 via 192.0.2.1; ok "Left host route removed"; }
fix_lab03(){ ip -n mls1-l03-left route replace 192.0.2.64/26 via 192.0.2.1; ok "Left host route restored"; }
capture_lab03(){
  local dir; dir="$(new_result lab03)"
  ip -n mls1-l03-left neigh flush dev eth0 >/dev/null 2>&1 || true
  ip -n mls1-l03-right neigh flush dev eth0 >/dev/null 2>&1 || true
  ip -n mls1-l03-router neigh flush dev left0 >/dev/null 2>&1 || true
  ip -n mls1-l03-router neigh flush dev right0 >/dev/null 2>&1 || true
  timeout 7 ip netns exec mls1-l03-router tcpdump -U -ni left0 -c 8 -w "$dir/left-link.pcap" 'arp or icmp' >"$dir/left-tcpdump.log" 2>&1 & local left_pid=$!
  timeout 7 ip netns exec mls1-l03-router tcpdump -U -ni right0 -c 8 -w "$dir/right-link.pcap" 'arp or icmp' >"$dir/right-tcpdump.log" 2>&1 & local right_pid=$!
  wait_capture "$dir/left-tcpdump.log"; wait_capture "$dir/right-tcpdump.log"
  ip netns exec mls1-l03-left ping -c 2 -W 1 192.0.2.70 >"$dir/ping.txt"; wait "$left_pid" || true; wait "$right_pid" || true
  ip -n mls1-l03-left route >"$dir/left-routes.txt"; ip -n mls1-l03-router route >"$dir/router-routes.txt"
  tcpdump -nn -e -r "$dir/left-link.pcap" >"$dir/left-packets.txt" 2>/dev/null
  tcpdump -nn -e -r "$dir/right-link.pcap" >"$dir/right-packets.txt" 2>/dev/null
  finish_result "$dir" lab03
  printf '%s\n' "Result: $dir"; ok "Two-interface routing PCAP saved"
}
evidence_lab03(){ verify_lab03; capture_lab03; }

cleanup_lab04(){
  for ns in mls1-l04-a mls1-l04-b mls1-l04-witness; do ip netns del "$ns" >/dev/null 2>&1 || true; done
  ip link del mls1-l04-br >/dev/null 2>&1 || true; rm -rf "$STATE_ROOT/lab04"
}
build_lab04(){
  doctor >/dev/null
  cleanup_lab04; mkdir -p "$STATE_ROOT/lab04"; ip link add mls1-l04-br type bridge; ip link set mls1-l04-br up
  add_bridge_host mls1-l04-a mls1-l04-ae mls1-l04-ab mls1-l04-br 198.51.100.10/24 02:00:00:04:00:10
  add_bridge_host mls1-l04-b mls1-l04-be mls1-l04-bb mls1-l04-br 198.51.100.20/24 02:00:00:04:00:20
  add_bridge_host mls1-l04-witness mls1-l04-we mls1-l04-wb mls1-l04-br 198.51.100.30/24 02:00:00:04:00:30
  ok "Three endpoint namespaces and one pure Linux bridge are ready"
}
verify_lab04(){ exists_link mls1-l04-br || die "Run lab04 build first."; bridge link show master mls1-l04-br; bridge fdb show br mls1-l04-br; ok "Bridge ports and FDB inspected"; }
broadcast_lab04(){ ip netns exec mls1-l04-a ping -b -c 1 -W 1 198.51.100.255 >/dev/null 2>&1 || true; }
unknown_lab04(){ ip netns exec mls1-l04-a python3 -c "import socket,time; s=socket.socket(socket.AF_PACKET,socket.SOCK_RAW); s.bind(('eth0',0)); frame=bytes.fromhex('02000004ffff02000004001088b5')+b'MISSION-L2-UNKNOWN'; [s.send(frame) or time.sleep(0.1) for _ in range(3)]"; }
capture_lab04(){
  local dir; dir="$(new_result lab04)"
  ip -n mls1-l04-a neigh flush dev eth0 >/dev/null 2>&1 || true
  ip -n mls1-l04-b neigh flush dev eth0 >/dev/null 2>&1 || true
  fdb_flush_bridge mls1-l04-br
  timeout 7 ip netns exec mls1-l04-witness tcpdump -U -eni eth0 -c 32 -w "$dir/ethernet-frames.pcap" '(arp or icmp) or (ether proto 0x88b5)' >"$dir/tcpdump.log" 2>&1 & CAPTURE_PID=$!
  wait_capture "$dir/tcpdump.log"
  ip netns exec mls1-l04-a ping -c 2 -W 1 198.51.100.20 >/dev/null; broadcast_lab04; unknown_lab04; wait "$CAPTURE_PID" || true
  bridge fdb show br mls1-l04-br >"$dir/fdb.txt"; tcpdump -nn -e -XX -r "$dir/ethernet-frames.pcap" >"$dir/frames.txt" 2>/dev/null
  # The witness must actually have seen the flood. Without this the lab prints
  # PASS for a capture that proves nothing.
  assert_in_pcap "$dir/ethernet-frames.pcap" 'MISSION-L2-UNKNOWN' "The witness did not receive the marked unknown-unicast frame"
  grep -q 'ff:ff:ff:ff:ff:ff' "$dir/frames.txt" || die "The witness did not receive a broadcast frame"
  finish_result "$dir" lab04
  printf '%s\n' "Result: $dir"; ok "Ethernet frame and witness evidence saved"
}
evidence_lab04(){ verify_lab04; capture_lab04; }

cleanup_lab05(){
  ip netns del mls1-l05-a >/dev/null 2>&1 || true; ip netns del mls1-l05-b >/dev/null 2>&1 || true
  ip link del mls1-l05-br >/dev/null 2>&1 || true; rm -rf "$STATE_ROOT/lab05"
}
build_lab05(){
  doctor >/dev/null
  cleanup_lab05; mkdir -p "$STATE_ROOT/lab05"; ip link add mls1-l05-br type bridge; ip link set mls1-l05-br up
  add_bridge_host mls1-l05-a mls1-l05-ae mls1-l05-ab mls1-l05-br 203.0.113.10/24 02:00:00:05:00:10
  add_bridge_host mls1-l05-b mls1-l05-be mls1-l05-bb mls1-l05-br 203.0.113.20/24 02:00:00:05:00:20
  ip -n mls1-l05-a neigh flush dev eth0 >/dev/null 2>&1 || true
  ok "ARP peers are ready with an empty client neighbor cache"
}
flush_lab05(){ ip -n mls1-l05-a neigh flush dev eth0 >/dev/null 2>&1 || true; ip -n mls1-l05-a neigh show; ok "Neighbor cache flushed"; }
resolve_lab05(){ ip netns exec mls1-l05-a ping -c 1 -W 1 203.0.113.20 >/dev/null; ip -n mls1-l05-a neigh show dev eth0; }
verify_lab05(){
  exists_ns mls1-l05-a || die "Run lab05 build first."
  flush_lab05
  local neighbors
  neighbors="$(resolve_lab05)" || die "ARP resolution failed."
  grep -q '02:00:00:05:00:20' <<<"$neighbors" || die "Expected MAC was not learned."
  printf '%s\n' "$neighbors"
  ok "ARP resolved the expected IP-to-MAC mapping"
}
capture_lab05(){
  local dir; dir="$(new_result lab05)"; flush_lab05
  timeout 6 tcpdump -U -ni mls1-l05-br -c 2 -w "$dir/arp-request-reply.pcap" arp >"$dir/tcpdump.log" 2>&1 & CAPTURE_PID=$!
  wait_capture "$dir/tcpdump.log"; resolve_lab05 >"$dir/neighbors.txt"; wait "$CAPTURE_PID" || true
  tcpdump -nn -e -vv -r "$dir/arp-request-reply.pcap" >"$dir/arp.txt" 2>/dev/null
  grep -q 'Request who-has 203.0.113.20' "$dir/arp.txt" || die "No ARP request for 203.0.113.20 in the capture"
  grep -q 'Reply 203.0.113.20 is-at 02:00:00:05:00:20' "$dir/arp.txt" || die "No matching ARP reply in the capture"
  finish_result "$dir" lab05
  printf '%s\n' "Result: $dir"; ok "ARP request and reply PCAP saved"
}
evidence_lab05(){ verify_lab05; capture_lab05; }

destroy_selected(){ case "$1" in lab01)cleanup_lab01;;lab02)cleanup_lab02;;lab03)cleanup_lab03;;lab04)cleanup_lab04;;lab05)cleanup_lab05;;esac; ok "$1 resources removed"; }

main(){
  local lab="${1:-}" command="${2:-help}"
  case "$lab" in help|-h|--help) usage; return;; version|--version) printf '%s\n' "$VERSION"; return;; esac
  [[ "$lab" =~ ^lab0[1-5]$ ]] || { usage; exit 1; }
  case "$command" in help|-h|--help) usage; return;; version|--version) printf '%s\n' "$VERSION"; return;; esac
  need_root
  case "$command" in
    install) install_packages;; doctor) doctor;; destroy) destroy_selected "$lab";;
    build|verify|capture|evidence) "${command}_${lab}";;
    request) [[ "$lab" == lab01 ]] || die "request belongs to lab01"; request_lab01;;
    inspect) [[ "$lab" == lab02 ]] || die "inspect belongs to lab02"; inspect_lab02;;
    break) [[ "$lab" == lab03 ]] || die "break belongs to lab03"; break_lab03;;
    fix) [[ "$lab" == lab03 ]] || die "fix belongs to lab03"; fix_lab03;;
    broadcast) [[ "$lab" == lab04 ]] || die "broadcast belongs to lab04"; broadcast_lab04;;
    unknown) [[ "$lab" == lab04 ]] || die "unknown belongs to lab04"; unknown_lab04;;
    flush) [[ "$lab" == lab05 ]] || die "flush belongs to lab05"; flush_lab05;;
    resolve) [[ "$lab" == lab05 ]] || die "resolve belongs to lab05"; resolve_lab05;;
    *) usage; exit 1;;
  esac
}
main "$@"