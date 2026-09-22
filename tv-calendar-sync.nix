{ config, pkgs, ... }:
let
  pythonEnv = pkgs.python3.withPackages (ps: [ ps.icalendar ]);

  # Expands every VEVENT into its constituent dates. All-day events in
  # iCal use an EXCLUSIVE DTEND (a "Dec 21 - Dec 24" break literally
  # means through the 23rd) -- naively including DTEND itself would
  # exclude one extra day of TV operation that was never actually part
  # of the break.
  parseScript = pkgs.writeText "ics-to-excluded-dates.py" ''
    import sys, datetime
    from icalendar import Calendar

    ics_path, out_path = sys.argv[1], sys.argv[2]

    with open(ics_path, "rb") as f:
        cal = Calendar.from_ical(f.read())

    def to_date(value):
        return value.date() if isinstance(value, datetime.datetime) else value

    dates = set()
    for component in cal.walk():
        if component.name != "VEVENT":
            continue

        dtstart_raw = component.decoded("dtstart")
        start = to_date(dtstart_raw)

        if "dtend" in component:
            dtend_raw = component.decoded("dtend")
            end = to_date(dtend_raw)
            # Only back off by one for genuine all-day (date, not
            # datetime) events -- that's where DTEND's exclusivity
            # actually applies.
            if not isinstance(dtend_raw, datetime.datetime):
                end = end - datetime.timedelta(days=1)
        else:
            end = start

        current = start
        while current <= end:
            dates.add(current)
            current += datetime.timedelta(days=1)

    with open(out_path, "w") as f:
        for d in sorted(dates):
            f.write(d.isoformat() + "\n")
  '';
in
{
  # tv-calendar-ics-url is declared centrally in secrets.nix.

  systemd.services.tv-calendar-sync = {
    description = "Fetch org calendar feed, rebuild the TV excluded-dates list";
    serviceConfig.Type = "oneshot";
    script = ''
      set -euo pipefail
      # webcal:// is not a real transport -- it's a hint calendar apps
      # use to mean "subscribe here," universally equivalent to the same
      # resource over https://. curl has no webcal handler and will
      # simply reject the URL unless this is rewritten first.
      url=$(cat ${config.sops.secrets."tv-calendar-ics-url".path} | sed -e 's#^webcal://#https://#')
      tmp=$(mktemp)
      ${pkgs.curl}/bin/curl -fsSL "$url" -o "$tmp"
      mkdir -p /var/lib/tv-schedule
      ${pythonEnv}/bin/python3 ${parseScript} "$tmp" /var/lib/tv-schedule/excluded-dates.txt
      rm -f "$tmp"
    '';
  };

  systemd.timers.tv-calendar-sync = {
    description = "Daily refresh of the TV excluded-dates list";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "04:30";
      Persistent = true; # catches up if the Pi was off at 04:30
    };
  };
}
