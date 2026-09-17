#!/usr/bin/env bash
echo Pulling latest changes
git pull

echo Killing LibreOffice
sudo killall soffice.bin || true

echo Deploying system
sudo nixos-rebuild switch --flake .#nixos-ssds --option extra-experimental-features "nix-command flakes"

echo restarting main script
sudo kill $(pgrep -f presentation.sh)
