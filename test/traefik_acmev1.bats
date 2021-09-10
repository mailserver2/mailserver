load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

# rspamd

@test "checking rspamd: debug mode disabled (traefik_acmev1 configuration)" {
  run docker exec mailserver_traefik_acmev1 /bin/sh -c 'rspamadm configdump | grep -E "level = \"warning\";"'
  assert_success
}

#
# postfix
#

@test "checking postfix: verbose mode enabled (traefik_acmev1 configuration)" {
  run docker exec mailserver_traefik_acmev1 /bin/sh -c "grep 'smtpd -v' /etc/postfix/master.cf | wc -l"
  assert_success
  assert_output 3
}

#
# dovecot
#

@test "checking dovecot: debug mode enabled (traefik_acmev1 configuration)" {
  run docker exec mailserver_traefik_acmev1 /bin/sh -c "doveconf -h auth_verbose 2>/dev/null"
  assert_success
  assert_output "yes"
  run docker exec mailserver_traefik_acmev1 /bin/sh -c "doveconf -h auth_verbose_passwords 2>/dev/null"
  assert_success
  assert_output "sha1"
  run docker exec mailserver_traefik_acmev1 /bin/sh -c "doveconf -h auth_debug 2>/dev/null"
  assert_success
  assert_output "yes"
  run docker exec mailserver_traefik_acmev1 /bin/sh -c "doveconf -h auth_debug_passwords 2>/dev/null"
  assert_success
  assert_output "yes"
  run docker exec mailserver_traefik_acmev1 /bin/sh -c "doveconf -h mail_debug 2>/dev/null"
  assert_success
  assert_output "yes"
  run docker exec mailserver_traefik_acmev1 /bin/sh -c "doveconf -h verbose_ssl 2>/dev/null"
  assert_success
  assert_output "yes"
}

#
# ssl
#

@test "checking ssl: traefik cert works correctly (acme v1)" {
  run docker exec mailserver_traefik_acmev1 /bin/sh -c "timeout 1 openssl s_client -ign_eof -connect 0.0.0.0:587 -starttls smtp | grep 'Verify return code: 10 (certificate has expired)'"
  assert_success
}

#
# traefik acme v1
#

@test "checking traefik acme v1: acme.json exist" {
  run docker exec mailserver_traefik_acmev1 [ -f /etc/letsencrypt/acme/acme.json ]
  assert_success
}

@test "checking traefik acme v1: dump.log doesn't exist" {
  run docker exec mailserver_traefik_acmev1 [ -f /etc/letsencrypt/acme/dump.log ]
  assert_failure
}

@test "checking traefik acme v1: all certificates were generated" {
  run docker exec mailserver_traefik_acmev1 [ -f /ssl/cert.pem ]
  assert_success
  run docker exec mailserver_traefik_acmev1 [ -f /ssl/chain.pem ]
  assert_success
  run docker exec mailserver_traefik_acmev1 [ -f /ssl/fullchain.pem ]
  assert_success
  run docker exec mailserver_traefik_acmev1 [ -f /ssl/privkey.pem ]
  assert_success
}

@test "checking traefik acme v1: check private key" {
  run docker exec mailserver_traefik_acmev1 /bin/sh -c "openssl rsa -in /ssl/privkey.pem -check 2>/dev/null | head -n 1"
  assert_success
  assert_output "RSA key ok"
}

@test "checking traefik acme v1: private key matches the certificate" {
  run docker exec mailserver_traefik_acmev1 /bin/sh -c "(openssl x509 -noout -modulus -in /ssl/cert.pem | openssl md5 ; openssl rsa -noout -modulus -in /ssl/privkey.pem | openssl md5) | uniq | wc -l"
  assert_success
  assert_output 1
}

#
# logs
#

@test "checking logs: /var/log/mail.err in mailserver_traefik_acmev1 does not exist" {
  run docker exec mailserver_traefik_acmev1 cat /var/log/mail.err
  assert_failure
  assert_output --partial 'No such file or directory'
}
