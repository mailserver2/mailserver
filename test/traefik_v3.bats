load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

#
# traefik v3
#
# acme.json as written by Traefik 2 and 3, which share the same format. The
# fixture holds two certificate resolvers: with more than one of them, the
# extraction used to fail and no certificate was written at all.
#

@test "checking traefik v3: acme.json exist" {
  run docker exec mailserver_traefik_v3 [ -f /etc/letsencrypt/acme/acme.json ]
  assert_success
}

@test "checking traefik v3: acme.json has more than one certificate resolver" {
  run docker exec mailserver_traefik_v3 /bin/sh -c "jq -r 'keys | length' /etc/letsencrypt/acme/acme.json"
  assert_success
  [ "$output" -gt 1 ]
}

# fixtures_traefik_v3 rewrites acme.json once. A watcher that reacted to
# its own reads would start the cycle again and again. The rewritten bytes
# are identical, so the cycle ends at "Live Certificates match".
@test "checking traefik v3: one write to acme.json causes exactly one reload" {
  run docker logs mailserver_traefik_v3
  assert_success
  [ "$(echo "$output" | grep -c 'Updating SSL certificates and reloading')" -eq 1 ]
  [ "$(echo "$output" | grep -c 'Live Certificates match')" -eq 1 ]
}

@test "checking traefik v3: the dump log was removed" {
  run docker exec mailserver_traefik_v3 [ -f /var/mail/ssl/acme_dump.log ]
  assert_failure
}

@test "checking traefik v3: all certificates were generated" {
  run docker exec mailserver_traefik_v3 [ -f /ssl/cert.pem ]
  assert_success
  run docker exec mailserver_traefik_v3 [ -f /ssl/chain.pem ]
  assert_success
  run docker exec mailserver_traefik_v3 [ -f /ssl/fullchain.pem ]
  assert_success
  run docker exec mailserver_traefik_v3 [ -f /ssl/privkey.pem ]
  assert_success
}

@test "checking traefik v3: check private key" {
  run docker exec mailserver_traefik_v3 /bin/sh -c "openssl rsa -in /ssl/privkey.pem -check 2>/dev/null | head -n 1"
  assert_success
  assert_output "RSA key ok"
}

@test "checking traefik v3: private key matches the certificate" {
  run docker exec mailserver_traefik_v3 /bin/sh -c "(openssl x509 -noout -modulus -in /ssl/cert.pem | openssl md5 ; openssl rsa -noout -modulus -in /ssl/privkey.pem | openssl md5) | uniq | wc -l"
  assert_success
  assert_output 1
}

#
# ssl
#

@test "checking ssl: the certificate from acme.json is the one served" {
  run docker exec mailserver_traefik_v3 /bin/sh -c "timeout 1 openssl s_client -ign_eof -connect 0.0.0.0:587 -starttls smtp 2>/dev/null | openssl x509 -noout -ext subjectAltName 2>/dev/null"
  assert_success
  assert_output --partial "DNS:mail.domain.tld"
}

#
# logs
#

@test "checking logs: /var/log/mail.err in mailserver_traefik_v3 does not exist" {
  run docker exec mailserver_traefik_v3 cat /var/log/mail.err
  assert_failure
  assert_output --partial 'No such file or directory'
}
