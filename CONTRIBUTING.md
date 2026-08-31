# Contributing

Thanks for helping improve Networking Zero to Hero Labs. Contributions should make the course safer, clearer, more reproducible, or more useful to a learner.

## Before you begin

- Open an issue before proposing a new lab, dependency, platform, or change to the safety boundary.
- Keep each pull request focused on one problem.
- Preserve the evidence-first loop: predict, build, verify, capture, explain, destroy.
- Do not commit generated `results/`, packet captures from real networks, credentials, or personal data.

## Course scope

The current learning path covers:

- browser request anatomy, IPv4 addressing, subnetting, Ethernet, ARP, switching, VLANs, FDB learning, and STP
- Layer 3 routing beginning with containerized FRRouting and eBGP
- local evidence from Linux kernel state, packet captures, routing tables, and router configurations

New material should fit the progression and identify its prerequisite lab. Prefer one bounded network question over a broad technology tour.

## Learner-facing documentation

Every lab guide should include:

- level, estimated time, and one core question
- two or three measurable learning objectives
- a topology diagram and an accessible text description
- a prediction before commands are run
- exact build, verification, evidence, and cleanup commands
- expected observations without giving away the learner's entire explanation
- a `Done when` statement and primary study links
- previous, course-home, and next navigation

Use short sentences and define an acronym on first use. Keep commands copyable. Avoid em dashes in learner-facing copy.

## Shell and runtime requirements

Every shell change must:

- use `set -Eeuo pipefail`
- quote variables
- use the existing `mls1` or `mls1-bgp` resource prefixes
- keep traffic inside the declared lab topology
- bound captures, retries, and polling
- track exact process IDs
- fail explicitly when an asserted observation is absent
- clean up only exact resources created by the runner
- save reproducible evidence under `results/`

Do not add host firewall changes, broad process-name killing, telemetry, accounts, SaaS dependencies, vendor-only services, or arbitrary privileged execution.

## Validate your change

Run the static checks:

```bash
bash -n scripts/*.sh tests/*.sh
shellcheck -x scripts/*.sh tests/*.sh
LC_ALL=C bash tests/acceptance.sh
LC_ALL=C.UTF-8 bash tests/acceptance.sh
bash tests/act2-acceptance.sh
```

Then run the relevant real environment gate:

```bash
# Act 1 on a disposable Ubuntu host
sudo bash tests/smoke.sh

# Act 2 on a Docker host
bash tests/act2-smoke.sh
```

A static pass does not replace a privileged Ubuntu or Docker smoke test when the change affects runtime behavior.

## Pull request checklist

In the pull request, state:

- what learner problem the change solves
- which documented commands you ran
- operating system, kernel, and Docker versions where relevant
- which privileged or container labs ran successfully
- whether cleanup left any `mls1` resources behind
- any check you could not run and why

By contributing code, you agree that it is licensed under MIT. By contributing course text or diagrams, you agree that it is licensed under CC BY 4.0.
