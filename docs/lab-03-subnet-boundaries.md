# Lab 03: Subnet boundaries

**Level:** L2 investigation<br>
**Time:** 40 minutes<br>
**Question:** What changes and what survives when a router forwards a packet?

## Topology

```text
left /26 -- router namespace -- right /26
```

Before running, predict the destination MAC on each link and whether the source/destination IP addresses change.

```bash
sudo ./scripts/mission-act1-labs.sh lab03 build
sudo ./scripts/mission-act1-labs.sh lab03 verify
sudo ./scripts/mission-act1-labs.sh lab03 capture
```

Compare `left-link.pcap` and `right-link.pcap` using `icmp`. Record Ethernet source and destination, IP source and destination, and TTL on the same echo request. The router should replace Layer 2 headers and decrement TTL while preserving the end-to-end IP addresses. The route files explain why forwarding was possible.

Expected result: two different Ethernet conversations carry one Layer 3 conversation. Ping confirms reachability but the paired captures prove header transformation.

Done when you can explain why a remote IP is sent to a local gateway MAC.

## Study links

- [RFC 1812: Requirements for IPv4 routers](https://datatracker.ietf.org/doc/html/rfc1812#section-5.2) walks through forwarding and next-hop selection.
- [RFC 1812: Time to Live](https://datatracker.ietf.org/doc/html/rfc1812#section-5.3.1) explains the TTL change you compare across links.
- [`ip-route(8)`](https://man7.org/linux/man-pages/man8/ip-route.8.html) is the reference for Linux route lookup and route types.

```bash
sudo ./scripts/mission-act1-labs.sh lab03 destroy
```