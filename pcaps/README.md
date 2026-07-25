# PCAP exercises

The repository does not ship unexplained packet captures. Each lab generates a bounded PCAP from a known local topology and saves the exact stimulus beside it.

| Lab | Generated capture | What to prove |
|---|---|---|
| 01 | `browser-to-wire.pcap` | ARP precedes TCP, and TCP precedes HTTP |
| 02 | `ipv4-header.pcap` | The source, destination and protocol match kernel state |
| 03 | `left-link.pcap` and `right-link.pcap` | IP endpoints persist while Ethernet changes at the router |
| 04 | `ethernet-frames.pcap` | A witness receives broadcast and unknown unicast |
| 05 | `arp-request-reply.pcap` | Broadcast request becomes a unicast reply and cache entry |
| 06 | scenario captures under `results/` | VLAN, FDB, STP and failover claims have packet or kernel evidence |

Never upload a capture that may contain personal browsing traffic, cookies, tokens or private addresses. The supplied labs avoid that risk by generating traffic inside isolated namespaces.