#!/usr/bin/env bash

echo Linking configuration files in to place
sudo rm /etc/nixos/configuration.nix
sudo ln -s $(pwd)/SSDS-Nixos/configuration.nix /etc/nixos/configuration.nix

sudo rm /etc/nixos/hardware-configuration.nix
sudo ln -s $(pwd)/SSDS-Nixos/hardware-configuration.nix /etc/nixos/hardware-configuration.nix

echo Deploying system
sudo nixos-rebuild switch
