#!/usr/bin/env bash
echo Pulling latest changes
git pull

echo Linking configuration files in to place
sudo rm /etc/nixos/configuration.nix
sudo ln -s $(pwd)/configuration.nix /etc/nixos/configuration.nix

echo Linking hardware configuration files in to place
sudo rm /etc/nixos/hardware-configuration.nix
sudo ln -s $(pwd)/hardware-configuration.nix /etc/nixos/hardware-configuration.nix

echo Killing LibreOffice
killall soffice.bin

echo Deploying system
sudo nixos-rebuild switch
