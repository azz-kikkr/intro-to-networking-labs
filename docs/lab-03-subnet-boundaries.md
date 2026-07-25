# Lab 03: Subnet Boundaries

Route between two adjacent /26 networks and prove the effect of removing one route.

## Predict

Write the expected kernel state and packet sequence before running the capture. A correct prediction is useful, but the result must be supported by evidence.

## Build

```bash
sudo ./scripts/mission-act1-labs.sh lab03 build
```

## Inspect

```bash
sudo ./scripts/mission-act1-labs.sh lab03 verify
```

## Capture

```bash
sudo ./scripts/mission-act1-labs.sh lab03 capture
```

## Evidence checkpoint

Compare the frame on each router interface. The Ethernet envelope changes while the end-to-end IPv4 addresses remain stable.

The timestamped result directory is the hand-in artifact. Keep the PCAP, readable packet summary and relevant kernel state together.

## Cleanup

```bash
sudo ./scripts/mission-act1-labs.sh lab03 destroy
```
