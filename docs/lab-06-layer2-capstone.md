# Lab 06: Layer 2 Capstone

Build a four-switch campus fabric and prove STP election, port roles, VLAN access and trunk state, FDB learning, flooding, MAC movement and failover.

## Build

```bash
chmod +x scripts/mission-layer2-capstone.sh
sudo ./scripts/mission-layer2-capstone.sh install
sudo ./scripts/mission-layer2-capstone.sh doctor
sudo ./scripts/mission-layer2-capstone.sh build
```

## Baseline evidence

```bash
sudo ./scripts/mission-layer2-capstone.sh verify
sudo ./scripts/mission-layer2-capstone.sh report
```

Do not begin a failure investigation until the baseline passes. The report writes timestamped kernel and packet evidence under `results/`.

## Investigation method

For every scenario:

1. Predict the forwarding impact.
2. Record baseline physical, STP, VLAN and FDB state.
3. Apply one bounded fault.
4. Generate bounded endpoint traffic.
5. Capture the affected link or witness.
6. Compare expected and observed state.
7. Restore the baseline and verify it again.

## Cleanup

```bash
sudo ./scripts/mission-layer2-capstone.sh destroy
```