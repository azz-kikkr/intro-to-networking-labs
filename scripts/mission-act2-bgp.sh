#!/usr/bin/env bash
set -Eeuo pipefail

LAB_SUITE="Mission Tech Act 2 BGP Labs"
VERSION="1.1.4"
RESULTS_ROOT="${PWD}/results"
FRR_IMAGE="quay.io/frrouting/frr:10.3.1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LABS_DIR="$REPO_ROOT/labs/act2-bgp"

# Container and network names use the mls1 prefix required by the project.
PREFIX="mls1-bgp"

log(){ printf '[%s] %s\n' "$LAB_SUITE" "$*"; }
ok(){ printf '[PASS] %s\n' "$*"; }
die(){ printf '[FAIL] %s\n' "$*" >&2; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }

usage(){ cat <<'EOF'
Usage:
  ./scripts/mission-act2-bgp.sh <command> [lab]

Commands:
  --version       Print the runner version
  doctor          Check Docker and Docker Compose prerequisites
  prep            Pull the FRR container image
  build <lab>     Start a lab topology (e.g. lab01)
  verify <lab>    Verify BGP sessions and prefix learning
  evidence <lab>  Save router state as timestamped evidence
  connect <r>     Open interactive vtysh on a router (e.g. mls1-bgp-r1)
  destroy <lab>   Remove lab containers and networks
  list            Show available labs

Environment:
  Linux, macOS, or Windows WSL2 with Docker Engine or Docker Desktop.
  No sudo required for Docker commands when the user is in the docker group.
EOF
}

# ---------------------------------------------------------------------------
# Doctor
# ---------------------------------------------------------------------------
doctor(){
  local failed=0
  if have docker && docker info >/dev/null 2>&1; then
    ok "Docker is installed and running"
  else
    printf '[FAIL] Docker is not installed or the daemon is not running\n' >&2
    failed=1
  fi
  if docker compose version >/dev/null 2>&1; then
    ok "Docker Compose is available"
  else
    printf '[FAIL] Docker Compose plugin is not available\n' >&2
    failed=1
  fi
  (( failed == 0 )) || die "Environment check failed"
  ok "Environment is ready"
}

# ---------------------------------------------------------------------------
# Prep
# ---------------------------------------------------------------------------
prep(){
  log "Pulling $FRR_IMAGE (this may take a minute on first run)"
  docker pull "$FRR_IMAGE"
  ok "FRR image ready: $FRR_IMAGE"
}

# ---------------------------------------------------------------------------
# Lab resolution
# ---------------------------------------------------------------------------
resolve_lab(){
  local lab="$1"
  local lab_dir="$LABS_DIR/$lab"
  [[ -d "$lab_dir" ]] || die "Lab '$lab' not found. Run: $0 list"
  [[ -f "$lab_dir/docker-compose.yml" ]] || die "Lab '$lab' is missing docker-compose.yml"
  printf '%s' "$lab_dir"
}

list_labs(){
  log "Available Act 2 BGP labs:"
  for d in "$LABS_DIR"/*/; do
    [[ -d "$d" ]] || continue
    local name; name="$(basename "$d")"
    printf '  %s\n' "$name"
  done
}

# ---------------------------------------------------------------------------
# Build (compose up)
# ---------------------------------------------------------------------------
build_lab(){
  local lab="$1"
  local lab_dir; lab_dir="$(resolve_lab "$lab")"
  doctor >/dev/null 2>&1 || doctor
  log "Starting $lab topology"
  docker compose -f "$lab_dir/docker-compose.yml" -p "${PREFIX}-${lab}" up -d
  ok "$lab containers are running"
  log "Waiting for BGP sessions to converge (up to 90 seconds)"
  wait_bgp "$lab_dir" "$lab"
}

wait_bgp(){
  local lab_dir="$1" lab="$2"
  local attempts=45 # 45 x 2s = 90 seconds
  local checks_file="$lab_dir/checks.json"
  [[ -f "$checks_file" ]] || die "No checks.json found for $lab"
  while (( attempts > 0 )); do
    if verify_checks "$lab_dir" "$lab" quiet; then
      ok "BGP sessions established and prefixes learned"
      return 0
    fi
    sleep 2
    attempts=$((attempts - 1))
  done
  die "BGP did not converge within 90 seconds. Run: $0 verify $lab"
}

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------
verify_lab(){
  local lab="$1"
  local lab_dir; lab_dir="$(resolve_lab "$lab")"
  verify_checks "$lab_dir" "$lab" loud
}

verify_checks(){
  local lab_dir="$1" lab="$2" mode="$3"
  local checks_file="$lab_dir/checks.json"
  local total=0 passed=0

  # Parse checks.json using a simple line-by-line approach (no jq dependency).
  local type router peer prefix description
  local in_object=false

  while IFS= read -r line; do
    # Detect object boundaries
    if [[ "$line" == *"{"* && "$line" != "["* ]]; then
      in_object=true
      type="" router="" peer="" prefix="" description=""
    fi
    if [[ "$in_object" == true ]]; then
      if [[ "$line" =~ \"type\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
        type="${BASH_REMATCH[1]}"
      fi
      if [[ "$line" =~ \"router\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
        router="${BASH_REMATCH[1]}"
      fi
      if [[ "$line" =~ \"peer\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
        peer="${BASH_REMATCH[1]}"
      fi
      if [[ "$line" =~ \"prefix\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
        prefix="${BASH_REMATCH[1]}"
      fi
      if [[ "$line" =~ \"description\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
        description="${BASH_REMATCH[1]}"
      fi
    fi
    if [[ "$line" == *"}"* && "$in_object" == true ]]; then
      in_object=false
      [[ -n "$type" ]] || continue
      total=$((total + 1))
      local result=false
      case "$type" in
        container_running)
          local cname="${PREFIX}-${lab}-${router}-1"
          if docker inspect --format='{{.State.Running}}' "$cname" 2>/dev/null | grep -q true; then
            result=true
          fi
          ;;
        bgp_session)
          local cname="${PREFIX}-${lab}-${router}-1"
          local output
          output="$(docker exec "$cname" vtysh -c 'show bgp summary json' 2>/dev/null)" || true
          if printf '%s' "$output" | grep -q "\"$peer\""; then
            if printf '%s' "$output" | grep -q '"pfxRcd"'; then
              # pfxRcd is present when session is Established
              local pfx_count
              # Extract pfxRcd value after the peer IP
              pfx_count="$(printf '%s' "$output" | grep -A 20 "\"$peer\"" | grep '"pfxRcd"' | head -1 | grep -oE '[0-9]+')" || true
              if [[ -n "$pfx_count" && "$pfx_count" -gt 0 ]]; then
                result=true
              fi
            fi
          fi
          ;;
        prefix_received)
          local cname="${PREFIX}-${lab}-${router}-1"
          local output
          output="$(docker exec "$cname" vtysh -c "show ip bgp json" 2>/dev/null)" || true
          if printf '%s' "$output" | grep -q "\"$prefix\""; then
            # Confirm it was learned from the expected peer
            if printf '%s' "$output" | grep -A 5 "\"$prefix\"" | grep -q "\"peerId\":\"$peer\""; then
              result=true
            fi
          fi
          ;;
      esac
      if [[ "$result" == true ]]; then
        passed=$((passed + 1))
        [[ "$mode" == "loud" ]] && printf '[PASS] %s\n' "$description"
      else
        [[ "$mode" == "loud" ]] && printf '[FAIL] %s\n' "$description" >&2
      fi
    fi
  done < "$checks_file"

  if [[ "$mode" == "loud" ]]; then
    printf '\n%d/%d checks passed\n' "$passed" "$total"
  fi
  (( passed == total ))
}

# ---------------------------------------------------------------------------
# Evidence
# ---------------------------------------------------------------------------
evidence_lab(){
  local lab="$1"
  local lab_dir; lab_dir="$(resolve_lab "$lab")"
  local checks_file="$lab_dir/checks.json"
  local stamp; stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
  local result_dir="${RESULTS_ROOT}/${stamp}-act2-${lab}"
  mkdir -p "$result_dir"

  # Collect evidence from each router mentioned in checks.json
  local routers=()
  while IFS= read -r line; do
    if [[ "$line" =~ \"router\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
      local r="${BASH_REMATCH[1]}"
      local already=false
      for existing in "${routers[@]+"${routers[@]}"}"; do
        [[ "$existing" == "$r" ]] && already=true
      done
      [[ "$already" == false ]] && routers+=("$r")
    fi
  done < "$checks_file"

  for router in "${routers[@]}"; do
    local cname="${PREFIX}-${lab}-${router}-1"
    log "Collecting evidence from $router"
    docker exec "$cname" vtysh -c "show bgp summary" > "$result_dir/${router}-bgp-summary.txt" 2>/dev/null || true
    docker exec "$cname" vtysh -c "show ip bgp" > "$result_dir/${router}-bgp-table.txt" 2>/dev/null || true
    docker exec "$cname" vtysh -c "show ip bgp json" > "$result_dir/${router}-bgp-table.json" 2>/dev/null || true
    docker exec "$cname" vtysh -c "show running-config" > "$result_dir/${router}-running-config.txt" 2>/dev/null || true
    docker exec "$cname" vtysh -c "show bgp neighbors" > "$result_dir/${router}-bgp-neighbors.txt" 2>/dev/null || true
  done

  # Write manifest
  {
    printf 'lab=%s\n' "$lab"
    printf 'generated_utc=%s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    printf 'runner_version=%s\n' "$VERSION"
    printf 'evidence_type=bgp_router_state\n'
  } > "$result_dir/manifest.txt"

  # Run verify and save output
  verify_lab "$lab" > "$result_dir/verify-output.txt" 2>&1 || true

  ok "Evidence saved to $result_dir"
  printf '%s\n' "Result: $result_dir"
}

# ---------------------------------------------------------------------------
# Connect
# ---------------------------------------------------------------------------
connect_router(){
  local router="$1"
  # Accept both raw name (r1) and full container name (mls1-bgp-lab01-r1-1)
  local cname="$router"
  if ! docker inspect "$cname" >/dev/null 2>&1; then
    # Try to find a running container matching the short name
    local match
    match="$(docker ps --format '{{.Names}}' | grep "${PREFIX}.*-${router}-" | head -1)" || true
    if [[ -n "$match" ]]; then
      cname="$match"
    else
      die "Container '$router' is not running. Start a lab first: $0 build <lab>"
    fi
  fi
  log "Connecting to $cname (type 'exit' to leave)"
  docker exec -it "$cname" vtysh
}

# ---------------------------------------------------------------------------
# Destroy
# ---------------------------------------------------------------------------
destroy_lab(){
  local lab="$1"
  local lab_dir; lab_dir="$(resolve_lab "$lab")"
  log "Stopping $lab"
  docker compose -f "$lab_dir/docker-compose.yml" -p "${PREFIX}-${lab}" down --volumes --remove-orphans 2>/dev/null || true
  ok "$lab containers and networks removed"
}

# ---------------------------------------------------------------------------
# Main dispatch
# ---------------------------------------------------------------------------
main(){
  local command="${1:-help}"
  case "$command" in
    help|-h|--help) usage; return;;
    version|--version) printf '%s\n' "$VERSION"; return;;
    doctor) doctor;;
    prep) prep;;
    list) list_labs;;
    build)
      [[ -n "${2:-}" ]] || die "Usage: $0 build <lab>"
      build_lab "$2"
      ;;
    verify)
      [[ -n "${2:-}" ]] || die "Usage: $0 verify <lab>"
      verify_lab "$2"
      ;;
    evidence)
      [[ -n "${2:-}" ]] || die "Usage: $0 evidence <lab>"
      evidence_lab "$2"
      ;;
    connect)
      [[ -n "${2:-}" ]] || die "Usage: $0 connect <router>"
      connect_router "$2"
      ;;
    destroy)
      [[ -n "${2:-}" ]] || die "Usage: $0 destroy <lab>"
      destroy_lab "$2"
      ;;
    *) usage; exit 1;;
  esac
}
main "$@"
