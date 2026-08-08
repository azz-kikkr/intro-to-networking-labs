# Intro to Networking Labs

Free, local, evidence-first labs for Mission Tech's [Networking Zero to Hero](https://missioninstituteoftechnology.com/courses/networking-zero-to-hero.html) course.

**Act 1** (Labs 1-6) uses Linux network namespaces, veth pairs, bridges, routes, packet captures and kernel state to teach Layer 2 fundamentals.

**Act 2** (Lab 7+) uses Docker containers running [FRRouting](https://frrouting.org/) to teach BGP and Layer 3 routing.

You make a prediction, build a bounded network, collect evidence and explain what the evidence proves.

## What you build

```text
browser or command
        |
  Linux namespace
        |
      veth
        |
  Linux bridge  ---- packet capture
        |
 kernel route, neighbor, VLAN, FDB and STP state
```

The browser is the control room. The Linux kernel is the network.

## Requirements

### Act 1 (Layer 2 labs)

Use one of these environments:

- a clean Ubuntu VM with Docker not installed
- WSL2 Ubuntu where the lab guide explicitly supports it

You need `sudo` and a kernel that permits network namespaces, veth pairs and Linux bridges. Never run the labs on a production host.

The learner scripts do not modify a physical interface, host default route, host firewall or WSL external interface. They create only `mls1`-prefixed virtual resources and track exact PIDs for cleanup.

### Act 2 (BGP labs)

Use any environment with:

- Docker Engine (Linux) or Docker Desktop (macOS, Windows with WSL2)
- Docker Compose plugin

No `sudo` required if your user is in the `docker` group. All containers and networks use `mls1-bgp`-prefixed names and are fully removed on destroy.

## Start here

```bash
git clone https://github.com/azz-kikkr/intro-to-networking-labs.git
cd intro-to-networking-labs
chmod +x scripts/*.sh tests/*.sh
bash tests/acceptance.sh
```

Then read [Start Here](docs/00-start-here.md). Run the environment check before building a lab:

```bash
# Act 1 (Layer 2)
sudo ./scripts/mission-act1-labs.sh doctor
sudo ./scripts/mission-layer2-capstone.sh doctor

# Act 2 (BGP)
./scripts/mission-act2-bgp.sh doctor
./scripts/mission-act2-bgp.sh prep
```

## Act 1 lab path

| Session | Lab | Time | Evidence you leave with |
|---|---|---:|---|
| 1 | [Browser to Wire](docs/lab-01-browser-to-wire.md) | 35 min | HTTP, route, bridge and PCAP evidence agree |
| 2 | [IP Addresses](docs/lab-02-ip-addresses.md) | 30 min | A prefix creates a connected kernel route |
| 3 | [Subnet Boundaries](docs/lab-03-subnet-boundaries.md) | 40 min | Routing changes Layer 2 headers while preserving the Layer 3 journey |
| 4 | [Ethernet Frames](docs/lab-04-ethernet-frames.md) | 40 min | A witness proves broadcast and unknown-unicast flooding |
| 5 | [ARP Resolution](docs/lab-05-arp-resolution.md) | 30 min | A request and matching reply create an IP-to-MAC mapping |
| 6 | [Layer 2 Capstone](docs/lab-06-layer2-capstone.md) | 90 to 120 min | VLAN, FDB and STP evidence explain and repair a campus fabric |

Before Lab 06, complete the [Layer 2 capstone readiness primer](docs/capstone-readiness.md) covering FDB learning, VLAN access and trunk behavior, PVIDs, STP root selection, path cost and failover.

## Act 2 lab path

Act 2 introduces BGP routing with containerized FRR routers. Docker is required.

| Session | Lab | Time | Evidence you leave with |
|---|---|---:|---|
| 7 | [Your First eBGP Session](docs/lab-07-first-ebgp-session.md) | 45 min | BGP session state, AS path and prefix learning prove eBGP peering works |

### Act 2 quick start

```bash
./scripts/mission-act2-bgp.sh doctor
./scripts/mission-act2-bgp.sh prep
./scripts/mission-act2-bgp.sh build lab01
./scripts/mission-act2-bgp.sh verify lab01
./scripts/mission-act2-bgp.sh connect r1
./scripts/mission-act2-bgp.sh evidence lab01
./scripts/mission-act2-bgp.sh destroy lab01
```

## Evidence contract

Every lab separates three questions:

1. What did the learner-facing command report?
2. What state does the Linux kernel (or router) expose?
3. What does the packet capture (or routing table) prove?

Evidence stays local under a timestamped `results/` directory. Act 1 evidence includes bounded PCAPs with checksums. Act 2 evidence includes BGP table dumps, session state and running configurations. Manifests identify the runner version and make later review reproducible.

## Useful commands

### Act 1 (kernel networking)

```bash
# Ask the kernel which route it would use.
ip route get 1.1.1.1

# Inspect Layer 2 state.
bridge link show
bridge vlan show
bridge fdb show

# Read a capture without a GUI.
tcpdump -nn -e -r results/path/to/capture.pcap
tcpdump -nn -r results/path/to/capture.pcap 'tcp[tcpflags] & tcp-syn != 0'
```

### Act 2 (BGP routing)

```bash
# Inside vtysh on a router container:
show bgp summary
show ip bgp
show ip bgp neighbors 10.1.12.3 received-routes
show running-config
```

Capture filters and Wireshark display filters are different languages. Capture broadly enough to preserve evidence, then narrow the view during analysis.

## Validation

Static checks:

```bash
bash -n scripts/*.sh tests/*.sh
shellcheck -x scripts/*.sh tests/*.sh
LC_ALL=C bash tests/acceptance.sh
LC_ALL=C.UTF-8 bash tests/acceptance.sh
bash tests/act2-acceptance.sh
```

Privileged runtime gate on the target Ubuntu VM (Act 1):

```bash
sudo bash tests/smoke.sh
sudo ip netns list
ip -o link show | grep mls1
```

Docker runtime gate (Act 2):

```bash
bash tests/act2-smoke.sh
docker ps --format '{{.Names}}' | grep mls1-bgp || echo "clean"
```

A release-quality runtime ends with `failed 0, skipped 0`, followed by no remaining `mls1` namespaces, links or containers. Static checks do not prove privileged kernel feasibility or Docker availability.

## Troubleshooting

Read [Troubleshooting](docs/troubleshooting.md) first. Two common causes are:

- running from `/mnt/c` instead of the Linux filesystem under WSL2
- Docker's bridge netfilter and `FORWARD` policy changing bridged-packet behavior

Use a clean Ubuntu VM with Docker not installed for the capstone release gate. The scripts will not weaken the host's firewall or security posture to make a lab pass.

## Free and open study resources

- [Wireshark User's Guide](https://www.wireshark.org/docs/wsug_html/), official documentation for the open-source packet analyzer
- [Beej's Guide to Network Concepts](https://beej.us/guide/bgnet/), a free guide from frames through routing and transport
- [Mininet Walkthrough](https://mininet.org/walkthrough/), an open-source network-emulation lab
- [FRRouting User Guide](https://docs.frrouting.org/en/latest/), free software for OSPF, BGP, IS-IS and more
- [Linux network namespace manual](https://man7.org/linux/man-pages/man8/ip-netns.8.html), the primitive behind the lab endpoints
- [IETF RFC index](https://www.rfc-editor.org/), the open standards themselves

## Contributing

Keep changes bounded and evidence-driven. Shell scripts must use strict mode, quoted variables, bounded polling, explicit failure and idempotent cleanup. Do not add host firewall changes, broad process-name killing, telemetry, accounts, SaaS dependencies, vendor images or arbitrary privileged execution.

Before opening a pull request, run the static checks above and state exactly which privileged labs were run.

## Licenses

Code is MIT licensed. Workshop text and diagrams are CC BY 4.0 licensed. See [LICENSE](LICENSE) and [LICENSE-CONTENT](LICENSE-CONTENT).