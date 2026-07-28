# Layer 2 capstone readiness

Complete this primer before Lab 06. The capstone assumes you can explain all three decisions below before you inspect Linux state.

## 1. Learning and flooding

A bridge learns the source MAC address of an arriving frame. It records the ingress port in its forwarding database. A known unicast follows one learned port. An unknown unicast floods to other forwarding ports in the same VLAN.

```bash
bridge fdb show
```

Readiness check: explain why a witness can see an unknown unicast even though its MAC address is not the destination.

## 2. Access ports, trunks and PVIDs

An access port accepts an untagged endpoint frame and assigns it to its PVID. A trunk carries selected VLANs between bridges. VLAN membership is a Layer 2 boundary and does not require a router to prove isolation.

```bash
bridge vlan show
```

Readiness check: identify the PVID for each endpoint and the allowed VLANs on every trunk.

## 3. STP root, cost and failover

STP selects one root bridge, calculates a least-cost path toward it and blocks redundant forwarding paths. A blocked link remains physically up. When an active link fails, STP can converge on the stored redundant path.

```bash
bridge link show
ip -d -j link show dev BRIDGE_NAME
```

Readiness check: predict the root, one blocked port and the path that should activate after a link failure.

## Evidence rubric

For each claim, record:

1. your prediction
2. the exact command or capture point
3. the kernel state or PCAP field that proves the claim
4. one limitation of that evidence

Ping can support a claim, but reachability alone does not prove VLAN membership, FDB behavior or the active STP path.