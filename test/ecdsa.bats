load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

# rspamd

@test "checking rspamd: 3 modules disabled in ecdsa configuration" {
  run docker exec mailserver_ecdsa cat /etc/rspamd/local.d/rbl.conf
  assert_success
  assert_output "enabled = false;"
  run docker exec mailserver_ecdsa cat /etc/rspamd/local.d/mx_check.conf
  assert_success
  assert_output "enabled = false;"
  run docker exec mailserver_ecdsa cat /etc/rspamd/local.d/url_redirector.conf
  assert_success
  assert_output "enabled = false;"
}

@test "checking rspamd: 2 addresses whitelisted in ecdsa configuration" {
  run docker exec mailserver_ecdsa /bin/bash -c "grep '\"test@example.com\",\"another@domain.tld\"' /etc/rspamd/local.d/settings.conf | wc -l"
  assert_success
  assert_output 1
}

#
# ssl
#

@test "checking ssl: ECDSA P-384 cert works correctly" {
  run docker exec mailserver_ecdsa /bin/sh -c "timeout 1 openssl s_client -ign_eof -connect 0.0.0.0:587 -starttls smtp | grep 'Verify return code: 18 (self-signed certificate)'"
  assert_success
}

#
# logs
#

@test "checking logs: /var/log/mail.err in mailserver_ecdsa does not exist" {
  run docker exec mailserver_ecdsa cat /var/log/mail.err
  assert_failure
  assert_output --partial 'No such file or directory'
}
