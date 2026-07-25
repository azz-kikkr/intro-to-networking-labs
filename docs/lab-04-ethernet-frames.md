# Lab 04: Ethernet frames

**Level:** L2 investigation<br>
**Time:** 40 minutes<br>
**Question:** Which frames does a switch deliver beyond the intended receiver?

## Topology

```text
sender -- mls1 bridge -- receiver
                 |
              witness
```

Predict what the witness sees for known unicast, broadcast, and unknown unicast.

```bash
sudo ./scripts/mission-act1-labs.sh lab04 build
sudo ./scripts/mission-act1-labs.sh lab04 verify
sudo ./scripts/mission-act1-labs.sh lab04 capture
```

Open `ethernet-frames.pcap`. Filters: `eth.dst == ff:ff:ff:ff:ff:ff` for broadcast and `eth.dst == 02:00:00:de:ad:04` for the marked unknown destination. Inspect destination MAC, source MAC, EtherType or length, and payload bytes. Compare with `fdb.txt`.

Expected result: the witness receives broadcast and an unknown destination because the bridge floods them. A learned unicast is forwarded only toward the learned port.

Challenge: explain why flooding is forwarding behavior, not evidence that the bridge is a hub.

## Study links

- [Linux kernel Ethernet bridging](https://docs.kernel.org/networking/bridge.html) describes the bridge, forwarding database, STP, and VLAN model used by the lab.
- [`bridge(8)`](https://man7.org/linux/man-pages/man8/bridge.8.html) documents the commands used to inspect FDB and port state.
- [Wireshark Ethernet field reference](https://www.wireshark.org/docs/dfref/e/eth.html) lists the Ethernet fields available for frame analysis.

```bash
sudo ./scripts/mission-act1-labs.sh lab04 destroy
```