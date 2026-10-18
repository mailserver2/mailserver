#!/bin/bash

# How clamav-unofficial-sigs asks clamd to reload its databases (see
# clamd_reload_opt in /etc/clamav-unofficial-sigs/os.conf).
#
# Whenever clamd is starting, at container start or after it restarts, it has
# no socket and ignores SIGUSR2, the updater's fallback, until it has loaded
# its databases, so a reload sent then is lost. The update at startup runs
# while clamd starts, so it meets this regularly; an hourly one can too. So
# every reload first waits for clamd to answer. Each failed ping prints an
# ERROR, which the updater would take for a failed reload, so the wait is
# silent: if clamd never answers, the reload's own error is what the updater
# sees.
#
# A reload sent while clamd is already reloading does not wait: clamd answers
# then, and merges it into the reload in progress. Anything that reload missed
# is picked up by clamd's SelfCheck.

clamdscan --ping 300:1 > /dev/null 2>&1
exec clamdscan --reload
