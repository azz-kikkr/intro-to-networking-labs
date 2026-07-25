# Troubleshooting

## Doctor cannot create a namespace

Confirm that you are inside WSL2 Ubuntu or Linux and that the command uses `sudo`. Do not continue until `doctor` passes.

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