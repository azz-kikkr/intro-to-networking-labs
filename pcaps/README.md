# Packet captures

The runners generate sanitized captures locally under timestamped `results/` directories. Lab addresses use the documentation ranges `192.0.2.0/24`, `198.51.100.0/24`, and `203.0.113.0/24`, or private lab-only ranges. MAC addresses are synthetic. No production traffic, credentials, cookies, or personal identifiers are captured.

Each evidence directory includes `manifest.txt` with SHA-256 hashes. Release assets may include a curated `act1-reference-pcaps` archive generated only from the isolated `mls1` topologies.

Open a capture with:

```bash
tcpdump -nn -e -r FILE.pcap
```

Or use Wireshark and the filters listed in each lab guide.