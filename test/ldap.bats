load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

#
# system
#

@test "checking system: /etc/mailname (env method) (ldap)" {
  run docker exec mailserver_ldap cat /etc/mailname
  assert_success
  assert_output "mail.domain.tld"
}

@test "checking system: all environment variables have been replaced (ldap configuration)" {
  run docker exec mailserver_ldap /bin/bash -c "egrep -R -I "{{.*}}" /etc/postfix /etc/postfixadmin/fetchmail.conf /etc/dovecot /etc/rspamd /etc/cron.d /etc/mailname /usr/local/bin"
  assert_failure
}

#
# processes (ldap configuration)
#

@test "checking process: s6           (ldap configuration)" {
  run docker exec mailserver_ldap /bin/bash -c "ps aux --forest | grep '[s]6-svscan /services'"
  assert_success
}

@test "checking process: rsyslog      (ldap configuration)" {
  run docker exec mailserver_ldap /bin/bash -c "ps aux --forest | grep '[s]6-supervise rsyslogd'"
  assert_success
  run docker exec mailserver_ldap /bin/bash -c "ps aux --forest | grep '[r]syslogd -n -f /etc/rsyslog/rsyslog.conf'"
  assert_success
}

@test "checking process: cron         (ldap configuration)" {
  run docker exec mailserver_ldap /bin/bash -c "ps aux --forest | grep '[s]6-supervise cron'"
  assert_success
  run docker exec mailserver_ldap /bin/bash -c "ps aux --forest | grep '[c]ron -f'"
  assert_success
}

@test "checking process: postfix      (ldap configuration)" {
  run docker exec mailserver_ldap /bin/bash -c "ps aux --forest | grep '[s]6-supervise postfix'"
  assert_success
  run docker exec mailserver_ldap /bin/bash -c "ps aux --forest | grep '[/]usr/lib/postfix/sbin/master -s'"
  assert_success
}

@test "checking process: dovecot      (ldap configuration)" {
  run docker exec mailserver_ldap /bin/bash -c "ps aux --forest | grep '[s]6-supervise dovecot'"
  assert_success
  run docker exec mailserver_ldap /bin/bash -c "ps aux --forest | grep '[/]usr/sbin/dovecot -F'"
  assert_success
}

@test "checking process: rspamd       (ldap configuration)" {
  run docker exec mailserver_ldap /bin/bash -c "ps aux --forest | grep '[s]6-supervise rspamd'"
  assert_success
  run docker exec mailserver_ldap /bin/bash -c "ps aux --forest | grep '[r]spamd: main process'"
  assert_success
  run docker exec mailserver_ldap /bin/bash -c "ps aux --forest | grep '[r]spamd: rspamd_proxy process'"
  assert_success
  run docker exec mailserver_ldap /bin/bash -c "ps aux --forest | grep '[r]spamd: controller process'"
  assert_success
}

@test "checking process: clamd        (ldap configuration)" {
  run docker exec mailserver_ldap /bin/bash -c "ps aux --forest | grep '[s]6-supervise clamd'"
  assert_success
  run docker exec mailserver_ldap /bin/bash -c "ps aux --forest | grep -v 's6' | grep '[c]lamd'"
  assert_success

}

@test "checking process: freshclam    (ldap configuration)" {
  run docker exec mailserver_ldap /bin/bash -c "ps aux --forest | grep '[s]6-supervise freshclam'"
  assert_success
  run docker exec mailserver_ldap /bin/bash -c "ps aux --forest | grep '[f]reshclam -d'"
  assert_success
}

@test "checking process: unbound      (ldap configuration)" {
  run docker exec mailserver_ldap /bin/bash -c "ps aux --forest | grep '[s]6-supervise unbound'"
  assert_success
  run docker exec mailserver_ldap /bin/bash -c "ps aux --forest | grep -v 's6' | grep '[u]nbound'"
  assert_success
}

@test "checking process: cert_watcher (ldap configuration)" {
  run docker exec mailserver_ldap /bin/bash -c "ps aux --forest | grep '[s]6-supervise cert_watcher'"
  assert_success
}

#
# processes restarting
#

@test "checking process: 10 cron tasks to reset all the process counters" {
  run docker exec mailserver_ldap /bin/bash -c "cat /etc/cron.d/counters | wc -l"
  assert_success
  assert_output 10
}

@test "checking process: no service restarted (ldap configuration)" {
  run docker exec mailserver_ldap cat /tmp/counters/_parent
  assert_success
  assert_output 0
  run docker exec mailserver_ldap cat /tmp/counters/clamd
  assert_success
  assert_output 0
  run docker exec mailserver_ldap cat /tmp/counters/cron
  assert_success
  assert_output 0
  run docker exec mailserver_ldap cat /tmp/counters/dovecot
  assert_success
  assert_output 0
  run docker exec mailserver_ldap cat /tmp/counters/freshclam
  assert_success
  assert_output 0
  run docker exec mailserver_ldap cat /tmp/counters/postfix
  assert_success
  assert_output 0
  run docker exec mailserver_ldap cat /tmp/counters/rspamd
  assert_success
  assert_output 0
  run docker exec mailserver_ldap cat /tmp/counters/rsyslogd
  assert_success
  assert_output 0
  run docker exec mailserver_ldap cat /tmp/counters/unbound
  assert_success
  assert_output 0
  run docker exec mailserver_ldap cat /tmp/counters/cert_watcher
  assert_success
  assert_output 0
}

#
# ports
#

@test "checking port    (25): external port listening    (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "nc -z 0.0.0.0 25"
  assert_success
}

@test "checking port    (53): internal port listening    (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "nc -z 127.0.0.1 53"
  assert_success
}

@test "checking port   (110): external port closed       (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "nc -z 0.0.0.0 110"
  assert_failure
}

@test "checking port   (143): external port listening    (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "nc -z 0.0.0.0 143"
  assert_success
}

@test "checking port   (465): external port listening    (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "nc -z 0.0.0.0 465"
  assert_success
}

@test "checking port   (587): external port listening    (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "nc -z 0.0.0.0 587"
  assert_success
}

@test "checking port   (993): external port listening    (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "nc -z 0.0.0.0 993"
  assert_success
}

@test "checking port   (995): external port closed       (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "nc -z 0.0.0.0 995"
  assert_failure
}

@test "checking port  (3310): external port closed       (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "nc -z 0.0.0.0 3310"
  assert_success
}

@test "checking port  (4190): external port closed       (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "nc -z 0.0.0.0 4190"
  assert_success
}

@test "checking port  (8953): internal port listening    (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "nc -z 127.0.0.1 8953"
  assert_success
}

@test "checking port (10025): internal port closed       (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "nc -z 127.0.0.1 10025"
  assert_failure
}

@test "checking port (10026): internal port listening    (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "nc -z 127.0.0.1 10026"
  assert_success
}

@test "checking port (11332): external port listening    (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "nc -z 0.0.0.0 11332"
  assert_success
}

@test "checking port (11334): external port listening    (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "nc -z 0.0.0.0 11334"
  assert_success
}

#
# sasl
#

@test "checking sasl: dovecot auth with good password (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "doveadm auth test sarah.connor@domain.tld testpasswd12 | grep 'auth succeeded'"
  assert_success
}

@test "checking sasl: dovecot auth with bad password (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "doveadm auth test sarah.connor@domain.tld badpassword | grep 'auth failed'"
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

@test "checking smtp (25): STARTTLS AUTH PLAIN works with good password (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:25 -starttls smtp < /tmp/tests/auth/smtp-auth-plain.txt 2>&1 | grep -i 'authentication successful'"
  assert_success
}

@test "checking smtps (465): SSL/TLS AUTH LOGIN works with good password (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:465 < /tmp/tests/auth/smtp-auth-login.txt 2>&1 | grep -i 'authentication successful'"
  assert_success
}

@test "checking smtp: john.doe should have received 6 mails (internal + external + subaddress + hostmaster_forward + postmaster_alias + group_alias) (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "ls -A /var/mail/vhosts/domain.tld/john.doe/mail/new/ | wc -l"
  assert_success
  assert_output 6
}

@test "checking smtp: sarah.connor should have received 1 mail (internal spam-ham test) (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "ls -A /var/mail/vhosts/domain.tld/sarah.connor/mail/new/ | wc -l"
  assert_success
  assert_output 1
}

@test "checking smtp: sarah.connor should have received 1 spam (with manual IMAP COPY to Spam folder) (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "ls -A /var/mail/vhosts/domain.tld/sarah.connor/mail/.Spam/cur/ | wc -l"
  assert_success
  assert_output 1
}

@test "checking smtp: john.connor should have received 2 mails (hostmaster_forward + postmaster_alias) (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "ls -A /var/mail/vhosts/domain.tld/john.connor/mail/new/ | wc -l"
  assert_success
  assert_output 2
}

@test "checking smtp: rejects mail to unknown user (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "grep '<ghost@domain.tld>: Recipient address rejected: User unknown in virtual mailbox table' /var/log/mail.log | wc -l"
  assert_success
  assert_output 1
}

@test "checking smtp: delivers mail to existing forward (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "grep 'to=<john.doe@domain.tld>, orig_to=<hostmaster@domain.tld>' /var/log/mail.log | grep 'status=sent' | wc -l"
  assert_success
  assert_output 1
}

@test "checking smtp: delivers mail to existing alias (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "grep 'to=<john.doe@domain.tld>, orig_to=<postmaster@domain.tld>' /var/log/mail.log | grep 'status=sent' | wc -l"
  assert_success
  assert_output 1
}

@test "checking smtp: delivers mail to existing forward (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "grep 'to=<john.connor@domain.tld>, orig_to=<hostmaster@domain.tld>' /var/log/mail.log | grep 'status=sent' | wc -l"
  assert_success
  assert_output 1
}

@test "checking smtp: delivers mail to existing alias (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "grep 'to=<john.connor@domain.tld>, orig_to=<postmaster@domain.tld>' /var/log/mail.log | grep 'status=sent' | wc -l"
  assert_success
  assert_output 1
}

#
# imap
#

@test "checking imap (143): STARTTLS login works with good password (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:143 -starttls imap < /tmp/tests/auth/imap-auth.txt 2>&1 | grep -i 'logged in'"
  assert_success
}

@test "checking imaps (993): SSL/TLS login works with good password (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:993 < /tmp/tests/auth/imap-auth.txt 2>&1 | grep -i 'logged in'"
  assert_success
}

@test "checking imaps (993): SSL/TLS login fails with good master password on no master config (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:993 < /tmp/tests/auth/imap-auth-master.txt 2>&1 | grep -i 'authentication failed'"
  assert_success
}

# rspamd

@test "checking rspamd: spam filtered (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "grep -i 'Gtube pattern; from=<spam@gmail.com> to=<john.doe@domain.tld> ' /var/log/mail.log | wc -l"
  assert_success
  assert_output 1
}

#
# accounts
#

@test "checking accounts: user accounts (ldap configuration)" {
  run docker exec mailserver_ldap doveadm user '*'
  assert_success
  [ "${lines[0]}" = "john.doe@domain.tld" ]
  [ "${lines[1]}" = "sarah.connor@domain.tld" ]
  [ "${lines[2]}" = "john.connor@domain.tld" ]
}

@test "checking accounts: user accounts (ldap2 configuration)" {
  run docker exec mailserver_ldap doveadm user '*'
  assert_success
  [ "${lines[0]}" = "john.doe@domain.tld" ]
  [ "${lines[1]}" = "sarah.connor@domain.tld" ]
  [ "${lines[2]}" = "john.connor@domain.tld" ]
}

@test "checking accounts: user quotas (ldap configuration)" {
  run docker exec mailserver_ldap /bin/bash -c "doveadm quota get -A 2>&1 | grep '1000' | wc -l"
  assert_success
  assert_output 1
  run docker exec mailserver_ldap /bin/bash -c "doveadm quota get -A 2>&1 | grep '2000' | wc -l"
  assert_success
  assert_output 1
  run docker exec mailserver_ldap /bin/bash -c "doveadm quota get -A 2>&1 | grep '4000' | wc -l"
  assert_success
  assert_output 1
}

#
# dkim
#

@test "checking dkim: all key pairs are generated (ldap configuration)" {
  run docker exec mailserver_ldap /bin/bash -c "ls -A /var/mail/dkim/*/mail20190101.{private.key,public.key} | wc -l"
  assert_success
  assert_output 6
}

#
# postfix
#

@test "checking postfix: mynetworks value (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "postconf -h mynetworks"
  assert_success
  assert_output "127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128"
}

@test "checking postfix: smtp_tls_security_level value (ldap configuration)" {
  run docker exec mailserver_ldap postconf -h smtp_tls_security_level
  assert_success
  assert_output "dane"
}

@test "checking postfix: smtp_dns_support_level value (ldap configuration)" {
  run docker exec mailserver_ldap postconf -h smtp_dns_support_level
  assert_success
  assert_output "dnssec"
}

@test "checking postfix: smtpd_sender_login ldap maps (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "postconf -h smtpd_sender_login_maps | grep 'ldap'"
  assert_success
}

#
# dovecot
#

@test "checking dovecot: login_greeting value (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "doveconf -h login_greeting 2>/dev/null"
  assert_success
  assert_output "Do. Or do not. There is no try."
}

@test "checking dovecot: debug mode disabled (ldap configuration)" {
  run docker exec mailserver_ldap /bin/sh -c "doveconf -h auth_verbose 2>/dev/null"
  assert_success
  assert_output "no"
  run docker exec mailserver_ldap /bin/sh -c "doveconf -h auth_verbose_passwords 2>/dev/null"
  assert_success
  assert_output "no"
  run docker exec mailserver_ldap /bin/sh -c "doveconf -h auth_debug 2>/dev/null"
  assert_success
  assert_output "no"
  run docker exec mailserver_ldap /bin/sh -c "doveconf -h auth_debug_passwords 2>/dev/null"
  assert_success
  assert_output "no"
  run docker exec mailserver_ldap /bin/sh -c "doveconf -h mail_debug 2>/dev/null"
  assert_success
  assert_output "no"
  run docker exec mailserver_ldap /bin/sh -c "doveconf -h verbose_ssl 2>/dev/null"
  assert_success
  assert_output "no"
}

#
# unbound
#

@test "checking unbound: /etc/resolv.conf (ldap configuration)" {
  run docker exec mailserver_ldap cat /etc/resolv.conf
  assert_success
  assert_output "nameserver 127.0.0.1"
}

@test "checking unbound: /var/mail/postfix/spool/etc/resolv.conf (ldap configuration)" {
  run docker exec mailserver_ldap cat /var/mail/postfix/spool/etc/resolv.conf
  assert_success
  assert_output "nameserver 127.0.0.1"
}

@test "checking unbound: root.hints exist (ldap configuration)" {
  run docker exec mailserver_ldap [ -f /etc/unbound/root.hints ]
  assert_success
}

@test "checking unbound: root.key exist (ldap configuration)" {
  run docker exec mailserver_ldap [ -f /etc/unbound/root.key ]
  assert_success
}

#
# ldap
#

@test "checking ldap maps exist in postfix main.cf in ldap configurations" {
  run docker exec mailserver_ldap grep -i 'ldap:' /etc/postfix/main.cf
  assert_success
}

@test "checking no sql maps exist in postfix main.cf in ldap configurations" {
  run docker exec mailserver_ldap grep -i 'sql' /etc/postfix/main.cf
  assert_failure
}

@test "checking ldap alias, forward and group maps exist in postfix main.cf in ldap configurations" {
  run docker exec mailserver_ldap grep -i 'ldap:/etc/postfix/ldap/virtual-alias-maps.cf' /etc/postfix/main.cf
  assert_success
  run docker exec mailserver_ldap grep -i 'ldap:/etc/postfix/ldap/virtual-forward-maps.cf' /etc/postfix/main.cf
  assert_success
  run docker exec mailserver_ldap grep -i 'ldap:/etc/postfix/ldap/virtual-group-maps.cf' /etc/postfix/main.cf
  assert_success
}

@test "checking ldap master only exists in ldap2 configurations" {
  run docker exec mailserver_ldap grep -i 'master' /etc/dovecot/conf.d/auth-ldap.conf.ext
  assert_failure
}

#
# logs
#

@test "checking logs: /var/log/mail.log in mailserver_ldap is error free" {
  run docker exec mailserver_ldap grep -i ': error:' /var/log/mail.log
  assert_failure
  run docker exec mailserver_ldap grep -i 'is not writable' /var/log/mail.log
  assert_failure
  run docker exec mailserver_ldap grep -i 'permission denied' /var/log/mail.log
  assert_failure
  run docker exec mailserver_ldap grep -i 'address already in use' /var/log/mail.log
  assert_failure
}

@test "checking logs: /var/log/mail.err in mailserver_ldap does not exist" {
  run docker exec mailserver_ldap cat /var/log/mail.err
  assert_failure
  assert_output --partial 'No such file or directory'
}
