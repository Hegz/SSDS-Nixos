# SSDS-Nixos

A NixOS flake that builds Raspberry Pi 4 signage nodes for [SSDS](https://github.com/Hegz/ssds) kiosk software. The whole system is declared in Nix; every rebuild produces an identical machine.

## What It Is

A complete, reproducible NixOS build for the SSDS kiosk, targeting Raspberry Pi 4, deployed as a single NixOS flake. Rebuild it any number of times, on any number of machines, and you get the same result.

## Contents

| File | Purpose |
|---|---|
| `flake.nix` / `flake.lock` | Flake entry point; all inputs pinned. |
| `configuration.nix` | System configuration: packages, services, home-manager profile for user `otto`. |
| `hardware-configuration.nix` | Bootloader, filesystem layout, and kernel modules for Raspberry Pi 4. |
| `secrets/` | Secrets encrypted with sops-nix. |
| `.sops.yaml` | Age key rules used when re-encrypting secrets on a trusted workstation. Not part of the build. |

## Deployment

Flash a base NixOS image to the Pi, Follow the secret management then run:

```bash
sudo nixos-rebuild switch --flake github:Hegz/SSDS-nixos#nixos-ssds --refresh --option extra-experimental-features "nix-command flakes"
```

This works for initial deployment and for updates alike. It fetches the latest commit from GitHub, rebuilds the system, and switches over without prompting. Before running it, make sure your changes are pushed to GitHub — the node builds from the remote, not from any local checkout. If LibreOffice is running on the node, stop its processes (for example `pkill -f soffice.bin`) before the rebuild.

The node reads its secrets by decrypting them with its own SSH host key (`/etc/ssh/ssh_host_ed25519_key`). Complete the [Secrets Management](#secrets-management) steps before the first successful switch so that this key is accepted by the encrypted blob; otherwise the build fails at secret decryption.

## Secrets Management

Secrets are encrypted with **sops-nix**. To onboard a new machine to the trust group:

**1. Harvest its age key from its SSH host key:**

```bash
nix-shell -p ssh-to-age --run 'ssh-keyscan ip.add.re.ss | ssh-to-age'
```

**2. Inscribe the key into `.sops.yaml` on a trusted workstation.**

**3. Re-encrypt the secrets under the new key:**

```bash
nix-shell -p sops --run "sops updatekeys secrets/secrets.yaml"
```

Commit and push the resulting `secrets/secrets.yaml`, then run the deployment command on the node. Until all three steps above have succeeded, the node cannot decrypt its secrets.

## Requirements

- A Raspberry Pi 4
- Nix with flakes enabled
- A workstation with git access to this repository (for the onboarding steps) and SSH access to the node

## Companion Repository

Pair this flake with [SSDS](https://github.com/Hegz/ssds), the signage engine this system exists to serve. One without the other won't work.

## License

GPL-2.0.
