{ config, pkgs, lib, ... }:
{
  # User definition
  users.users.otto = {
	isNormalUser = true;
    createHome = true;
    extraGroups = [ "networkmanager" "wheel" "video" "render" ];
    openssh.authorizedKeys.keys = [ config.sops.secrets."otto-authorized-keys".path ];
    packages = with pkgs; [
      ffmpeg
      imv                 # Image viewer
      killall
      libheif             # Explicit HEIF Support
      libreoffice-still   # Libreoffice for Slides
      mpv                 # Video Support
    ];
  };  

  # Users home folder definition
  home-manager.users.otto = { pkgs, lib, ... }: {
    # Enable sway management, and set options
    wayland.windowManager.sway.enable = true;
    wayland.windowManager.sway.config = {
      seat = { "*" = { hide_cursor = "600"; }; };
      output = { "*" = { bg = "~/ssds/School_District_73.jpg fill"; }; };
      startup = [
        { command = "exec /home/otto/ssds/wrapper.sh"; always = true; }
      ];
    };
    wayland.windowManager.sway.checkConfig = false; # Don't check the config, since it references files that are pulled in from Git.

    # Import the SSDS files from Github.
    home.file."ssds".source = "${pkgs.fetchFromGitHub {
      owner = "Hegz";
      repo = "SSDS";
      rev = "a4613532ba1e9eddd52754a4d5668b8dc8d98775";
      hash = "sha256-OIVMBBhdd3vOTYLeAZGwDzd8oTQLalIENfUJ6G4HFC0=";
    }}";

    home.activation = {
      # Generate Needed Directories
      create_directories = lib.hm.dag.entryAfter ["writeBoundary"] ''
        $DRY_RUN_CMD mkdir -p /home/otto/Control;
        $DRY_RUN_CMD mkdir -p /home/otto/Presentation;
      '';
      # Generate the libreoffice .config files / directories, then link in the macros
      libreofficesetup = lib.hm.dag.entryAfter ["writeBoundary"] ''
          $DRY_RUN_CMD rm -rf /home/otto/.config/libreoffice
          $DRY_RUN_CMD ${pkgs.libreoffice}/bin/libreoffice --terminate_after_init --headless;
          $DRY_RUN_CMD mkdir -p /home/otto/.config/libreoffice/4/user/basic
          $DRY_RUN_CMD rm -rf /home/otto/.config/libreoffice/4/user/basic/Standard;
          $DRY_RUN_CMD ln -s /home/otto/ssds/Standard /home/otto/.config/libreoffice/4/user/basic/;
      '';
    };

    systemd.user.services = {
      wayvnc = {
        Unit = {
          Description = "Wayvnc screen sharing";
          After = ["sway-session.target"];
          StartLimitIntervalSec = 500;
          StartLimitBurst = 5;
        };
        Service = {
          ExecStart = toString ( pkgs.writeShellScript "launch_wayvnc.sh" ''
            ${pkgs.wayvnc}/bin/wayvnc -v 127.0.0.1 5900'');
          Type = "exec";
          Restart = "on-failure";
          RestartSec = "5s";
        };
        Install = {
          WantedBy = ["default.target"];
        };
      };

      # Make sure wayvnc is running.
      wayvnc_watchdog = {
        Unit.Description = "WayVNC reachability watchdog";
        Service = {
          Type = "oneshot";
          ExecStart = toString ( pkgs.writeShellScript "wayvnc_watchdog.sh" ''
            set -u
            SYSTEMCTL=${pkgs.systemd}/bin/systemctl

            STATE=$($SYSTEMCTL --user is-active wayvnc.service 2>/dev/null || true)

            if [ "$STATE" = "failed" ]; then
              logger -t wayvnc-watchdog "wayvnc failed, likely hit its restart limit -- clearing and restarting"
              $SYSTEMCTL --user reset-failed wayvnc.service
              $SYSTEMCTL --user restart wayvnc.service
              exit 0
            fi

            if [ "$STATE" != "active" ]; then
              logger -t wayvnc-watchdog "wayvnc is $STATE, not active -- starting"
              $SYSTEMCTL --user start wayvnc.service
              exit 0
            fi

            if ! timeout 3 ${pkgs.bash}/bin/bash -c 'exec 3<>/dev/tcp/127.0.0.1/5900' 2>/dev/null; then
              logger -t wayvnc-watchdog "wayvnc reports active but port 5900 refused connection -- restarting"
              $SYSTEMCTL --user restart wayvnc.service
         fi
          '');
        };
      };

      # Open office may have a memory leak. Refresh it daily at 6:00am
      office_refresh = {
        Unit.Description = "Daily Libreoffice Refresh";
        Service = {
          Type = "oneshot";
          ExecStart = toString ( pkgs.writeShellScript "soffice_refresh.sh" ''
            ${pkgs.killall}/bin/killall soffice.bin
            sleep 2
            ${pkgs.findutils}/bin/find /home/otto/Presentation -maxdepth 1 -type f -name ".~lock.*.odp#" -delete
            ${pkgs.coreutils-full}/bin/touch /home/otto/Control/End
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
      wayvnc_watchdog = {
        Unit.Description = "WayVNC watchdog schedule";
        Timer = {
          Unit = "wayvnc_watchdog.service";
          OnBootSec = "2m";
          OnUnitActiveSec = "2m";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };

    home.stateVersion = "23.05";  # Required
  };
}
