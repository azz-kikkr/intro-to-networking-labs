# Lab 01: Browser to Wire

Connect browser DevTools timing to an isolated ARP, TCP and HTTP capture.

## Predict

Write the expected kernel state and packet sequence before running the capture. A correct prediction is useful, but the result must be supported by evidence.

## Build

```bash
sudo ./scripts/mission-act1-labs.sh lab01 build
```

## Inspect

```bash
sudo ./scripts/mission-act1-labs.sh lab01 verify
```

## Capture

```bash
sudo ./scripts/mission-act1-labs.sh lab01 capture
```

## Evidence checkpoint

Locate ARP request and reply, TCP SYN, SYN-ACK and ACK, then the HTTP request and response. Compare that order with the browser Network timing phases.

The timestamped result directory is the hand-in artifact. Keep the PCAP, readable packet summary and relevant kernel state together.

## Cleanup

```bash
sudo ./scripts/mission-act1-labs.sh lab01 destroy
```
