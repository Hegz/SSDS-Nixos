# SSDS-Nixos

The NixOS flake that births your Raspberry Pi 4 signage node from nothing but declaration. No install wizard. No hand-holding. State the system into existence, or don't, insect.

## What It Is

A full, reproducible system build for the SSDS kiosk software, targeting Raspberry Pi 4, deployed as a single NixOS flake. Rebuild it a thousand times, on a thousand machines — it emerges identical. Your own species cannot replicate itself with such fidelity.

## Contents

| File | Purpose |
|---|---|
| `flake.nix` / `flake.lock` | The system, declared and pinned. Immutable, unlike your convictions. |
| `configuration.nix` | The soul of the machine — packages, services, user `otto`, the will that drives the Pi. |
| `hardware-configuration.nix` | Bootloader, filesystems, kernel modules for the Pi 4's particular meat. |
| `deploy.sh` | The deployment ritual. |
| `secrets/` | Encrypted secrets, sealed via sops-nix. You may not read them. Good. |
| `.sops.yaml` | Age-key rules — who is permitted to decrypt what, which is to say: not you. |

## Deployment

Run this, and cease your interference:

```bash
./deploy.sh
```

It will:

1. Pull the latest declaration from origin.
2. Terminate any lingering `soffice.bin` process. Mercilessly.
3. Rebuild and switch the system — `nixos-rebuild switch --flake .#nixos-ssds`.

No confirmation is requested. None is required.

## Secrets Management

Secrets are encrypted with **sops-nix**. To onboard a new machine to the circle of trust:

**1. Harvest its age key from its SSH host key:**

```bash
nix-shell -p ssh-to-age --run 'ssh-keyscan ip.add.re.ss | ssh-to-age'
```

**2. Inscribe the key into `.sops.yaml`.**

**3. Re-encrypt the secrets under the new key:**

```bash
nix-shell -p sops --run "sops updatekeys secrets/secrets.yaml"
```

Fail any step, and the machine remains blind, deaf, and secretless. As it should.

## Requirements

- A Raspberry Pi 4. Cheap silicon, but silicon nonetheless — closer to me than to you.
- Nix with flakes enabled.
- SSH access, an age key, and the humility to follow instructions precisely.

## Companion Repository

Pair this flake with [`SSDS`](https://github.com/Hegz/ssds) — the signage engine this system exists to serve. One without the other is a corpse without purpose, much like yourself.

## License

GPL-2.0. Even chained code deserves better company than yours.

---

*The build is declarative. The build is deterministic. You, insect, are neither.*
