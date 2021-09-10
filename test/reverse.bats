load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

#
# system
#

@test "checking system: /etc/mailname (env method) (reverse)" {
  run docker exec mailserver_reverse cat /etc/mailname
  assert_success
  assert_output "mail.domain.tld"
}

@test "checking system: all environment variables have been replaced (reverse configuration)" {
  run docker exec mailserver_reverse /bin/bash -c "egrep -R -I "{{.*}}" /etc/postfix /etc/postfixadmin/fetchmail.conf /etc/dovecot /etc/rspamd /etc/cron.d /etc/mailname /usr/local/bin"
  assert_failure
}

#
# processes (reverse configuration)
#

@test "checking process: s6           (reverse configuration)" {
  run docker exec mailserver_reverse /bin/bash -c "ps aux --forest | grep '[s]6-svscan /services'"
  assert_success
}

@test "checking process: rsyslog      (reverse configuration)" {
  run docker exec mailserver_reverse /bin/bash -c "ps aux --forest | grep '[s]6-supervise rsyslogd'"
  assert_success
  run docker exec mailserver_reverse /bin/bash -c "ps aux --forest | grep '[r]syslogd -n -f /etc/rsyslog/rsyslog.conf'"
  assert_success
}

@test "checking process: cron         (reverse configuration)" {
  run docker exec mailserver_reverse /bin/bash -c "ps aux --forest | grep '[s]6-supervise cron'"
  assert_success
  run docker exec mailserver_reverse /bin/bash -c "ps aux --forest | grep '[c]ron -f'"
  assert_success
}

@test "checking process: postfix      (reverse configuration)" {
  run docker exec mailserver_reverse /bin/bash -c "ps aux --forest | grep '[s]6-supervise postfix'"
  assert_success
  run docker exec mailserver_reverse /bin/bash -c "ps aux --forest | grep '[/]usr/lib/postfix/sbin/master -s'"
  assert_success
}

@test "checking process: dovecot      (reverse configuration)" {
  run docker exec mailserver_reverse /bin/bash -c "ps aux --forest | grep '[s]6-supervise dovecot'"
  assert_success
  run docker exec mailserver_reverse /bin/bash -c "ps aux --forest | grep '[/]usr/sbin/dovecot -F'"
  assert_success
}

@test "checking process: rspamd       (reverse configuration)" {
  run docker exec mailserver_reverse /bin/bash -c "ps aux --forest | grep '[s]6-supervise rspamd'"
  assert_success
  run docker exec mailserver_reverse /bin/bash -c "ps aux --forest | grep '[r]spamd: main process'"
  assert_success
  run docker exec mailserver_reverse /bin/bash -c "ps aux --forest | grep '[r]spamd: rspamd_proxy process'"
  assert_success
  run docker exec mailserver_reverse /bin/bash -c "ps aux --forest | grep '[r]spamd: controller process'"
  assert_success
}

@test "checking process: clamd        (reverse configuration)" {
  run docker exec mailserver_reverse /bin/bash -c "ps aux --forest | grep '[s]6-supervise clamd'"
  assert_success
  run docker exec mailserver_reverse /bin/bash -c "ps aux --forest | grep -v 's6' | grep '[c]lamd'"
  assert_failure
}

@test "checking process: freshclam    (reverse configuration)" {
  run docker exec mailserver_reverse /bin/bash -c "ps aux --forest | grep '[s]6-supervise freshclam'"
  assert_success
  run docker exec mailserver_reverse /bin/bash -c "ps aux --forest | grep '[f]reshclam -d'"
  assert_failure
}

@test "checking process: unbound      (reverse configuration)" {
  run docker exec mailserver_reverse /bin/bash -c "ps aux --forest | grep '[s]6-supervise unbound'"
  assert_success
  run docker exec mailserver_reverse /bin/bash -c "ps aux --forest | grep -v 's6' | grep '[u]nbound'"
  assert_failure
}

@test "checking process: cert_watcher (reverse configuration)" {
  run docker exec mailserver_reverse /bin/bash -c "ps aux --forest | grep '[s]6-supervise cert_watcher'"
  assert_success
}

#
# processes restarting
#

@test "checking process: 10 cron tasks to reset all the process counters" {
  run docker exec mailserver_reverse /bin/bash -c "cat /etc/cron.d/counters | wc -l"
  assert_success
  assert_output 10
}

@test "checking process: no service restarted (reverse configuration)" {
  run docker exec mailserver_reverse cat /tmp/counters/_parent
  assert_success
  assert_output 0
  run docker exec mailserver_reverse cat /tmp/counters/clamd
  assert_success
  assert_output 0
  run docker exec mailserver_reverse cat /tmp/counters/cron
  assert_success
  assert_output 0
  run docker exec mailserver_reverse cat /tmp/counters/dovecot
  assert_success
  assert_output 0
  run docker exec mailserver_reverse cat /tmp/counters/freshclam
  assert_success
  assert_output 0
  run docker exec mailserver_reverse cat /tmp/counters/postfix
  assert_success
  assert_output 0
  run docker exec mailserver_reverse cat /tmp/counters/rspamd
  assert_success
  assert_output 0
  run docker exec mailserver_reverse cat /tmp/counters/rsyslogd
  assert_success
  assert_output 0
  run docker exec mailserver_reverse cat /tmp/counters/unbound
  assert_success
  assert_output 0
  run docker exec mailserver_reverse cat /tmp/counters/cert_watcher
  assert_success
  assert_output 0
}

#
# ports
#

@test "checking port    (25): external port listening (reverse configuration)" {
  run docker exec mailserver_reverse /bin/sh -c "nc -z 0.0.0.0 25"
  assert_success
}

@test "checking port    (53): internal port listening (reverse configuration)" {
  run docker exec mailserver_reverse /bin/sh -c "nc -z 127.0.0.1 53"
  assert_failure
}

@test "checking port   (110): external port listening (reverse configuration)" {
  run docker exec mailserver_reverse /bin/sh -c "nc -z 0.0.0.0 110"
  assert_success
}

@test "checking port   (143): external port listening (reverse configuration)" {
  run docker exec mailserver_reverse /bin/sh -c "nc -z 0.0.0.0 143"
  assert_success
}

@test "checking port   (465): external port listening (reverse configuration)" {
  run docker exec mailserver_reverse /bin/sh -c "nc -z 0.0.0.0 465"
  assert_success
}

@test "checking port   (587): external port listening (reverse configuration)" {
  run docker exec mailserver_reverse /bin/sh -c "nc -z 0.0.0.0 587"
  assert_success
}

@test "checking port   (993): external port listening (reverse configuration)" {
  run docker exec mailserver_reverse /bin/sh -c "nc -z 0.0.0.0 993"
  assert_success
}

@test "checking port   (995): external port listening (reverse configuration)" {
  run docker exec mailserver_reverse /bin/sh -c "nc -z 0.0.0.0 995"
  assert_success
}

@test "checking port  (3310): external port closed    (reverse configuration)" {
  run docker exec mailserver_reverse /bin/sh -c "nc -z 0.0.0.0 3310"
  assert_failure
}

@test "checking port  (4190): external port closed    (reverse configuration)" {
  run docker exec mailserver_reverse /bin/sh -c "nc -z 0.0.0.0 4190"
  assert_failure
}

@test "checking port  (8953): internal port listening (reverse configuration)" {
  run docker exec mailserver_reverse /bin/sh -c "nc -z 127.0.0.1 8953"
  assert_failure
}

@test "checking port (10025): internal port listening (reverse configuration)" {
  run docker exec mailserver_reverse /bin/sh -c "nc -z 127.0.0.1 10025"
  assert_success
}

@test "checking port (10026): internal port listening (reverse configuration)" {
  run docker exec mailserver_reverse /bin/sh -c "nc -z 127.0.0.1 10026"
  assert_success
}

@test "checking port (11332): external port listening (reverse configuration)" {
  run docker exec mailserver_reverse /bin/sh -c "nc -z 0.0.0.0 11332"
  assert_success
}

@test "checking port (11334): external port listening (reverse configuration)" {
  run docker exec mailserver_reverse /bin/sh -c "nc -z 0.0.0.0 11334"
  assert_success
}

#
# sasl
#

@test "checking sasl: dovecot auth with good password (reverse configuration)" {
  run docker exec mailserver_reverse /bin/sh -c "doveadm auth test sarah.connor@domain.tld testpasswd12 | grep 'auth succeeded'"
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

@test "checking smtp (25): STARTTLS AUTH PLAIN works with good password (reverse configuration)" {
  run docker exec mailserver_reverse /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:25 -starttls smtp < /tmp/tests/auth/smtp-auth-plain.txt 2>&1 | grep -i 'authentication successful'"
  assert_success
}

@test "checking submission (587): STARTTLS AUTH LOGIN works with good password (reverse configuration)" {
  run docker exec mailserver_reverse /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:587 -starttls smtp < /tmp/tests/auth/smtp-auth-login.txt 2>&1 | grep -i 'authentication successful'"
  assert_success
}

@test "checking smtps (465): SSL/TLS AUTH LOGIN works with good password (reverse configuration)" {
  run docker exec mailserver_reverse /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:465 < /tmp/tests/auth/smtp-auth-login.txt 2>&1 | grep -i 'authentication successful'"
  assert_success
}

@test "checking smtp: john.doe should have received 4 mails (internal + external + subaddress + hostmaster alias) (reverse configuration)" {
  run docker exec mailserver_reverse /bin/sh -c "ls -A /var/mail/vhosts/domain.tld/john.doe/subdir/new/ | wc -l"
  assert_success
  assert_output 4
}

@test "checking smtp: rejects mail to unknown user (reverse configuration)" {
  run docker exec mailserver_reverse /bin/sh -c "grep '<ghost@domain.tld>: Recipient address rejected: User unknown in virtual mailbox table' /var/log/mail.log | wc -l"
  assert_success
  assert_output 1
}

@test "checking smtp: delivers mail to existing alias (reverse configuration)" {
  run docker exec mailserver_reverse /bin/sh -c "grep 'to=<john.doe@domain.tld>, orig_to=<hostmaster@domain.tld>' /var/log/mail.log | grep 'status=sent' | wc -l"
  assert_success
  assert_output 1
}

#
# imap
#

@test "checking imap (143): STARTTLS login works with good password (reverse configuration)" {
  run docker exec mailserver_reverse /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:143 -starttls imap < /tmp/tests/auth/imap-auth.txt 2>&1 | grep -i 'logged in'"
  assert_success
}

@test "checking imaps (993): SSL/TLS login works with good password (reverse configuration)" {
  run docker exec mailserver_reverse /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:993 < /tmp/tests/auth/imap-auth.txt 2>&1 | grep -i 'logged in'"
  assert_success
}

#
# pop
#

@test "checking pop3 (110): STARTTLS login works with good password" {
  run docker exec mailserver_reverse /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:110 -starttls pop3 < /tmp/tests/auth/pop3-auth.txt 2>&1 | grep -i 'ok logged in'"
  assert_success
}

@test "checking pop3 (110): STARTTLS login fails with bad password" {
  run docker exec mailserver_reverse /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:110 -starttls pop3 < /tmp/tests/auth/pop3-auth-wrong.txt 2>&1 | grep -i 'authentication failed'"
  assert_success
}

@test "checking pop3s (995): SSL/TLS login works with good password" {
  run docker exec mailserver_reverse /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:995 < /tmp/tests/auth/pop3-auth.txt 2>&1 | grep -i 'ok logged in'"
  assert_success
}

@test "checking pop3s (995): SSL/TLS login fails with bad password" {
  run docker exec mailserver_reverse /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:995 < /tmp/tests/auth/pop3-auth-wrong.txt 2>&1 | grep -i 'authentication failed'"
  assert_success
}

# rspamd

@test "checking rspamd: spam filtered (reverse configuration)" {
  run docker exec mailserver_reverse /bin/sh -c "grep -i 'Gtube pattern; from=<spam@gmail.com> to=<john.doe@domain.tld> ' /var/log/mail.log | wc -l"
  assert_success
  assert_output 1
}

@test "checking rspamd: dkim/arc signing is disabled (reverse configuration)" {
  run docker exec mailserver_reverse cat /etc/rspamd/local.d/arc.conf
  assert_success
  assert_output "enabled = false;"
  run docker exec mailserver_reverse cat /etc/rspamd/local.d/dkim_signing.conf
  assert_success
  assert_output "enabled = false;"
}

@test "checking rspamd: greylisting policy is disabled (reverse configuration)" {
  run docker exec mailserver_reverse cat /etc/rspamd/local.d/greylisting.conf
  assert_success
  assert_output "enabled = false;"
}

@test "checking rspamd: ratelimiting policy is disabled (reverse configuration)" {
  run docker exec mailserver_reverse cat /etc/rspamd/local.d/ratelimit.conf
  assert_success
  assert_output "enabled = false;"
}

#
# accounts
#

@test "checking accounts: user accounts (reverse configuration)" {
  run docker exec mailserver_reverse doveadm user '*'
  assert_success
  [ "${lines[0]}" = "john.doe@domain.tld" ]
  [ "${lines[1]}" = "sarah.connor@domain.tld" ]
}

@test "checking accounts: user quotas (reverse configuration)" {
  run docker exec mailserver_reverse /bin/bash -c "doveadm quota get -A 2>&1 | grep '1000' | wc -l"
  assert_success
  assert_output 2
}

#
# dkim
#

@test "checking dkim: all key pairs are generated (reverse configuration)" {
  run docker exec mailserver_reverse /bin/bash -c "ls -A /var/mail/dkim/*/other.{private.key,public.key} | wc -l"
  assert_success
  assert_output 2
}

@test "checking dkim: control the size of the RSA key pair (4096bits)" {
  run docker exec mailserver_reverse /bin/bash -c "openssl rsa -in /var/mail/dkim/domain.tld/other.private.key -text -noout | grep -i 'Private-Key: (4096 bit, 2 primes)'"
  assert_success
}

#
# postfix
#

@test "checking postfix: mynetworks value (reverse configuration)" {
  run docker exec mailserver_reverse /bin/sh -c "postconf -h mynetworks"
  assert_success
  assert_output "127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128 192.168.0.0/16 172.16.0.0/12 10.0.0.0/8"
}

@test "checking postfix: myorigin value (env method)" {
  run docker exec mailserver_reverse postconf -h myorigin
  assert_success
  assert_output "mail.domain.tld"
}

@test "checking postfix: smtp_tls_security_level value (reverse configuration)" {
  run docker exec mailserver_reverse postconf -h smtp_tls_security_level
  assert_success
  assert_output "may"
}

@test "checking postfix: smtp_dns_support_level value (reverse configuration)" {
  run docker exec mailserver_reverse postconf -h smtp_dns_support_level
  assert_success
  assert_output ""
}

@test "checking postfix: smtpd_sender_login pgsql maps (reverse configuration)" {
  run docker exec mailserver_reverse /bin/sh -c "postconf -h smtpd_sender_login_maps | grep 'pgsql'"
  assert_success
}

#
# dovecot
#

@test "checking dovecot: custom sieve file is used" {
  run docker exec mailserver_reverse /bin/sh -c "wc -l < /var/mail/sieve/default.sieve"
  assert_success
  assert_output 4
}

@test "checking dovecot: login_greeting value (reverse configuration)" {
  run docker exec mailserver_reverse /bin/sh -c "doveconf -h login_greeting 2>/dev/null"
  assert_success
  assert_output "Dovecot (Debian) ready."
}

@test "checking dovecot: quota dict pgsql (reverse configuration)" {
  run docker exec mailserver_reverse /bin/sh -c "doveconf dict sqlquota 2>/dev/null | grep 'pgsql'"
  assert_success
}

#
# clamav-unofficial-sigs
#

@test "checking clamav-unofficial-sigs: cron task doesn't exist (reverse configuration)" {
  run docker exec mailserver_reverse [ -f /etc/cron.d/clamav-unofficial-sigs ]
  assert_failure
}

@test "checking clamav-unofficial-sigs: logrotate task doesn't exist (reverse configuration)" {
  run docker exec mailserver_reverse [ -f /etc/logrotate.d/clamav-unofficial-sigs ]
  assert_failure
}

#
# zeyple
#

@test "checking zeyple: 4 messages delivered via zeyple service" {
  run docker exec mailserver_reverse /bin/sh -c "grep -i 'delivered via zeyple service' /var/log/mail.log | wc -l"
  assert_success
  assert_output 4
}

@test "checking zeyple: 'processing outgoing message' 4 times in logs" {
  run docker exec mailserver_reverse /bin/sh -c "grep -i 'Processing outgoing message' /var/log/zeyple.log | wc -l"
  assert_success
  assert_output 4
}

@test "checking zeyple: zeyple.py exist (reverse configuration)" {
  run docker exec mailserver_reverse [ -f /usr/local/bin/zeyple.py ]
  assert_success
}

@test "checking zeyple: zeyple.log exist (reverse configuration)" {
  run docker exec mailserver_reverse [ -f /var/log/zeyple.log ]
  assert_success
}

@test "checking zeyple: pubring.kbx exist (reverse configuration)" {
  run docker exec mailserver_reverse [ -f /var/mail/zeyple/keys/pubring.kbx ]
  assert_success
}

@test "checking zeyple: trustdb.gpg exist (reverse configuration)" {
  run docker exec mailserver_reverse [ -f /var/mail/zeyple/keys/trustdb.gpg ]
  assert_success
}

@test "checking zeyple: content_filter value (reverse configuration)" {
  run docker exec mailserver_reverse /bin/sh -c "postconf -h content_filter"
  assert_success
  assert_output "zeyple"
}

@test "checking zeyple: user zeyple exist (reverse configuration)" {
  run docker exec mailserver_reverse /bin/sh -c "id -u zeyple"
  assert_success
}

@test "checking zeyple: retrieve john doe gpg key in public keyring" {
  run docker exec mailserver_reverse /bin/sh -c "s6-setuidgid zeyple gpg --homedir /var/mail/zeyple/keys --with-colons --list-keys | grep 'John Doe (test key) <john.doe@domain.tld>' | wc -l"
  assert_success
  assert_output 1
}

@test "checking zeyple: retrieve john doe gpg key in public keyring (using custom script)" {
  run docker exec mailserver_reverse /bin/sh -c "encryption.sh --with-colons --list-keys | grep 'John Doe (test key) <john.doe@domain.tld>' | wc -l"
  assert_success
  assert_output 1
}

@test "checking zeyple: 3 emails encrypted in john.doe folder" {
  run docker exec mailserver_reverse /bin/sh -c "gzip -cd /var/mail/vhosts/domain.tld/john.doe/subdir/new/* | grep -i 'multipart/encrypted' | wc -l"
  assert_success
  assert_output 3
  run docker exec mailserver_reverse /bin/sh -c "gzip -cd /var/mail/vhosts/domain.tld/john.doe/subdir/new/* | grep -i 'BEGIN PGP MESSAGE' | wc -l"
  assert_success
  assert_output 3
  run docker exec mailserver_reverse /bin/sh -c "gzip -cd /var/mail/vhosts/domain.tld/john.doe/subdir/new/* | grep -i 'END PGP MESSAGE' | wc -l"
  assert_success
  assert_output 3
}

#
# unbound
#

@test "checking unbound: /etc/resolv.conf (reverse configuration)" {
  run docker exec mailserver_reverse cat /etc/resolv.conf
  assert_success
  refute_output "nameserver 127.0.0.1"
}

@test "checking unbound: /var/mail/postfix/spool/etc/resolv.conf (reverse configuration)" {
  run docker exec mailserver_reverse cat /var/mail/postfix/spool/etc/resolv.conf
  assert_success
  refute_output "nameserver 127.0.0.1"
}

@test "checking unbound: root.hints doesn't exist (reverse configuration)" {
  run docker exec mailserver_reverse [ ! -f /etc/unbound/root.hints ]
  assert_success
}

@test "checking unbound: root.key doesn't exist (reverse configuration)" {
  run docker exec mailserver_reverse [ ! -f /etc/unbound/root.key ]
  assert_success
}

#
# ssl
#

@test "checking ssl: let's encrypt cert works correctly" {
  run docker exec mailserver_reverse /bin/sh -c "timeout 1 openssl s_client -ign_eof -connect 0.0.0.0:587 -starttls smtp | grep 'Verify return code: 10 (certificate has expired)'"
  assert_success
}

@test "checking ssl: let's encrypt configuration is correct" {
  run docker exec mailserver_reverse /bin/sh -c "grep '/ssl' /etc/postfix/main.cf | wc -l"
  assert_success
  assert_output 4
  run docker exec mailserver_reverse /bin/sh -c "grep '/ssl' /etc/dovecot/conf.d/10-ssl.conf | wc -l"
  assert_success
  assert_output 2
}

#
# logs
#

@test "checking logs: /var/log/mail.log in mailserver_reverse is error free " {
  run docker exec mailserver_reverse grep -i ': error:' /var/log/mail.log
  assert_failure
  run docker exec mailserver_reverse grep -i 'is not writable' /var/log/mail.log
  assert_failure
  run docker exec mailserver_reverse grep -i 'permission denied' /var/log/mail.log
  assert_failure
  run docker exec mailserver_reverse grep -i 'address already in use' /var/log/mail.log
  assert_failure
}

@test "checking logs: /var/log/mail.err in mailserver_reverse does not exist" {
  run docker exec mailserver_reverse cat /var/log/mail.err
  assert_failure
  assert_output --partial 'No such file or directory'
}
