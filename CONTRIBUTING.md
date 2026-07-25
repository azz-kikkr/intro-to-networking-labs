# Contributing

Keep proposed changes inside the Act 1 scope: browser request anatomy, IPv4 addressing, subnetting, Ethernet, ARP and switching.

Every shell change must:

- use `set -Eeuo pipefail`
- quote variables
- use `mls1`-prefixed resources
- keep traffic inside endpoint namespaces
- bound captures and polling
- track exact PIDs
- clean up only exact resources
- save evidence under `results/`
- avoid em dashes in learner-facing copy

A static check is necessary but does not replace a privileged WSL2 smoke test. Include the tested Ubuntu and kernel versions in the pull request.