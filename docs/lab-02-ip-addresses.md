# Lab 02: IP Addresses, Proven

Turn address and prefix notation into a connected kernel route and an observable IPv4 header.

## Predict

Write the expected kernel state and packet sequence before running the capture. A correct prediction is useful, but the result must be supported by evidence.

## Build

```bash
sudo ./scripts/mission-act1-labs.sh lab02 build
```

## Inspect

```bash
sudo ./scripts/mission-act1-labs.sh lab02 inspect
```

## Capture

```bash
sudo ./scripts/mission-act1-labs.sh lab02 capture
```

## Evidence checkpoint

Confirm 192.0.2.10 and 192.0.2.20 are inside 192.0.2.0/26, then match the PCAP source and destination to kernel state.

The timestamped result directory is the hand-in artifact. Keep the PCAP, readable packet summary and relevant kernel state together.

## Cleanup

```bash
sudo ./scripts/mission-act1-labs.sh lab02 destroy
```
