load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

# rspamd

@test "checking rspamd: debug mode enabled (traefik_acmev2 configuration)" {
  run docker exec mailserver_traefik_acmev2 /bin/sh -c 'rspamadm configdump | grep -E "level = \"info\";"'
  assert_success
}

#
# postfix
#

@test "checking postfix: verbose mode enabled (traefik_acmev2 configuration)" {
  run docker exec mailserver_traefik_acmev2 /bin/sh -c "grep 'smtpd -v' /etc/postfix/master.cf | wc -l"
  assert_success
  assert_output 3
}

#
# dovecot
#

@test "checking dovecot: debug mode enabled (traefik_acmev2 configuration)" {
  run docker exec mailserver_traefik_acmev2 /bin/sh -c "doveconf -h auth_verbose 2>/dev/null"
  assert_success
  assert_output "yes"
  run docker exec mailserver_traefik_acmev2 /bin/sh -c "doveconf -h auth_verbose_passwords 2>/dev/null"
  assert_success
  assert_output "sha1"
  run docker exec mailserver_traefik_acmev2 /bin/sh -c "doveconf -h auth_debug 2>/dev/null"
  assert_success
  assert_output "yes"
  run docker exec mailserver_traefik_acmev2 /bin/sh -c "doveconf -h auth_debug_passwords 2>/dev/null"
  assert_success
  assert_output "yes"
  run docker exec mailserver_traefik_acmev2 /bin/sh -c "doveconf -h mail_debug 2>/dev/null"
  assert_success
  assert_output "yes"
  run docker exec mailserver_traefik_acmev2 /bin/sh -c "doveconf -h verbose_ssl 2>/dev/null"
  assert_success
  assert_output "yes"
}

#
# unbound
#

@test "checking unbound: debug mode enabled" {
  run docker exec mailserver_traefik_acmev2 /bin/sh -c "unbound-control status | grep 'verbosity: 2'"
  assert_success
}

#
# ssl
#

@test "checking ssl: traefik cert works correctly (acme v2)" {
  run docker exec mailserver_traefik_acmev2 /bin/sh -c "timeout 1 openssl s_client -ign_eof -connect 0.0.0.0:587 -starttls smtp | grep 'Verify return code: 10 (certificate has expired)'"
  assert_success
}

#
# traefik acme v2
#

@test "checking traefik acme v2: acme.json exist" {
  run docker exec mailserver_traefik_acmev2 [ -f /etc/letsencrypt/acme/acme.json ]
  assert_success
}

@test "checking traefik acme v2: dump.log doesn't exist" {
  run docker exec mailserver_traefik_acmev2 [ -f /etc/letsencrypt/acme/dump.log ]
  assert_failure
}

@test "checking traefik acme v2: all certificates were generated" {
  run docker exec mailserver_traefik_acmev2 [ -f /ssl/cert.pem ]
  assert_success
  run docker exec mailserver_traefik_acmev2 [ -f /ssl/chain.pem ]
  assert_success
  run docker exec mailserver_traefik_acmev2 [ -f /ssl/fullchain.pem ]
  assert_success
  run docker exec mailserver_traefik_acmev2 [ -f /ssl/privkey.pem ]
  assert_success
}

@test "checking traefik acme v2: check private key" {
  run docker exec mailserver_traefik_acmev2 /bin/sh -c "openssl rsa -in /ssl/privkey.pem -check 2>/dev/null | head -n 1"
  assert_success
  assert_output "RSA key ok"
}

@test "checking traefik acme v2: private key matches the certificate" {
  run docker exec mailserver_traefik_acmev2 /bin/sh -c "(openssl x509 -noout -modulus -in /ssl/cert.pem | openssl md5 ; openssl rsa -noout -modulus -in /ssl/privkey.pem | openssl md5) | uniq | wc -l"
  assert_success
  assert_output 1
}

#
# logs
#

@test "checking logs: /var/log/mail.err in mailserver_traefik_acmev2 does not exist" {
  run docker exec mailserver_traefik_acmev2 cat /var/log/mail.err
  assert_failure
  assert_output --partial 'No such file or directory'
}
