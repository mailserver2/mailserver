#!/bin/sh
# Print what this container's resolver answers for dbl.spamhaus.org, and which
# resolver that is. Runs inside the mailserver container (needs dig).
#
#   dbltest.com -> 127.0.1.2      the permanent test listing: the blocklist works
#   dbltest.com -> 127.255.255.x  this resolver is refused: every sender gets rejected
#   dbltest.com -> (nothing)      answered nothing: the blocklist is inert
#   gmail.com   -> (nothing)      the fixtures' sender domain, the name postfix looks up
#   example.com -> (nothing)      expected, it is not listed
#
# The resolver line gives the nameserver the container is configured with and
# the resolver's egress address as seen by two whoami services, because a
# healthy Spamhaus answer does not name it (only a refusal does). ttl is the
# remaining TTL: a full value is a fresh answer, a lower one came from cache.

q() { dig +time=3 +tries=1 "$@" 2>/dev/null | grep -v '^;'; }

ns=$(awk '/^nameserver/{print $2; exit}' /etc/resolv.conf)
ak=$(q +short A whoami.akamai.net | head -1)
gg=$(q +short TXT o-o.myaddr.l.google.com | grep -v edns0 | head -1 | tr -d '"')
printf '[dnsbl] resolver: nameserver=%s egress-seen-by-akamai=%s egress-seen-by-google=%s\n' "${ns:--}" "${ak:--}" "${gg:--}"

for name in dbltest.com.dbl.spamhaus.org gmail.com.dbl.spamhaus.org example.com.dbl.spamhaus.org; do
  out=$(dig +time=3 +tries=1 +noall +comments +answer +authority A "$name" 2>&1)
  st=$(printf '%s\n' "$out" | sed -n 's/.*status: \([A-Z]*\).*/\1/p' | head -1); [ -z "$st" ] && st=unreachable
  a=$(printf '%s\n' "$out" | grep '[[:space:]]A[[:space:]]' | sed 's/.*[[:space:]]//' | tr '\n' ',' | sed 's/,$//'); [ -z "$a" ] && a=-
  ttl=$(printf '%s\n' "$out" | grep -v '^;' | awk 'NF>=5{print $2; exit}'); [ -z "$ttl" ] && ttl=-
  t=$(q +short TXT "$name" | grep '^"' | head -1); [ -z "$t" ] && t=-
  printf '[dnsbl] %-32s status=%-11s A=%-16s ttl=%-5s %s\n' "$name" "$st" "$a" "$ttl" "$t"
done
