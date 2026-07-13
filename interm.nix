# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running `nixos-help`).

{ config, pkgs, lib, ... }:
let
  # Raspberry pi harware overlays
  nixos-hardware = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixos-hardware/archive/80d98a7d55c6e27954a166cb583a41325e9512d7.zip";
    sha256 = "sha256:10017wi78lk746m16ca76dbywdzq495f65vxmav012slipzh7zxh";
  }; 
  # Sops secret management
  sops-nix = builtins.fetchTarball {
    url = "https://github.com/Mic92/sops-nix/archive/632c3161a6cc24142c8e3f5529f5d81042571165.zip";
    sha256 = "sha256:0lbw6ci3z2ciqnfszk942c3w8drn7qbnhha1bc1praj660x3gkgd";
    # Pinned to release date 28/Oct/2023
  }; 
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      (import "${nixos-hardware}/raspberry-pi/4")
      (import "${sops-nix}/modules/sops")
    ];

  # Secrets control
  sops.defaultSopsFile = ./secrets/secrets.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.secrets.dbert-pass.neededForUsers = true;
  sops.secrets.wifi = {};
  sops.secrets.wayvnc_cfg = {
  };
  
  boot = {
    loader = {
      # Use the extlinux boot loader. (NixOS wants to enable GRUB by default)
      grub.enable = false;
      # Enables the generation of /boot/extlinux/extlinux.conf
      generic-extlinux-compatible.enable = true;
    };
    plymouth.enable = false;
  };

  networking = {
    hostName = "nixos-ssds"; # Define your hostname.
    wireless = {
      secretsFile = config.sops.secrets."wifi".path;
      enable = true;  # Enables wireless support via wpa_supplicant.
      networks = {
        "sd73-staff" = {
          pskRaw = "ext:psk";
        };
      };
    };
  };

  # Raspberry Pi 4b hardware settings
  hardware = {
    raspberry-pi."4".apply-overlays-dtmerge.enable = true;
    deviceTree.enable = true;
    #raspberry-pi."4".fkms-3d.enable = true;
    opengl = {
      enable = true;
      package = pkgs.mesa;
    };
  };

  # Reduce overhead of journald a little 
  services.journald.extraConfig = ''
    SystemMaxFileSize=50M
    Storage=volatile
  '';

  # Set time zone.
  time.timeZone = "America/Vancouver";

  # Define a user accounts. 
  users.users.dbert = {
    isNormalUser = true;
    passwordFile = config.sops.secrets.dbert-pass.path;
    extraGroups = [ "wheel" ];
  };

  # packages installed in system profile.
  environment.systemPackages = with pkgs; [
    vim 
    git
    htop
    libraspberrypi
    raspberrypi-eeprom
    killall
  ];
 
  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # 5900 - VNC
  networking.firewall.allowedTCPPorts = [ 5900 ];

  system.stateVersion = "23.05"; # Required 
}
