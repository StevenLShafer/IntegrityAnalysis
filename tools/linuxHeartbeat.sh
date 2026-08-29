#!/usr/bin/env bash
############################################################################
# linuxHeartbeat.sh - make the compute node's death leave evidence.        #
#                                                                          #
# Provenance                                                               #
# Written 2026-08-29 by Claude Code (model Claude Opus 5) at Steve         #
# Shafer's request. LOCAL INFRASTRUCTURE ONLY - nothing here ships.        #
#                                                                          #
# WHY. Steve stopped using this machine under Windows because it "would    #
# abruptly die for no apparent reason". Before it is trusted with corpus   #
# runs that take tens of minutes, a death has to leave a trace. Right      #
# now it would not: the machine would simply stop answering, and we would  #
# learn nothing about why.                                                 #
#                                                                          #
# WHAT THIS ANSWERS. Two questions, and the second is the one that has     #
# never been answerable:                                                   #
#                                                                          #
#   1. WHEN did it die?  A vitals line is appended every minute. The gap   #
#      between the last line and the next boot IS the death window.        #
#                                                                          #
#   2. Was it a DEATH or a clean reboot?  A marker service writes BOOT     #
#      when systemd starts it and SHUTDOWN when systemd stops it. An       #
#      orderly reboot therefore reads ... SHUTDOWN, BOOT ... A crash,      #
#      a thermal cut, or a power loss reads ... BOOT with NO SHUTDOWN      #
#      before it. That single distinction separates "the OS restarted"     #
#      from "the hardware stopped", which is the fork in the road for      #
#      every subsequent diagnosis.                                         #
#                                                                          #
# WHAT THE VITALS ARE FOR. If the machine dies of heat, the CPU            #
# temperature climbs across the minutes before the gap and the last line   #
# is hot. If it dies of something else, the last line looks ordinary -     #
# which is itself informative, because it rules out the easy explanation.  #
# Reading k10temp/nvme/amdgpu straight from sysfs means NO packages are    #
# needed: lm-sensors and smartmontools are not required for any of this.   #
#                                                                          #
# The log is /var/log/ia-heartbeat.log, on a filesystem whose journal is   #
# already persistent, so it survives the reboot that follows a death.      #
#                                                                          #
# Usage - once, and it then runs forever:                                  #
#   ssh ubantu                                                             #
#   sudo bash ~/heartbeat.sh                                               #
#                                                                          #
# Safe to re-run: it overwrites its own units and re-enables them.         #
############################################################################

set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run me with sudo: sudo bash $0" >&2; exit 1; }

LOG=/var/log/ia-heartbeat.log

# ---- the vitals collector ----------------------------------------------
# Deliberately dependency-free: /sys and /proc only. Anything that needs a
# package is a thing that can be missing on the day it matters.
cat > /usr/local/bin/ia-heartbeat <<'COLLECT'
#!/usr/bin/env bash
# One vitals line. Written by tools/linuxHeartbeat.sh - do not edit here.
LOG=/var/log/ia-heartbeat.log

hw() {   # hw <name> -> temperature in C, or "-"
  for h in /sys/class/hwmon/hwmon*; do
    [ "$(cat "$h/name" 2>/dev/null)" = "$1" ] || continue
    [ -r "$h/temp1_input" ] || continue
    echo $(( $(cat "$h/temp1_input") / 1000 )); return
  done
  echo -
}

printf '%s up=%ss load=%s cpu=%sC nvme=%sC gpu=%sC mhz=%s memfree=%sM disk=%s\n' \
  "$(date -Is)" \
  "$(cut -d. -f1 /proc/uptime)" \
  "$(cut -d' ' -f1 /proc/loadavg)" \
  "$(hw k10temp)" "$(hw nvme)" "$(hw amdgpu)" \
  "$(awk '/cpu MHz/{s+=$4;n++}END{printf "%.0f", (n?s/n:0)}' /proc/cpuinfo)" \
  "$(awk '/MemAvailable/{printf "%.0f", $2/1024}' /proc/meminfo)" \
  "$(df -h / | awk 'NR==2{print $5}')" >> "$LOG"

# Keep the file bounded without a logrotate dependency. 200k lines is
# roughly 140 days at one line a minute - far more history than needed,
# and small enough to grep instantly.
if [ "$(wc -l < "$LOG")" -gt 200000 ]; then
  tail -n 100000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi
COLLECT
chmod +x /usr/local/bin/ia-heartbeat

# ---- BOOT / SHUTDOWN markers -------------------------------------------
# RemainAfterExit makes this a "one-shot that stays active": systemd runs
# ExecStart at boot and ExecStop during an ORDERLY shutdown. A hard death
# never reaches ExecStop, which is precisely how the two are told apart.
cat > /etc/systemd/system/ia-marker.service <<'MARKER'
[Unit]
Description=IntegrityAnalysis boot/shutdown marker (crash detection)
DefaultDependencies=no
After=local-fs.target
Before=shutdown.target
Conflicts=shutdown.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'echo "$(date -Is) ===== BOOT ===== kernel=$(uname -r)" >> /var/log/ia-heartbeat.log'
ExecStop=/bin/sh  -c 'echo "$(date -Is) ===== SHUTDOWN (clean) =====" >> /var/log/ia-heartbeat.log'

[Install]
WantedBy=multi-user.target
MARKER

# ---- the every-minute timer --------------------------------------------
cat > /etc/systemd/system/ia-heartbeat.service <<'SVC'
[Unit]
Description=IntegrityAnalysis heartbeat vitals sample

[Service]
Type=oneshot
ExecStart=/usr/local/bin/ia-heartbeat
SVC

cat > /etc/systemd/system/ia-heartbeat.timer <<'TIMER'
[Unit]
Description=Sample IntegrityAnalysis heartbeat vitals every minute

[Timer]
OnBootSec=30s
OnUnitActiveSec=60s
AccuracySec=5s

[Install]
WantedBy=timers.target
TIMER

touch "$LOG"; chmod 644 "$LOG"
systemctl daemon-reload
systemctl enable --now ia-marker.service  >/dev/null
systemctl enable --now ia-heartbeat.timer >/dev/null
/usr/local/bin/ia-heartbeat   # one line immediately, so the log is never empty

echo "heartbeat installed. Current state:"
systemctl is-active ia-heartbeat.timer ia-marker.service | paste -sd' '
echo "--- last lines of $LOG ---"
tail -3 "$LOG"
echo
echo "After any unexpected outage, the diagnosis is one command:"
echo "  grep -E '=====' $LOG | tail -20"
echo "A BOOT line with no SHUTDOWN before it means the hardware stopped."
