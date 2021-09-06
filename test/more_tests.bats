load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

#
# dovecot
#

@test "checking dovecot: piped ham message with sieve" {
  run docker exec mailserver_sieve /bin/sh -c "grep -i 'Debug: sieve: uid=2: pipe action: piped message to program.*rspamd-pipe-ham.sh' /var/log/mail.log | wc -l"
  assert_success
  assert_output 1
}

@test "checking dovecot: piped spam message with sieve" {
  run docker exec mailserver_sieve /bin/sh -c "grep -i 'Debug: sieve: uid=1: pipe action: piped message to program.*rspamd-pipe-spam.sh' /var/log/mail.log | wc -l"
  assert_success
  assert_output 1
}
