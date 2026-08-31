# Troubleshooting

[Start guide](00-start-here.md) · [Course home](../README.md) · [Open an issue](https://github.com/azz-kikkr/intro-to-networking-labs/issues)

Start with the runner's `doctor` command. It checks the environment the lab actually needs and is more useful than guessing from a later symptom.

```bash
# Act 1 · Labs 01–05
sudo ./scripts/mission-act1-labs.sh lab01 doctor

# Act 1 · Lab 06 capstone
sudo ./scripts/mission-layer2-capstone.sh doctor

# Act 2 · BGP
./scripts/mission-act2-bgp.sh doctor
```

## Quick triage

| Symptom | Likely cause | First action |
|---|---|---|
| `Permission denied` when starting a runner | Executable bit is missing | Run `chmod +x scripts/*.sh tests/*.sh` |
| Namespace or veth creation fails | Wrong environment, missing `sudo`, or unsupported kernel | Run the Act 1 `doctor` command with `sudo` |
| Ping or HTTP fails although the topology built | Docker bridge netfilter or host `FORWARD` policy | Use a clean Ubuntu VM without Docker |
| A PCAP is empty | Capture ran before a valid build or traffic was blocked | Read the adjacent `tcpdump.log` and rerun `verify` |
| BGP containers do not start | Docker daemon, Compose, image, or port/resource issue | Run the Act 2 `doctor`, then `docker compose ps` |
| BGP session stays Active | Neighbor address, remote AS, or container reachability mismatch | Run `verify`, then inspect both running configurations |

## Act 1: namespace or veth creation fails

Confirm that you are on native Ubuntu or inside WSL2 Ubuntu and that the command uses `sudo`.

```bash
uname -a
sudo ./scripts/mission-act1-labs.sh lab01 doctor
```

Do not continue until `doctor` passes. A shell syntax check cannot prove that privileged namespaces, veth pairs, bridges, and packet capture work on your kernel.

## Act 1: repository is under `/mnt/c`

Keep the repository in the WSL2 Linux filesystem. Move to your Linux home directory and clone it there:

```bash
cd
git clone https://github.com/azz-kikkr/intro-to-networking-labs.git
cd intro-to-networking-labs
```

Open evidence from Windows through `\\wsl$`. Do not run the course from the mounted Windows filesystem.

## Act 1: a capture contains zero packets

Confirm that the selected lab is built and verified, then use its documented `capture` command. Read the `tcpdump.log` saved beside the empty PCAP.

```bash
sudo ./scripts/mission-act1-labs.sh lab01 verify
sudo ./scripts/mission-act1-labs.sh lab01 capture
find results -name tcpdump.log -type f | sort
```

The runner starts a bounded capture before generating controlled traffic. An empty file is a failed observation, not proof that no traffic exists.

## Wireshark cannot open a capture

First prove that the file is readable inside Linux:

```bash
tcpdump -nn -e -r results/TIMESTAMP-LAB/file.pcap
```

If `tcpdump` can read it, open the same Linux path in Wireshark. If it cannot, preserve the adjacent log and manifest when reporting the issue.

## A lab already exists

Run only that lab's exact cleanup command, then build again:

```bash
sudo ./scripts/mission-act1-labs.sh lab01 destroy
```

For Lab 06 use `mission-layer2-capstone.sh destroy`. For Act 2 use `mission-act2-bgp.sh destroy lab01`. Never delete arbitrary namespaces, interfaces, containers, or processes by a broad pattern.

## Docker is installed on the Act 1 host

Docker loads `br_netfilter` and can set the host packet filter's `FORWARD` policy to `DROP`. Bridged IPv4 traffic may then be consumed before Linux bridge forwarding, with no useful error in the lab itself. `doctor` reports this as a `[CHECK]`.

Use a clean Ubuntu VM with Docker not installed for Act 1. Stopping Docker is not sufficient: the packet-filter policy and loaded module can remain after the daemon exits.

The learner scripts will not change the host firewall, disable bridge netfilter, or unload kernel modules. A teaching lab should not weaken the learner's security posture to make a test pass.

## Lab 06 takes time to converge

The capstone uses classic Linux kernel STP with shortened classroom timers. Use the runner's bounded status commands and wait for the expected port state before starting a failure scenario. Run stateful demos one at a time and use `fix` between them.

If the active scenario is unclear, rebuild the known-good baseline:

```bash
sudo ./scripts/mission-layer2-capstone.sh reset
sudo ./scripts/mission-layer2-capstone.sh verify
```

## Lab 06 fails with a netlink range error

`RTNETLINK answers: Numerical result out of range` means bridge timers were sent in the wrong unit. `ip link set ... type bridge` expects `forward_delay`, `hello_time`, `max_age`, and `ageing_time` in hundredths of a second. Runner 1.1.0 and later sends `400`, `100`, `600`, and `12000`.

Confirm your runner version:

```bash
./scripts/mission-layer2-capstone.sh --version
```

## Act 2: Docker or Compose is unavailable

Start Docker Engine or Docker Desktop and rerun:

```bash
./scripts/mission-act2-bgp.sh doctor
docker version
docker compose version
```

On Linux, a Docker socket permission error means the current user cannot access Docker. Follow Docker's official post-installation guidance or run Docker through your environment's approved method. Do not make the socket world-writable.

## Act 2: containers start but BGP does not establish

Run the course verification first:

```bash
./scripts/mission-act2-bgp.sh verify lab01
docker compose -f labs/act2-bgp/lab01/docker-compose.yml ps
```

Then collect both routers' state:

```bash
./scripts/mission-act2-bgp.sh evidence lab01
./scripts/mission-act2-bgp.sh connect r1
```

Inside `vtysh`, inspect `show bgp summary`, `show ip bgp`, and `show running-config`. A session in Active usually points to peer reachability, neighbor IP, or `remote-as` mismatch. Compare both ends instead of changing one value at random.

## Report a reproducible problem

If the issue remains, [open a GitHub issue](https://github.com/azz-kikkr/intro-to-networking-labs/issues) with:

- operating system and version
- `uname -a` output for Linux or WSL2
- runner version
- the exact command and complete `[FAIL]` output
- whether the relevant `doctor` passed
- the timestamped evidence directory or non-sensitive files from it

Do not attach production packet captures, credentials, tokens, or unrelated host configuration.
