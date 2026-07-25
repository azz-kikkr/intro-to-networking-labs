# Lab 04: Ethernet Frames on a Real Wire

Prove source learning, known unicast, broadcast and unknown-unicast flooding with a witness endpoint.

## Predict

Write the expected kernel state and packet sequence before running the capture. A correct prediction is useful, but the result must be supported by evidence.

## Build

```bash
sudo ./scripts/mission-act1-labs.sh lab04 build
```

## Inspect

```bash
sudo ./scripts/mission-act1-labs.sh lab04 verify
```

## Capture

```bash
sudo ./scripts/mission-act1-labs.sh lab04 capture
```

## Evidence checkpoint

Find EtherType 0x88b5 and the MISSION-L2-UNKNOWN payload on the witness capture, then match learned source MAC addresses to the bridge FDB.

The timestamped result directory is the hand-in artifact. Keep the PCAP, readable packet summary and relevant kernel state together.

## Cleanup

```bash
sudo ./scripts/mission-act1-labs.sh lab04 destroy
```
