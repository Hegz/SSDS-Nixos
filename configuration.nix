# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running `nixos-help`).
#
# This file only wires together the split-out modules below. Each
# module owns one concern; see the individual files for details.
{ config, gitRev, gitShortRev, gitDate, pkgs, lib, ... }:
{
  imports = [
    ./guacamole.nix
    ./otto.nix
    ./raspberry_pi.nix
    ./secrets.nix
  ];
  
  networking = {
    hostName = "nixos-ssds";
    wireless = {
      enable = true;
      secretsFile = config.sops.secrets."wifi".path;
      networks = {
        "sd73-staff" = {
          pskRaw = "ext:psk";
        };
      };
    };
    # Allow ports for Guacamole
    firewall.allowedTCPPorts = [ 80 443 ];
  };

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  
  # enable access to sops protected key files.
  services.openssh.settings.AuthorizedKeysFile = ".ssh/authorized_keys /run/secrets/ssh-authorized-keys-%u";

  environment.variables = {
    # Forces Mesa to scale back aggressive multi-threading
    "mesa_glthread" = "false";

    # Prevents wlroots from trying to grab hardware cursors,
    # which often triggers the vc4-drm 'commit wait timed out' bug
    "WLR_NO_HARDWARE_CURSORS" = "1";

    # Prevents LibreOffice from trying to use complex OpenGL transitions
    # that can freeze the vc4 GPU pipeline over time
    "SAL_DISABLE_GL" = "1";
  };
  
  environment.etc."wireplumber/main.lua.d/90-suspend-timeout.conf" = {
  text = ''
    wireplumber.settings = {
      "session.suspend-timeout-seconds" = 0
    }
    '';
  };
 
  # Records the commit hash this generation was built from. Surfaced by
  # `nixos-version --json` as "configurationRevision" -- compare across
  # days to see whether the last auto-upgrade run actually changed anything.
  system.configurationRevision = gitRev;

  users.motd = ''
    Welcom to Super Simple Digital Signage
    
    Current version: 
    NixOS ${config.system.nixos.label}
    Build:  ${gitShortRev}  (${gitDate})
  '';
  
  # Packages installed in system profile.
  environment.systemPackages = with pkgs; [
	git
	htop
	killall
	libcec
	libraspberrypi
	raspberrypi-eeprom
	vim
	wayvnc
  ];

  # Reduce overhead of journald a little
  services.journald.extraConfig = ''
    Storage=persistent
    Compress=yes
    SystemMaxUse=50M
    SystemMaxFileSize=10M
    SystemMaxFiles=5
  '';

  # Set time zone.
  time.timeZone = "America/Vancouver";

  # Enable Sway window manager
  programs.sway.enable = true;

  # Enable user autologin and sway startup
  services.getty.autologinUser = "otto";
  environment.loginShellInit = ''
    [[ "$(tty)" == /dev/tty1 ]] && WLR_LIBINPUT_NO_DEVICES=1 sway
  '';

  # Define administrator account
  users.users.dbert = {
    isNormalUser = true;
    hashedPasswordFile = config.sops.secrets.dbert-pass.path;
    extraGroups = [ "wheel" ];
  };

  # Flakes are required for the auto-upgrade below. Harmless if already
  # enabled elsewhere (e.g. in flake.nix's nixConfig).
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Pull and apply the latest commit on the tracked branch daily. Point
  # this at your actual system flake repo/hostname -- "Hegz/SSDS-nixos"
  # is a guess based on your shell prompt earlier in this conversation,
  # not a confirmed fact, so verify it before relying on this.
  system.autoUpgrade = {
	enable = true;
	flake = "github:Hegz/SSDS-nixos#nixos-ssds";
	dates = "04:00";
	operation = "switch";
    flags = [ "--refresh" ];
  };

  system.stateVersion = "23.05"; # Required

}
