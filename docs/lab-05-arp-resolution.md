# Lab 05: ARP, Request to Resolution

Observe an empty neighbor table become a verified IP-to-MAC mapping.

## Predict

Write the expected kernel state and packet sequence before running the capture. A correct prediction is useful, but the result must be supported by evidence.

## Build

```bash
sudo ./scripts/mission-act1-labs.sh lab05 build
```

## Inspect

```bash
sudo ./scripts/mission-act1-labs.sh lab05 flush
```

## Capture

```bash
sudo ./scripts/mission-act1-labs.sh lab05 capture
```

## Evidence checkpoint

Show that the request uses Ethernet broadcast and the reply identifies 02:00:00:05:00:20, then find the same mapping in the neighbor cache.

The timestamped result directory is the hand-in artifact. Keep the PCAP, readable packet summary and relevant kernel state together.

## Cleanup

```bash
sudo ./scripts/mission-act1-labs.sh lab05 destroy
```
