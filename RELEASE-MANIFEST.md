# Mission Labs 1.1.4 release manifest

Mission Labs 1.1.4 is a runtime portability and course-readiness repair built on 1.1.3. It keeps the learner security boundary unchanged.

## Git objects

| File | Git object |
|---|---|
| `scripts/mission-act1-labs.sh` | `d08925b4747c2f3db8d46288642645e34d9d27ed` |
| `scripts/mission-layer2-capstone.sh` | `65b0e1629da49bebc58311e79fadd1b54438f101` |
| `tests/smoke.sh` | `94b585b10caf6894a0488cdc17bd9c2d0c789dd9` |
| `tests/acceptance.sh` | `fdc5af427d051550f6fe3b86364480ca421b4fd5` |

## SHA-256

```text
6b4f159219f0afec1f30885db47d55cd9c0f370d3590532336ec2ad3b07a50f0  scripts/mission-act1-labs.sh
25bffefd9678685f3a11523c70e8fe94b43743dee2ab1b23bbf7925f369200d1  scripts/mission-layer2-capstone.sh
5a3fc487138fa5e3a5d362d547e3162881a5de533556857c2e25f25a00b4d324  tests/smoke.sh
52b034ba6a423c89a5a16bab7e0c4c1ed524ae6816e22b93f2fc00b7ce29fef2  tests/acceptance.sh
```

## Release gate

The release is valid only when the static job and both privileged Ubuntu runtime jobs pass. Each runtime must end with `failed 0, skipped 0` and no remaining `mls1` objects.