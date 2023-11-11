# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running `nixos-help`).

{ config, pkgs, lib, ... }:
let
  # Add the home manager channel to the system 
  home-manager = builtins.fetchTarball {
    url = "https://github.com/nix-community/home-manager/archive/release-23.05.tar.gz";
    sha256 = "0rwzab51hnr6cmm1w5zmfh29gbkg6byv8jnr7frcv5kd6m8kna41";
  }; 
  # Raspberry pi harware overlays
  nixos-hardware = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixos-hardware/archive/80d98a7d55c6e27954a166cb583a41325e9512d7.zip";
    sha256 = "sha256:10017wi78lk746m16ca76dbywdzq495f65vxmav012slipzh7zxh";
    # Pinned to release date 23/Oct/2023
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
      (import "${home-manager}/nixos")
      (import "${nixos-hardware}/raspberry-pi/4")
      (import "${sops-nix}/modules/sops")
    ];

  # Secrets control
  sops.defaultSopsFile = ./secrets/secrets.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.secrets.dbert-pass.neededForUsers = true;
  sops.secrets.wifi = {};
  sops.secrets.wayvnc_cfg = {
    owner = config.users.users.otto.name;
  };
  
  boot = {
    loader = {
      # Use the extlinux boot loader. (NixOS wants to enable GRUB by default)
      grub.enable = false;
      # Enables the generation of /boot/extlinux/extlinux.conf
      generic-extlinux-compatible.enable = true;
      raspberryPi.firmwareConfig = ''gpu_mem=192'';
    };
    plymouth.enable = false;
  };

  networking = {
    hostName = "nixos-ssds"; # Define your hostname.
    wireless = {
      environmentFile = config.sops.secrets."wifi".path;
      enable = true;  # Enables wireless support via wpa_supplicant.
      networks = {
        "@essid@" = {
          psk = "@psk@";
        };
      };
    };
  };

  # Raspberry Pi 4b hardware settings
  hardware = {
    raspberry-pi."4".apply-overlays-dtmerge.enable = true;
    deviceTree.enable = true;
    raspberry-pi."4".fkms-3d.enable = true;
    opengl = {
      enable = true;
      setLdLibraryPath = true;
      package = pkgs.mesa_drivers;
    };
  };

  # Reduce overhead of journald a little 
  services.journald.extraConfig = ''
    SystemMaxFileSize=50M
    Storage=volatile
  '';

  # Set time zone.
  time.timeZone = "America/Vancouver";

  # Eable Sway window manager
  programs.sway.enable = true;

  # Enable user autologin and sway startup
  services.getty.autologinUser = "otto";
  environment.loginShellInit = ''
    [[ "$(tty)" == /dev/tty1 ]] && WLR_LIBINPUT_NO_DEVICES=1 sway
    '';

  # Define a user accounts. 
  users.users.dbert = {
    isNormalUser = true;
    passwordFile = config.sops.secrets.dbert-pass.path;
    extraGroups = [ "wheel" ];
  };
  users.users.otto = {
    isNormalUser = true;
    createHome = true;
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAwaF65IvEZtjv5zCxQlCsJ5ThymSwXocfxk3uBaDlFLZXdqVw+KFb83GNwj1UDYsPCEz2RwXjs8XHxrIS72Npm+OKhlR/adbY6Q+Gtx+bM+PDKlHxOzNgYkIVHV0B8RHLVmTMjLwwOXayiolR8WuljvLjLcvRLkx1WgQgwdCuvQvCV99Gfyn9uUH7wcfdPd/SlRqPJ6k6h0J1Z/E+FlBJADxNObwlXpyhAVhlKdepT9Wo62rQfDfXDXawSRjUfDVHZkBnx7c9FH1eralLF8ILjXv1zR7It7juOgW2dtvvLWL15UKClWNfK15EWq/lp0vtR1rzueL9FtoyqKP98YBvlQ== sys-automation@server"
    ];
    packages = with pkgs; [
      libreoffice-still   # Libreoffice for Slides
      imv                 # Image viewer
      libheif             # Explicit HEIF Support
      mpv                 # Video Support
      wayvnc              # VNC Server
      openssl             # To generate Certs for VNC
      killall
      ffmpeg
    ];
  };

  home-manager.users.otto = { pkgs, lib, ... }: {
    # Enable sway managment, and set options
    wayland.windowManager.sway.enable = true;
    wayland.windowManager.sway.config = {
      seat = { "*" = { hide_cursor = "600"; }; };
      output = { "*" = { bg ="~/ssds/School_District_73.jpg fill"; }; };
    };
    # Import the SSDS files from Github.
    home.file."ssds".source = "${pkgs.fetchFromGitHub { 
      owner = "Hegz";
      repo = "SSDS";
      rev = "c314ef785e97f7bbaac3c9f4b1a789dbfd9d2999";
      hash = "sha256-gYXfDIPg3U4+vFZKB4rENqs/jvj4pcPR7c1fcg1/yuM=";
    }}";

    home.activation = {
      # Generate Needed Directories
      create_directories = lib.hm.dag.entryAfter ["writeBoundary"] ''
        $DRY_RUN_CMD mkdir -p /home/otto/.config/wayvnc/;
        $DRY_RUN_CMD mkdir -p /home/otto/Control;
        $DRY_RUN_CMD mkdir -p /home/otto/Presentation;
      '';
      # Generate the libreoffice .config files / directories, then link in the macros
      libreofficesetup = lib.hm.dag.entryAfter ["writeBoundary"] ''
        if [ ! -d /home/otto/.config/libreoffice/ ]; then
          $DRY_RUN_CMD ${pkgs.libreoffice}/bin/libreoffice --terminate_after_init --headless;
        fi
        $DRY_RUN_CMD rm -rf /home/otto/.config/libreoffice/4/user/basic/Standard;
        $DRY_RUN_CMD ln -s /home/otto/ssds/Standard /home/otto/.config/libreoffice/4/user/basic/;
      '';
      # Generate RSA key for VNC
      # Link VNC config into place
      generate_keys = lib.hm.dag.entryAfter ["writeBoundary"] ''
        $DRY_RUN_CMD ${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -keyout /home/otto/.config/wayvnc/tls_key.pem -out /home/otto/.config/wayvnc/tls_cert.pem -subj /CN=localhost
        $DRY_RUN_CMD ln -sf ${config.sops.secrets.wayvnc_cfg.path} /home/otto/.config/wayvnc/wayvnc;
      '';
    };
    systemd.user.services = {
      wayvnc = {
        Unit.Description = "Wayvnc screen sharing";
        Service = {
          ExecStart = toString ( pkgs.writeShellScript "launch_wayvnc.sh" ''
            ${pkgs.wayvnc}/bin/wayvnc -v --config=${config.sops.secrets.wayvnc_cfg.path}
          '');
          Type="exec";
        };
        Install = { 
          WantedBy = ["default.target"];
          After = ["sway-session.target"];
        };
      };
      ssds = {
        Unit.Description = "Super Simple Digital Signage";
        Service = {
          ExecStart = "${pkgs.bash} /home/otto/ssds/presentation.sh";
          Type="exec";
        };
        Install = { 
          WantedBy = ["default.target"];
          After = ["sway-session.target"];
        };
      };
      # Open office has a memory leak.  refresh it dailiy at 6:00am
      office_refresh = {
        Unit.Description = "Nightly Libreoffice Refresh";
        Service = {
          Type = "oneshot";
          ExecStart = toString ( pkgs.writeShellScript "soffice_refresh.sh" ''
            ${pkgs.killall}/bin/killall soffice.bin
          '');
        };
      };
    };
    systemd.user.timers = {
      office_refresh = {
        Unit.Description = "Office Refresh schedule";
        Timer = {
          Unit = "office_refresh.service";
          OnCalendar = "06:00";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
    home.stateVersion = "23.05";  # Required
  };

  # packages installed in system profile.
  environment.systemPackages = with pkgs; [
    vim 
    git
    libcec
    htop
    libraspberrypi
    raspberrypi-eeprom
    killall
  ];
  
  # CEC related configuration
  nixpkgs.overlays = [
    (self: super: { libcec = super.libcec.override { withLibraspberrypi = true; }; })
  ];

  services.udev.extraRules = ''
    # allow access to raspi cec device for video group (and optionally register it as a systemd device, used below)
    SUBSYSTEM=="vchiq", GROUP="video", MODE="0660", TAG+="systemd", ENV{SYSTEMD_ALIAS}="/dev/vchiq"
  '';

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # 5900 - VNC
  networking.firewall.allowedTCPPorts = [ 5900 ];

  system.stateVersion = "23.05"; # Required 
}
