#!/bin/sh
# Exercise the dbl.spamhaus.org sender check repeatedly, logging the resolver
# and the blocklist's answers before every attempt, until an attempt is
# refused or the iterations run out. Both outcomes are logged.
#
#   dnsbl-loop.sh <container> <iterations> <interval-seconds>
#
# Each iteration costs Spamhaus 9 queries (8 from the probe, 1 from postfix),
# so the default 20 iterations are 180 queries per run, spaced 15 s apart:
# a small fraction of what one quiet mail server sends in a day. The interval
# is longer than the 10 s negative TTL observed on the sender-domain answer,
# so each attempt reaches Spamhaus rather than the resolver's cache. If the
# blocklist ever answers 127.255.255.255 ("excessive number of queries") the
# loop stops at once.
set -u
container=$1; iterations=$2; interval=$3
template=/tmp/tests/email-templates/external-to-existing-user.txt   # MAIL FROM user@gmail.com

i=1
while [ "$i" -le "$iterations" ]; do
  echo "[dnsbl-loop] iteration $i/$iterations at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  probe=$(docker exec "$container" sh /tmp/tests/dnsbl-probe.sh)
  printf '%s\n' "$probe"
  if printf '%s\n' "$probe" | grep -q '127\.255\.255\.255'; then
    echo "[dnsbl-loop] STOP: Spamhaus answered 127.255.255.255 (excessive number of queries); not continuing"
    exit 2
  fi
  reply=$(docker exec "$container" python3 /tmp/tests/smtp-send.py 0.0.0.0 25 "$template" 2>&1)
  if printf '%s\n' "$reply" | grep -q 'blocked using dbl'; then
    echo "[dnsbl-loop] REFUSED at iteration $i:"
    printf '%s\n' "$reply" | grep 'blocked using dbl' | sed 's/^/    /'
    exit 1
  elif printf '%s\n' "$reply" | grep -q '250 2.0.0 Ok: queued'; then
    echo "[dnsbl-loop] accepted: $(printf '%s\n' "$reply" | grep '250 2.0.0 Ok: queued' | head -1)"
  else
    echo "[dnsbl-loop] UNEXPECTED reply at iteration $i:"
    printf '%s\n' "$reply" | grep '^S:' | sed 's/^/    /'
    exit 1
  fi
  [ "$i" -lt "$iterations" ] && sleep "$interval"
  i=$((i + 1))
done
echo "[dnsbl-loop] $iterations iterations, all accepted"
