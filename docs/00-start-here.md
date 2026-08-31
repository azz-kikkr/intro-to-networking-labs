# Start Here

[Course home](../README.md) · [Lab 01: Browser to Wire →](lab-01-browser-to-wire.md)

This is the learner setup guide for Networking Zero to Hero Labs. Follow it once before beginning the lab sequence.

## Your goal

Complete the current course with seven evidence folders you can inspect and explain:

- five guided investigations from browser traffic through ARP and switching
- one Layer 2 capstone covering VLANs, FDB learning, STP, failure, and repair
- one Layer 3 lab establishing and proving an eBGP session

Budget about **4 to 5 hours for Act 1** and **45 minutes for the current Act 2 lab**. Take breaks between labs. The evidence stays on your machine, so you do not need to finish in one sitting.

## Choose the right environment

Act 1 and Act 2 have different requirements. You can complete either act independently.

| | Act 1 · Labs 01–06 | Act 2 · Lab 07+ |
|---|---|---|
| What runs | Linux namespaces, veth pairs, bridges, kernel STP | FRRouting containers |
| Best environment | Clean Ubuntu 22.04 or 24.04 VM | Any host with Docker Engine or Docker Desktop |
| Also supported | WSL2 Ubuntu where the guide says so | Linux, macOS, or Windows with WSL2 |
| Privilege | `sudo` required | No `sudo` if your user can run Docker |
| Docker | Prefer a host without Docker installed | Required |

Never use a production host. Act 1 creates privileged virtual networking objects. The runners are tightly scoped, but a disposable learning environment remains the correct boundary.

> **Act 1 and Docker:** Docker can load bridge netfilter and leave a `FORWARD` policy that silently drops the lab's bridged traffic. A clean Ubuntu VM without Docker is the reliable choice for the Layer 2 capstone. The course will report the condition but will not change your firewall.

## 1. Get the course

Open a terminal inside Ubuntu for Act 1, or on your Docker host for Act 2.

```bash
git clone https://github.com/azz-kikkr/intro-to-networking-labs.git
cd intro-to-networking-labs
chmod +x scripts/*.sh tests/*.sh
```

Keep the repository inside the Linux filesystem when using WSL2, such as `~/intro-to-networking-labs`. Do not run it from `/mnt/c`.

Confirm the runners are available:

```bash
./scripts/mission-act1-labs.sh --version
./scripts/mission-act2-bgp.sh --version
```

## 2. Prepare Act 1

Install the open-source command-line tools used by Labs 01 to 05:

```bash
sudo ./scripts/mission-act1-labs.sh lab01 install
```

Then run the real environment check:

```bash
sudo ./scripts/mission-act1-labs.sh lab01 doctor
```

`doctor` must pass before you build a lab. It checks that your kernel can create namespaces, veth pairs, bridges, and bounded packet captures. A shell syntax check cannot prove these privileged operations work.

Before Lab 06, prepare and check the capstone runner too:

```bash
sudo ./scripts/mission-layer2-capstone.sh install
sudo ./scripts/mission-layer2-capstone.sh doctor
```

If a check fails, stop and use [Troubleshooting](troubleshooting.md). Do not continue on the assumption that later commands will repair the environment.

## 3. Learn the lab loop

Every lab follows the same reasoning loop:

1. **Predict** what the network should do.
2. **Build** one bounded topology.
3. **Verify** the known-good baseline.
4. **Capture** controlled traffic and network state.
5. **Explain** the result using specific evidence.
6. **Destroy** the topology while keeping the evidence.

For Labs 01 to 05, replace `lab01` with the lab you are taking:

```bash
sudo ./scripts/mission-act1-labs.sh lab01 build
sudo ./scripts/mission-act1-labs.sh lab01 verify
sudo ./scripts/mission-act1-labs.sh lab01 capture
sudo ./scripts/mission-act1-labs.sh lab01 destroy
```

A command that exits nonzero did not pass. Read the complete `[FAIL]` line, correct the cause, and rerun the failed step. Ping success by itself does not override a failed verification.

If you interrupt a lab or want to start again, run only that lab's documented `destroy` command. Do not delete namespaces, links, containers, or processes by a broad name or pattern.

## 4. Read your evidence

Each capture creates a timestamped folder under `results/`. Find the newest Lab 01 folder with:

```bash
find results -maxdepth 1 -type d -name '*-lab01' | sort
```

Read a packet capture in the terminal:

```bash
tcpdump -nn -e -r results/TIMESTAMP-lab01/browser-to-wire.pcap
```

Or open the same `.pcap` file in Wireshark. From Windows, browse to the Linux folder through `\\wsl$` instead of copying the repository to `/mnt/c`.

Capture filters and Wireshark display filters are different languages. Capture broadly enough to preserve the event, then narrow the view during analysis. Useful Wireshark display filters include:

```text
arp
icmp
tcp.port == 8080
eth.dst == ff:ff:ff:ff:ff:ff
```

Use the [packet capture field guide](packet-capture-field-guide.md) when you are unsure which layer or field supports a claim.

## 5. Complete Act 1 in order

| Lab | Core question | You are done when... |
|---|---|---|
| [01 · Browser to Wire](lab-01-browser-to-wire.md) | How does a browser request relate to packets? | You can connect ARP, TCP, and HTTP evidence |
| [02 · IP Addresses](lab-02-ip-addresses.md) | What does a prefix change? | You can explain the connected route created by `/26` |
| [03 · Subnet Boundaries](lab-03-subnet-boundaries.md) | What changes at a router? | You can separate the L2 hop from the L3 journey |
| [04 · Ethernet Frames](lab-04-ethernet-frames.md) | What does a switch flood? | You can prove broadcast and unknown-unicast behavior |
| [05 · ARP Resolution](lab-05-arp-resolution.md) | How does an IP become a MAC? | You can connect an ARP exchange to neighbor state |
| [06 · Layer 2 Capstone](lab-06-layer2-capstone.md) | Can you explain and repair a campus fabric? | You can defend VLAN, FDB, STP, and failover claims |

Complete the [capstone readiness primer](capstone-readiness.md) before Lab 06.

## 6. Prepare Act 2

Act 2 is independent of the privileged Act 1 environment. Start Docker, then run:

```bash
./scripts/mission-act2-bgp.sh doctor
./scripts/mission-act2-bgp.sh prep
```

`prep` downloads the FRRouting image once. `doctor` must report that Docker, Docker Compose, and the environment are ready.

The Act 2 workflow is:

```bash
./scripts/mission-act2-bgp.sh build lab01
./scripts/mission-act2-bgp.sh verify lab01
./scripts/mission-act2-bgp.sh connect r1
./scripts/mission-act2-bgp.sh evidence lab01
./scripts/mission-act2-bgp.sh destroy lab01
```

Follow [Lab 07: Your First eBGP Session](lab-07-first-ebgp-session.md) for the router commands, expected values, and explanation questions.

## Your evidence contract

For every lab, answer all four prompts:

1. **Prediction:** What did you expect before running the lab?
2. **Observation:** Which exact kernel, router, or packet field did you inspect?
3. **Claim:** What does that evidence support?
4. **Limit:** What can that evidence not prove by itself?

A strong explanation names the capture point or command, cites a concrete field or state value, and avoids claiming more than the observation supports.

## Definition of complete

You have completed a lab when:

- its `verify` command passes
- you can reopen the saved evidence after the topology is destroyed
- your explanation cites at least one specific state value or packet field
- you can state one limitation of the evidence
- the lab's exact resources are no longer running

Ready? Begin with **[Lab 01: Browser to Wire](lab-01-browser-to-wire.md)**.
