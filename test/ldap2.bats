load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

#
# system
#

@test "checking system: all environment variables have been replaced (ldap2 configuration)" {
  run docker exec mailserver_ldap2 /bin/bash -c "egrep -R -I "{{.*}}" /etc/postfix /etc/postfixadmin/fetchmail.conf /etc/dovecot /etc/rspamd /etc/cron.d /etc/mailname /usr/local/bin"
  assert_failure
}

#
# processes (ldap2 configuration)
#

@test "checking process: s6           (ldap2 configuration)" {
  run docker exec mailserver_ldap2 /bin/bash -c "ps aux --forest | grep '[s]6-svscan /services'"
  assert_success
}

@test "checking process: rsyslog      (ldap2 configuration)" {
  run docker exec mailserver_ldap2 /bin/bash -c "ps aux --forest | grep '[s]6-supervise rsyslogd'"
  assert_success
  run docker exec mailserver_ldap2 /bin/bash -c "ps aux --forest | grep '[r]syslogd -n -f /etc/rsyslog/rsyslog.conf'"
  assert_success
}

@test "checking process: cron         (ldap2 configuration)" {
  run docker exec mailserver_ldap2 /bin/bash -c "ps aux --forest | grep '[s]6-supervise cron'"
  assert_success
  run docker exec mailserver_ldap2 /bin/bash -c "ps aux --forest | grep '[c]ron -f'"
  assert_success
}

@test "checking process: postfix      (ldap2 configuration)" {
  run docker exec mailserver_ldap2 /bin/bash -c "ps aux --forest | grep '[s]6-supervise postfix'"
  assert_success
  run docker exec mailserver_ldap2 /bin/bash -c "ps aux --forest | grep '[/]usr/lib/postfix/sbin/master -s'"
  assert_success
}

@test "checking process: dovecot      (ldap2 configuration)" {
  run docker exec mailserver_ldap2 /bin/bash -c "ps aux --forest | grep '[s]6-supervise dovecot'"
  assert_success
  run docker exec mailserver_ldap2 /bin/bash -c "ps aux --forest | grep '[/]usr/sbin/dovecot -F'"
  assert_success
}

@test "checking process: rspamd       (ldap2 configuration)" {
  run docker exec mailserver_ldap2 /bin/bash -c "ps aux --forest | grep '[s]6-supervise rspamd'"
  assert_success
  run docker exec mailserver_ldap2 /bin/bash -c "ps aux --forest | grep '[r]spamd: main process'"
  assert_success
  run docker exec mailserver_ldap2 /bin/bash -c "ps aux --forest | grep '[r]spamd: rspamd_proxy process'"
  assert_success
  run docker exec mailserver_ldap2 /bin/bash -c "ps aux --forest | grep '[r]spamd: controller process'"
  assert_success
}

@test "checking process: clamd        (ldap2 configuration)" {
  run docker exec mailserver_ldap2 /bin/bash -c "ps aux --forest | grep '[s]6-supervise clamd'"
  assert_success
  run docker exec mailserver_ldap2 /bin/bash -c "ps aux --forest | grep -v 's6' | grep '[c]lamd'"
  assert_failure
}

@test "checking process: freshclam    (ldap2 configuration)" {
  run docker exec mailserver_ldap2 /bin/bash -c "ps aux --forest | grep '[s]6-supervise freshclam'"
  assert_success
  run docker exec mailserver_ldap2 /bin/bash -c "ps aux --forest | grep '[f]reshclam -d'"
  assert_failure
}

@test "checking process: unbound      (ldap2 configuration)" {
  run docker exec mailserver_ldap2 /bin/bash -c "ps aux --forest | grep '[s]6-supervise unbound'"
  assert_success
  run docker exec mailserver_ldap2 /bin/bash -c "ps aux --forest | grep -v 's6' | grep '[u]nbound'"
  assert_failure
}

@test "checking process: cert_watcher (ldap2 configuration)" {
  run docker exec mailserver_ldap2 /bin/bash -c "ps aux --forest | grep '[s]6-supervise cert_watcher'"
  assert_success
}

#
# sasl
#

@test "checking sasl: dovecot auth with good password (ldap2 configuration)" {
  run docker exec mailserver_ldap2 /bin/sh -c "doveadm auth test john.connor@domain.tld testpasswd2 | grep 'auth succeeded'"
  assert_success
}

@test "checking sasl: dovecot auth with bad password (ldap2 configuration)" {
  run docker exec mailserver_ldap2 /bin/sh -c "doveadm auth test john.connor@domain.tld badpassword | grep 'auth failed'"
  assert_success
}

@test "checking sasl: dovecot auth with good master password (ldap2 configuration)" {
  run docker exec mailserver_ldap2 /bin/sh -c "doveadm auth test john.doe@domain.tld*john.connor@domain.tld testpasswd2 | grep 'auth succeeded'"
  assert_success
}

@test "checking sasl: dovecot auth with bad master password (ldap2 configuration)" {
  run docker exec mailserver_ldap2 /bin/sh -c "doveadm auth test john.connor@domain.tld*john.doe@domain.tld testpasswd12 | grep 'auth failed'"
  assert_success
}

@test "checking sasl: dovecot auth with good non-master password (ldap2 configuration)" {
  run docker exec mailserver_ldap2 /bin/sh -c "doveadm auth test sarah.connor@domain.tld*john.doe@domain.tld testpasswd12 | grep 'auth failed'"
  assert_success
}

#
# smtp
# http://www.postfix.org/SASL_README.html#server_test
#

# Base64 AUTH STRINGS
# AHNhcmFoLmNvbm5vckBkb21haW4udGxkAHRlc3RwYXNzd2QxMg==
#   echo -ne '\000sarah.connor@domain.tld\000testpasswd12' | openssl base64
# AHNhcmFoLmNvbm5vckBkb21haW4udGxkAGJhZHBhc3N3b3Jk
#   echo -ne '\000sarah.connor@domain.tld\000badpassword' | openssl base64
# c2FyYWguY29ubm9yQGRvbWFpbi50bGQ=
#   echo -ne 'sarah.connor@domain.tld' | openssl base64
# dGVzdHBhc3N3ZDEy
#   echo -ne 'testpasswd12' | openssl base64
# YmFkcGFzc3dvcmQ=
#   echo -ne 'badpassword' | openssl base64

@test "checking smtp: john.doe should have received 4 mails (internal + external + subaddress + postmaster_alias) (ldap2 configuration)" {
  run docker exec mailserver_ldap2 /bin/sh -c "ls -A /var/mail/vhosts/domain.tld/john.doe/mail/new/ | wc -l"
  assert_success
  assert_output 4
}

@test "checking smtp: john.connor should have received 1 mails (postmaster_alias) (ldap2 configuration)" {
  run docker exec mailserver_ldap2 /bin/sh -c "ls -A /var/mail/vhosts/domain.tld/john.connor/mail/new/ | wc -l"
  assert_success
  assert_output 1
}

@test "checking smtp: delivers mail to existing alias (ldap2 configuration)" {
  run docker exec mailserver_ldap2 /bin/sh -c "grep 'to=<john.doe@domain.tld>, orig_to=<postmaster@domain.tld>' /var/log/mail.log | grep 'status=sent' | wc -l"
  assert_success
  assert_output 1
}

@test "checking smtp: rejects mail to unknown forward (ldap2 configuration)" {
  run docker exec mailserver_ldap2 /bin/sh -c "grep '<hostmaster@domain.tld>: Recipient address rejected: User unknown in virtual mailbox table' /var/log/mail.log | grep 'NOQUEUE: reject' | wc -l"
  assert_success
  assert_output 1
}

@test "checking smtp: rejects mail to unknown group (ldap2 configuration)" {
  run docker exec mailserver_ldap2 /bin/sh -c "grep '<group@domain.tld>: Recipient address rejected: User unknown in virtual mailbox table' /var/log/mail.log | grep 'NOQUEUE: reject' | wc -l"
  assert_success
  assert_output 1
}

#
# imap
#

@test "checking imaps (993): SSL/TLS login works with good master password (ldap2 configuration)" {
  run docker exec mailserver_ldap2 /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:993 < /tmp/tests/auth/imap-auth-master.txt 2>&1 | grep -i 'logged in'"
  assert_success
}

@test "checking imaps (993): SSL/TLS login fails with bad password (ldap2 configuration)" {
  run docker exec mailserver_ldap2 /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:993 < /tmp/tests/auth/imap-auth-master-wrong.txt 2>&1 | grep -i 'authentication failed'"
  assert_success
}

#
# ldap
#

@test "checking ldap maps exist in postfix main.cf in ldap configurations" {
  run docker exec mailserver_ldap2 grep -i 'ldap:' /etc/postfix/main.cf
  assert_success
}

@test "checking no sql maps exist in postfix main.cf in ldap configurations" {
  run docker exec mailserver_ldap2 grep -i 'sql' /etc/postfix/main.cf
  assert_failure
}

@test "checking ony ldap alias (not forward and group maps) exist in postfix main.cf in ldap2 configurations" {
  run docker exec mailserver_ldap2 grep -i 'ldap:/etc/postfix/ldap/virtual-alias-maps.cf' /etc/postfix/main.cf
  assert_success
  run docker exec mailserver_ldap2 grep -i 'ldap:/etc/postfix/ldap/virtual-forward-maps.cf' /etc/postfix/main.cf
  assert_failure
  run docker exec mailserver_ldap2 grep -i 'ldap:/etc/postfix/ldap/virtual-group-maps.cf' /etc/postfix/main.cf
  assert_failure
}

@test "checking ldap master only exists in ldap2 configurations" {
  run docker exec mailserver_ldap2 grep -i 'master' /etc/dovecot/conf.d/auth-ldap.conf.ext
  assert_success
}


#
# logs
#

@test "checking logs: /var/log/mail.log in mailserver_ldap2 is error free" {
  run docker exec mailserver_ldap2 grep -i ': error:' /var/log/mail.log
  assert_failure
  run docker exec mailserver_ldap2 grep -i 'is not writable' /var/log/mail.log
  assert_failure
  run docker exec mailserver_ldap2 grep -i 'permission denied' /var/log/mail.log
  assert_failure
  run docker exec mailserver_ldap2 grep -i 'address already in use' /var/log/mail.log
  assert_failure
}

@test "checking logs: /var/log/mail.err in mailserver_ldap2 does not exist" {
  run docker exec mailserver_ldap2 cat /var/log/mail.err
  assert_failure
  assert_output --partial 'No such file or directory'
}
