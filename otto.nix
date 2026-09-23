{ config, pkgs, lib, ... }:
{
  # User definition
  users.users.otto = {
	isNormalUser = true;
    createHome = true;
    extraGroups = [ "networkmanager" "wheel" "video" "render" ];
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
	let
      maintenanceLock = "/home/otto/Control/Maintenance.lock";

      libreofficeReset = pkgs.writeShellScript "libreoffice-profile-reset.sh" ''
        set -u
        exec 9>/run/libreoffice-reset.flock
        if ! ${pkgs.util-linux}/bin/flock -n 9; then
          echo "libreoffice-profile-reset: another reset is already in progress, skipping" | logger -t libreoffice-reset
          exit 0
        fi

        touch "${maintenanceLock}"
        trap 'rm -f "${maintenanceLock}"' EXIT

        ${pkgs.procps}/bin/pkill -f "/home/otto/ssds/presentation.sh" 2>/dev/null || true
        sleep 1

        ${pkgs.killall}/bin/killall soffice.bin 2>/dev/null || true
        sleep 2

        rm -rf /home/otto/.config/libreoffice

        ${pkgs.libreoffice}/bin/soffice --headless --terminate_after_init
        count=0
        while ${pkgs.procps}/bin/pgrep -x soffice.bin >/dev/null 2>&1 && [ "$count" -lt 30 ]; do
          sleep 1
          count=$((count+1))
        done

        mkdir -p /home/otto/.config/libreoffice/4/user/basic
        rm -rf /home/otto/.config/libreoffice/4/user/basic/Standard
        ln -s /home/otto/ssds/Standard /home/otto/.config/libreoffice/4/user/basic/Standard

        ${pkgs.coreutils-full}/bin/touch /home/otto/Control/End
      '';

      presentationWrapper = pkgs.writeShellScript "presentation-wrapper.sh" ''
        cd /home/otto

        function log_wrapper() {
            local priority="$1"
            local message="$2"
            logger -t presentation-wrapper -p "user.$priority" "$message"
            echo "[$priority] $message"
        }

        log_wrapper notice "Presentation wrapper service started."

        while true; do
            while [ -e "${maintenanceLock}" ]; do
                log_wrapper notice "Maintenance lock held -- waiting before (re)launching presentation.sh"
                sleep 2
            done

            log_wrapper info "Starting presentation script execution loop..."

            /home/otto/ssds/presentation.sh 2>&1 | logger -t presentation-script -p user.notice

            EXIT_CODE=''${PIPESTATUS[0]}

            log_wrapper warning "Presentation script exited unexpectedly with code $EXIT_CODE. Restarting in 3 seconds..."
            sleep 3
        done
      '';
    in
    {
      # Enable sway management, and set options
      wayland.windowManager.sway.enable = true;
      wayland.windowManager.sway.config = {
        seat = { "*" = { hide_cursor = "600"; }; };
        output = { "*" = { bg = "~/ssds/School_District_73.jpg fill"; }; };
        startup = [
          # Nix-authored wrapper (see presentationWrapper above), not the
          # repo's own wrapper.sh directly -- the difference is the
          # maintenance-lock gate.
          { command = "exec ${presentationWrapper}"; always = true; }
        ];
      };
      wayland.windowManager.sway.checkConfig = false; # Don't check the config, since it references files that are pulled in from Git.

      # Import the SSDS files from Github.
      home.file."ssds".source = "${pkgs.fetchFromGitHub {
        owner = "Hegz";
        repo = "SSDS";
        rev = "3415019e2d78090c044ce450c98344216a9ae808";
        hash = "sha256-jNJwQ5/rfg1lVtmWHFCh2zb2iq6HcHos9rlBFnX7pGw=";
      }}";

      home.activation = {
        # Generate Needed Directories
        create_directories = lib.hm.dag.entryAfter ["writeBoundary"] ''
          $DRY_RUN_CMD mkdir -p /home/otto/Control;
          $DRY_RUN_CMD mkdir -p /home/otto/Presentation;
        '';
        libreofficesetup = lib.hm.dag.entryAfter ["writeBoundary"] ''
          standard_link="/home/otto/.config/libreoffice/4/user/basic/Standard"
          standard_target="/home/otto/ssds/Standard"
          if [ "$(${pkgs.coreutils}/bin/readlink -f "$standard_link" 2>/dev/null)" != "$(${pkgs.coreutils}/bin/readlink -f "$standard_target")" ]; then
            $DRY_RUN_CMD ${libreofficeReset}
          fi
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

        office_refresh = {
          Unit.Description = "Nightly Libreoffice Refresh";
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

        libreoffice_profile_reset = {
          Unit.Description = "Weekly hard reset of the LibreOffice profile";
          Service = {
            Type = "oneshot";
            ExecStart = toString libreofficeReset;
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
        libreoffice_profile_reset = {
          Unit.Description = "Weekly LibreOffice profile reset schedule";
          Timer = {
            Unit = "libreoffice_profile_reset.service";
            OnCalendar = "Sat *-01,07-1..7 03:00:00";
            Persistent = true;
          };
          Install.WantedBy = [ "timers.target" ];
        };
      };

      home.stateVersion = "23.05";  # Required
    };




}
