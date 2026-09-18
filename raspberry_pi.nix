{ config, pkgs, lib, ... }:
{
  boot = {
    loader = {
      # Use the extlinux boot loader. (NixOS wants to enable GRUB by default)
      grub.enable = false;
      # Enables the generation of /boot/extlinux/extlinux.conf
      generic-extlinux-compatible.enable = true;
    };
    plymouth.enable = false;
    kernelPackages = pkgs.linuxPackages;
  };

  # Raspberry Pi 4b hardware settings
  hardware = {
    raspberry-pi."4".apply-overlays-dtmerge.enable = true;
    deviceTree.enable = true;
    graphics.enable = true;
    raspberry-pi.configtxt = {
      settings = {
        gpu_mem = 256;
      };
    };
  };

  # Needed to allow building of Guac
  nixpkgs.config.allowUnsupportedSystem = true;

  # CEC related configuration
  nixpkgs.overlays = [
    (self: super: { libcec = super.libcec.override { withLibraspberrypi = true; }; })
  ];

  services.udev.extraRules = ''
    # allow access to raspi cec device for video group (and optionally register it as a systemd device, used below)
    SUBSYSTEM=="vchiq", GROUP="video", MODE="0660", TAG+="systemd", ENV{SYSTEMD_ALIAS}="/dev/vchiq"
  '';

  # Send a single CEC command to logical address 0 (the TV) and quit.
  # "on 0"      -> power the display on
  # "standby 0" -> power the display off
  systemd.services = {
    tv-power-on = {
      description = "CEC: power on the TV";
      serviceConfig.Type = "oneshot";
      script = ''
        echo "on 0" | ${pkgs.libcec}/bin/cec-client -s -d 1
      '';
    };
    tv-power-off = {
      description = "CEC: power off the TV";
      serviceConfig.Type = "oneshot";
      script = ''
        echo "standby 0" | ${pkgs.libcec}/bin/cec-client -s -d 1
      '';
    };
  };

  systemd.timers = {
    tv-power-on = {
      description = "Schedule: power on the TV";
      wantedBy = [ "timers.target" ];
      timerConfig.OnCalendar = "07:00"; # adjust to taste
    };
    tv-power-off = {
      description = "Schedule: power off the TV";
      wantedBy = [ "timers.target" ];
      timerConfig.OnCalendar = "18:00"; # adjust to taste
    };
  };

}
