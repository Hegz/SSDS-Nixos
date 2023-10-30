#!/usr/bin/env bash
sudo rm /etc/nixos/configuration.nix
sudo ln -s /home/dbert/SSDS-Nixos/configuration.nix /etc/nixos/configuration.nix

sudo rm /etc/nixos/hardware-configuration.nix
sudo ln -s /home/dbert/SSDS-Nixos/hardware-configuration.nix /etc/nixos/hardware-configuration.nix

sudo nixos-rebuild switch
