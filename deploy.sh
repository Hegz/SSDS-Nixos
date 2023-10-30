#!/usr/bin/env bash

echo Linking configuration files in to place
sudo rm /etc/nixos/configuration.nix
sudo ln -s /home/dbert/SSDS-Nixos/configuration.nix /etc/nixos/configuration.nix

sudo rm /etc/nixos/hardware-configuration.nix
sudo ln -s /home/dbert/SSDS-Nixos/hardware-configuration.nix /etc/nixos/hardware-configuration.nix

echo Precreating secrets
sudo mkdir /run/secrets/
sudo touch /run/secrets/ssh_key

echo Deploying system
sudo nixos-rebuild switch
