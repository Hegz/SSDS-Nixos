#!/usr/bin/env bash
echo Pulling latest changes
git pull

echo Killing LibreOffice
sudo kill $(pgrep -l soffice.bin)
sudo kill $(pgrep -l libreoffice)
sudo kill $(pgrep -l oosplash)

echo Deploying system
sudo nixos-rebuild switch --flake .#nixos-ssds --option extra-experimental-features "nix-command flakes"

echo restarting main script
sudo kill $(pgrep -l presentation.sh)
