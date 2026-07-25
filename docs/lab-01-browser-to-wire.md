# Lab 01: Browser to wire

**Level:** L2 guided lab<br>
**Time:** 35 minutes<br>
**Question:** How does a browser request relate to packets on a controlled wire?

## Topology

```text
client namespace -- veth -- mls1 bridge -- veth -- web namespace:8080
```

## Predict

Write the expected order: ARP, TCP handshake, HTTP request, HTTP response. Circle the step DevTools cannot expose as a network frame.

## Build and prove

```bash
sudo ./scripts/mission-act1-labs.sh lab01 build
sudo ./scripts/mission-act1-labs.sh lab01 verify
sudo ./scripts/mission-act1-labs.sh lab01 capture
```

Expected success includes `[PASS] HTTP response verified` and a nonempty `browser-to-wire.pcap`. Open the generated `http-response.txt`, `packets.txt`, and PCAP side by side.

Wireshark filters:

```text
arp
tcp.port == 8080
tcp.flags.syn == 1
http.request
```

Inspect Ethernet source/destination, ARP opcode, TCP SYN/ACK flags, ports, sequence flow, and HTTP status. In Chrome or Edge DevTools, load any normal page and compare the Network panel phases. This is a model comparison, not a claim that DevTools and the lab PCAP contain the same transaction.

## Explain

Which observations belong to the browser, which belong to the kernel, and which exist only on the wire? Why can timings differ between the DevTools example and the controlled capture?

## Done when

You can point to the TCP four-tuple, identify the handshake, cite the HTTP status, and state that this capture proves only the isolated lab transaction.

## Study links

- [Chrome DevTools: Inspect network activity](https://developer.chrome.com/docs/devtools/network/) explains what the browser records and how to inspect request details.
- [RFC 9293: Transmission Control Protocol](https://datatracker.ietf.org/doc/html/rfc9293) is the current TCP specification. Focus on the segment format and connection establishment.
- [Wireshark display filter reference](https://www.wireshark.org/docs/dfref/) lists the fields available for `arp`, `tcp`, and `http` analysis.

## Cleanup

```bash
sudo ./scripts/mission-act1-labs.sh lab01 destroy
```