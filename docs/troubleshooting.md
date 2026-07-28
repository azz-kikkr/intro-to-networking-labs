# Troubleshooting

## Doctor cannot create a namespace

Confirm that you are on native Ubuntu or inside WSL2 Ubuntu, and that the command uses `sudo`. Do not continue until `doctor` passes.

## A capture contains zero packets

Confirm the selected lab is built, use its `capture` command and read the adjacent `tcpdump.log`. The runner starts the bounded capture before generating traffic.

## Wireshark cannot open the file

Read it first inside Linux:

```bash
tcpdump -nn -r results/TIMESTAMP-LAB/file.pcap
```

## A lab already exists

Run only its exact cleanup command, then build it again. Never delete arbitrary namespaces or interfaces by process name.

## Lab 06 takes time to converge

The capstone uses Linux kernel STP with shortened classroom timers. Use its bounded status commands and read the expected port state before beginning a failure scenario.

## Lab 06 build fails with a netlink range error

`RTNETLINK answers: Numerical result out of range` means the bridge timers were sent in the wrong unit. `ip link set ... type bridge` expects `forward_delay`, `hello_time`, `max_age` and `ageing_time` in hundredths of a second. Runner 1.1.0 sends `400`, `100`, `600` and `12000`.

## Docker is installed on the lab host

Docker loads `br_netfilter` and sets the host packet filter's `FORWARD` policy to `DROP`. Bridged IPv4 traffic in these labs is then dropped with no error message anywhere. `doctor` reports this as a `[CHECK]`.

**Use a clean Ubuntu VM with Docker not installed.** Stopping the Docker service is not sufficient: the `FORWARD` policy it set stays in place and the `br_netfilter` module stays loaded after the daemon exits. The lab scripts will never modify your host packet filter or unload kernel modules to work around this, because a teaching lab has no business changing the security posture of a learner's machine.
