# Intro to Networking Labs

Six free, local, evidence-first labs for Act 1 of Mission Tech's Networking Zero to Hero course.

These labs turn browser observations, Linux kernel state and packet captures into one coherent model of a local network. They use real network namespaces, veth pairs, Linux bridges and bounded captures. No account, cloud lab or vendor image is required.

## The path

| Session | Lab | Central proof |
|---|---|---|
| 1 | [Browser to Wire](docs/lab-01-browser-to-wire.md) | DevTools timing maps to ARP, TCP and HTTP packet events |
| 2 | [IP Addresses, Proven](docs/lab-02-ip-addresses.md) | Address plus prefix creates a connected kernel route |
| 3 | [Subnet Boundaries](docs/lab-03-subnet-boundaries.md) | A router forwards between two real `/26` networks |
| 4 | [Ethernet Frames on a Real Wire](docs/lab-04-ethernet-frames.md) | A witness proves broadcast and unknown-unicast flooding |
| 5 | [ARP, Request to Resolution](docs/lab-05-arp-resolution.md) | An empty neighbor cache becomes a verified IP-to-MAC mapping |
| 6 | [Layer 2 Capstone](docs/lab-06-layer2-capstone.md) | VLAN, FDB and STP evidence explain a four-switch fabric |

Start with [the setup and safety guide](docs/00-start-here.md).

## Requirements

- Windows 11 with WSL2 Ubuntu, or a disposable Linux VM
- `sudo` inside that Linux environment
- Wireshark on Windows is optional
- Chrome or Edge DevTools for Lab 01

## Evidence contract

Every investigation separates three questions:

1. What did the learner-facing tool report?
2. What state does the Linux kernel expose?
3. What does the packet capture prove?

Generated evidence stays local under a timestamped `results/` directory. The scripts do not modify a physical interface, the host default route, the host firewall or the WSL external interface.

## License

Code is licensed under the MIT License. Written workshop material is licensed under CC BY 4.0.