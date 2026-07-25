# Start here

## Goal

Finish Act 1 with six evidence folders you can inspect, explain, and share screenshots from. Budget about four hours total.

## Safety boundary

Every created resource starts with `mls1`. Traffic stays inside network namespaces. Captures have time and packet limits. Background processes are tracked by exact PID. Cleanup targets only known lab objects. No physical interface, external WSL link, host route, or firewall is changed.

## Prepare

```bash
git clone https://github.com/azz-kikkr/intro-to-networking-labs.git
cd intro-to-networking-labs
chmod +x scripts/*.sh
./scripts/mission-act1-labs.sh --version
sudo ./scripts/mission-act1-labs.sh lab01 install
sudo ./scripts/mission-act1-labs.sh lab01 doctor
```

`doctor` is a privileged feasibility check. A syntax check alone cannot prove that namespaces, veth pairs, bridges, and packet capture work on your kernel.

## The loop for Labs 1 to 5

Replace `lab01` with the current lab number.

```bash
sudo ./scripts/mission-act1-labs.sh lab01 build
sudo ./scripts/mission-act1-labs.sh lab01 verify
sudo ./scripts/mission-act1-labs.sh lab01 capture
sudo ./scripts/mission-act1-labs.sh lab01 destroy
```

A command that exits nonzero did not pass. Read the `[FAIL]` message, use [Troubleshooting](troubleshooting.md), and do not treat ping alone as proof.

## Read a PCAP

```bash
tcpdump -nn -e -r results/TIMESTAMP-lab01/browser-to-wire.pcap
```

In Wireshark, open the same file through `\\wsl$`. Useful display filters are `arp`, `tcp.port == 8080`, `icmp`, and `eth.dst == ff:ff:ff:ff:ff:ff`.

## Before every lab

Write one prediction. Afterward, cite one kernel-state file and one packet or frame field. End with one sentence stating what the evidence cannot prove.