Get target Key:

nix-shell -p ssh-to-age --run 'ssh-keyscan ip.add.re.ss | ssh-to-age'

Add to .sops.yaml

Update secrets: 
nix-shell -p sops --run "sops updatekeys secrets/secrets.yaml"

Update Repo
