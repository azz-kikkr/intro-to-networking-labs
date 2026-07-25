# Start here

Use WSL2 Ubuntu or a disposable Linux VM. Read every command before running it. The scripts require `sudo` because Linux restricts namespace, veth and bridge creation.

## Safety boundary

- every created network resource begins with `mls1`
- traffic remains inside endpoint namespaces
- captures have packet and time limits
- background processes are tracked by exact PID
- cleanup targets only the selected lab
- evidence remains under `results/`
- no physical interface, host default route, host firewall or WSL external interface is changed

## Prepare

```bash
cp /mnt/c/Users/YOUR-WINDOWS-USER/Downloads/mission-act1-labs.sh ~/
cd ~
chmod +x mission-act1-labs.sh
sudo ./mission-act1-labs.sh lab01 install
sudo ./mission-act1-labs.sh lab01 doctor
```

Run `doctor` again after fixing any failed check. Static syntax checks do not prove privileged kernel feasibility.

## Open a PCAP in Wireshark

From Windows Explorer, enter `\\wsl$` and browse to the Linux directory containing `results`. Open the `.pcap` directly or copy it into a Windows working folder.

Useful Wireshark display filters:

```text
arp
tcp.port == 8080
icmp
eth.dst == ff:ff:ff:ff:ff:ff
```

## Recovery

Each lab supports exact cleanup:

```bash
sudo ./mission-act1-labs.sh lab04 destroy
sudo ./mission-layer2-capstone.sh destroy
```