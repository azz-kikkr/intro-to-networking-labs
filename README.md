# Intro to Networking Labs

Six free, local, evidence-first labs for Act 1 of Mission Tech's Networking Zero to Hero course.

You will not memorize networking from slides. You will make a prediction, build a bounded Linux network, observe kernel state, capture packets, and explain what the evidence proves.

## Start in three commands

```bash
git clone https://github.com/azz-kikkr/intro-to-networking-labs.git
cd intro-to-networking-labs
chmod +x scripts/*.sh
```

Then follow [Start Here](docs/00-start-here.md). Use WSL2 Ubuntu or a disposable Linux VM. Never run these scripts on a production host.

## Act 1 path

| Session | Lab | Time | Proof you leave with |
|---|---|---:|---|
| 1 | [Browser to Wire](docs/lab-01-browser-to-wire.md) | 35 min | DevTools observations mapped carefully to a controlled HTTP capture |
| 2 | [IP Addresses](docs/lab-02-ip-addresses.md) | 30 min | A prefix creates a connected kernel route |
| 3 | [Subnet Boundaries](docs/lab-03-subnet-boundaries.md) | 40 min | A router changes Layer 2 headers while forwarding Layer 3 traffic |
| 4 | [Ethernet Frames](docs/lab-04-ethernet-frames.md) | 40 min | Broadcast and unknown-unicast flooding seen by a witness |
| 5 | [ARP Resolution](docs/lab-05-arp-resolution.md) | 30 min | An empty neighbor cache becomes an IP-to-MAC mapping |
| 6 | [Layer 2 Capstone](docs/lab-06-layer2-capstone.md) | 75 min | VLAN, FDB and STP evidence explain and repair a campus fabric |

## Evidence contract

Every lab answers three separate questions:

1. What did the learner-facing tool report?
2. What state does the Linux kernel expose?
3. What does the packet capture prove?

Generated evidence stays local under a timestamped `results/` directory. Each capture set includes a manifest and SHA-256 checksums. The scripts do not modify a physical interface, host default route, host firewall, or WSL external interface.

## Licenses

Code is MIT licensed. Workshop text and diagrams are CC BY 4.0 licensed. See [LICENSE](LICENSE) and [LICENSE-CONTENT](LICENSE-CONTENT).