#!/usr/bin/env bash
echo Pulling latest changes
git pull

echo Killing LibreOffice
killall soffice.bin || true

echo Deploying system
sudo nixos-rebuild switch --flake .#nixos-ssds
