#!/bin/bash

# The hourly clamav-unofficial-sigs update, as cron runs it (see
# cron_script_full_path in /etc/clamav-unofficial-sigs/os.conf).
#
# cron mails whatever a job prints to the job's user, clamav@<FQDN>, which
# nobody reads, and the mail is scanned by rspamd on the way. The output goes
# to syslog instead, with the rest of the container's logs: shell errors
# (stderr) at mail.err, the script's own ERROR and ALERT lines (stdout) at
# mail.warning. The job exits with the script's status.

pid_file=/var/lib/clamav-unofficial-sigs/pid/clamav-unofficial-sigs.pid

# The update at startup and this hourly one are independent, so finding the
# other one running is expected rather than an error.
if [ -f "$pid_file" ] && ps -p "$(cat "$pid_file")" > /dev/null 2>&1; then
  logger -t clamav-unofficial-sigs -p mail.info "update already running, skipping this run"
  exit 0
fi

# The script frames its messages with lines of = * - or +, which are dropped:
# by sed, as grep -v fails when it is left with nothing, which under pipefail
# would fail every quiet run.
set -o pipefail
{ /usr/local/bin/clamav-unofficial-sigs.sh 2>&1 1>&3 3>&- \
    | sed '/^[-=*+]*$/d' | logger -t clamav-unofficial-sigs -p mail.err; } 3>&1 \
  | sed '/^[-=*+]*$/d' | logger -t clamav-unofficial-sigs -p mail.warning
