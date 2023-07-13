load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

#
# system
#

@test "checking system: /etc/mailname (docker method) (default)" {
  run docker exec mailserver_default cat /etc/mailname
  assert_success
  assert_output "mail.domain.tld"
}

@test "checking system: /etc/hostname" {
  run docker exec mailserver_default cat /etc/hostname
  assert_success
  assert_output "mail.domain.tld"
}

@test "checking system: /etc/hosts" {
  run docker exec mailserver_default grep "mail.domain.tld" /etc/hosts
  assert_success
}

@test "checking system: fqdn" {
  run docker exec mailserver_default hostname -f
  assert_success
  assert_output "mail.domain.tld"
}

@test "checking system: domain" {
  run docker exec mailserver_default hostname -d
  assert_success
  assert_output "domain.tld"
}

@test "checking system: hostname" {
  run docker exec mailserver_default hostname -s
  assert_success
  assert_output "mail"
}

@test "checking system: all environment variables have been replaced (default configuration)" {
  run docker exec mailserver_default /bin/bash -c "egrep -R -I "{{.*}}" /etc/postfix /etc/postfixadmin/fetchmail.conf /etc/dovecot /etc/rspamd /etc/cron.d /etc/mailname /usr/local/bin"
  assert_failure
}

#
# processes (default configuration)
#

@test "checking process: s6           (default configuration)" {
  run docker exec mailserver_default /bin/bash -c "ps aux --forest | grep '[s]6-svscan /services'"
  assert_success
}

@test "checking process: rsyslog      (default configuration)" {
  run docker exec mailserver_default /bin/bash -c "ps aux --forest | grep '[s]6-supervise rsyslogd'"
  assert_success
  run docker exec mailserver_default /bin/bash -c "ps aux --forest | grep '[r]syslogd -n -f /etc/rsyslog/rsyslog.conf'"
  assert_success
}

@test "checking process: cron         (default configuration)" {
  run docker exec mailserver_default /bin/bash -c "ps aux --forest | grep '[s]6-supervise cron'"
  assert_success
  run docker exec mailserver_default /bin/bash -c "ps aux --forest | grep '[c]ron -f'"
  assert_success
}

@test "checking process: postfix      (default configuration)" {
  run docker exec mailserver_default /bin/bash -c "ps aux --forest | grep '[s]6-supervise postfix'"
  assert_success
  run docker exec mailserver_default /bin/bash -c "ps aux --forest | grep '[/]usr/lib/postfix/sbin/master -s'"
  assert_success
}

@test "checking process: dovecot      (default configuration)" {
  run docker exec mailserver_default /bin/bash -c "ps aux --forest | grep '[s]6-supervise dovecot'"
  assert_success
  run docker exec mailserver_default /bin/bash -c "ps aux --forest | grep '[/]usr/sbin/dovecot -F'"
  assert_success
}

@test "checking process: rspamd       (default configuration)" {
  run docker exec mailserver_default /bin/bash -c "ps aux --forest | grep '[s]6-supervise rspamd'"
  assert_success
  run docker exec mailserver_default /bin/bash -c "ps aux --forest | grep '[r]spamd: main process'"
  assert_success
  run docker exec mailserver_default /bin/bash -c "ps aux --forest | grep '[r]spamd: rspamd_proxy process'"
  assert_success
  run docker exec mailserver_default /bin/bash -c "ps aux --forest | grep '[r]spamd: controller process'"
  assert_success
}

@test "checking process: clamd        (default configuration)" {
  run docker exec mailserver_default /bin/bash -c "ps aux --forest | grep '[s]6-supervise clamd'"
  assert_success
  run docker exec mailserver_default /bin/bash -c "ps aux --forest | grep -v 's6' | grep '[c]lamd'"
  assert_success
}

@test "checking process: freshclam    (default configuration)" {
  run docker exec mailserver_default /bin/bash -c "ps aux --forest | grep '[s]6-supervise freshclam'"
  assert_success
  run docker exec mailserver_default /bin/bash -c "ps aux --forest | grep '[f]reshclam -d'"
  assert_success
}

@test "checking process: unbound      (default configuration)" {
  run docker exec mailserver_default /bin/bash -c "ps aux --forest | grep '[s]6-supervise unbound'"
  assert_success
  run docker exec mailserver_default /bin/bash -c "ps aux --forest | grep -v 's6' | grep '[u]nbound'"
  assert_success
}

@test "checking process: cert_watcher (default configuration)" {
  run docker exec mailserver_default /bin/bash -c "ps aux --forest | grep '[s]6-supervise cert_watcher'"
  assert_success
}

#
# processes restarting
#

@test "checking process: 10 cron tasks to reset all the process counters" {
  run docker exec mailserver_default /bin/bash -c "cat /etc/cron.d/counters | wc -l"
  assert_success
  assert_output 10
}

@test "checking process: no service restarted (default configuration)" {
  run docker exec mailserver_default cat /tmp/counters/_parent
  assert_success
  assert_output 0
  run docker exec mailserver_default cat /tmp/counters/clamd
  assert_success
  assert_output 0
  run docker exec mailserver_default cat /tmp/counters/cron
  assert_success
  assert_output 0
  run docker exec mailserver_default cat /tmp/counters/dovecot
  assert_success
  assert_output 0
  run docker exec mailserver_default cat /tmp/counters/freshclam
  assert_success
  assert_output 0
  run docker exec mailserver_default cat /tmp/counters/postfix
  assert_success
  assert_output 0
  run docker exec mailserver_default cat /tmp/counters/rspamd
  assert_success
  assert_output 0
  run docker exec mailserver_default cat /tmp/counters/rsyslogd
  assert_success
  assert_output 0
  run docker exec mailserver_default cat /tmp/counters/unbound
  assert_success
  assert_output 0
  run docker exec mailserver_default cat /tmp/counters/cert_watcher
  assert_success
  assert_output 0
}

#
# ports
#

@test "checking port    (25): external port listening (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "nc -z 0.0.0.0 25"
  assert_success
}

@test "checking port    (53): internal port listening (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "nc -z 127.0.0.1 53"
  assert_success
}

@test "checking port   (110): external port closed    (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "nc -z 0.0.0.0 110"
  assert_failure
}

@test "checking port   (143): external port listening (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "nc -z 0.0.0.0 143"
  assert_success
}

@test "checking port   (465): external port listening (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "nc -z 0.0.0.0 465"
  assert_success
}

@test "checking port   (587): external port listening (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "nc -z 0.0.0.0 587"
  assert_success
}

@test "checking port   (993): external port listening (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "nc -z 0.0.0.0 993"
  assert_success
}

@test "checking port   (995): external port closed    (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "nc -z 0.0.0.0 995"
  assert_failure
}

@test "checking port  (3310): external port listening (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "nc -z 0.0.0.0 3310"
  assert_success
}

@test "checking port  (4190): external port listening (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "nc -z 0.0.0.0 4190"
  assert_success
}

@test "checking port  (8953): internal port listening (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "nc -z 127.0.0.1 8953"
  assert_success
}

@test "checking port (10025): internal port closed    (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "nc -z 127.0.0.1 10025"
  assert_failure
}

@test "checking port (10026): internal port listening (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "nc -z 127.0.0.1 10026"
  assert_success
}

@test "checking port (11332): external port listening (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "nc -z 0.0.0.0 11332"
  assert_success
}

@test "checking port (11334): external port listening (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "nc -z 0.0.0.0 11334"
  assert_success
}

#
# sasl
#

@test "checking sasl: dovecot auth with good password (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "doveadm auth test sarah.connor@domain.tld testpasswd12 | grep 'auth succeeded'"
  assert_success
}

@test "checking sasl: dovecot auth with bad password (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "doveadm auth test sarah.connor@domain.tld badpassword | grep 'auth failed'"
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

@test "checking smtp (25): STARTTLS AUTH PLAIN works with good password (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:25 -starttls smtp < /tmp/tests/auth/smtp-auth-plain.txt 2>&1 | grep -i 'authentication successful'"
  assert_success
}

@test "checking smtp (25): STARTTLS AUTH PLAIN fails with bad password" {
  run docker exec mailserver_default /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:25 -starttls smtp < /tmp/tests/auth/smtp-auth-plain-wrong.txt 2>&1 | grep -i 'authentication failed'"
  assert_success
}

@test "checking smtp (25): clear auth disabled" {
  run docker exec mailserver_default /bin/sh -c "nc -w 2 0.0.0.0 25 < /tmp/tests/auth/smtp-auth-plain.txt | grep -i 'authentication not enabled'"
  assert_success
}

@test "checking submission (587): STARTTLS AUTH LOGIN works with good password (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:587 -starttls smtp < /tmp/tests/auth/smtp-auth-login.txt 2>&1 | grep -i 'authentication successful'"
  assert_success
}

@test "checking submission (587): STARTTLS AUTH LOGIN fails with bad password" {
  run docker exec mailserver_default /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:587 -starttls smtp < /tmp/tests/auth/smtp-auth-login-wrong.txt 2>&1 | grep -i 'authentication failed'"
  assert_success
}

@test "checking submission (587): Auth without STARTTLS fail" {
  run docker exec mailserver_default /bin/sh -c "nc -w 2 0.0.0.0 587 < /tmp/tests/auth/smtp-auth-plain.txt | grep -i 'Must issue a STARTTLS command first'"
  assert_success
}

@test "checking smtps (465): SSL/TLS AUTH LOGIN works with good password (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:465 < /tmp/tests/auth/smtp-auth-login.txt 2>&1 | grep -i 'authentication successful'"
  assert_success
}

@test "checking smtps (465): SSL/TLS AUTH LOGIN fails with bad password" {
  run docker exec mailserver_default /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:465 < /tmp/tests/auth/smtp-auth-login-wrong.txt 2>&1 | grep -i 'authentication failed'"
  assert_success
}

@test "checking smtp: john.doe should have received 4 mails (internal + external + subaddress + hostmaster alias) (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "ls -A /var/mail/vhosts/domain.tld/john.doe/mail/new/ | wc -l"
  assert_success
  assert_output 4
}

@test "checking smtp: sarah.connor should have received 1 mail (internal spam-ham test) (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "ls -A /var/mail/vhosts/domain.tld/sarah.connor/mail/new/ | wc -l"
  assert_success
  assert_output 1
}

@test "checking smtp: sarah.connor should have received 1 spam (with manual IMAP COPY to Spam folder) (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "ls -A /var/mail/vhosts/domain.tld/sarah.connor/mail/.Spam/cur/ | wc -l"
  assert_success
  assert_output 1
}

@test "checking smtp: rejects mail to unknown user (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "grep '<ghost@domain.tld>: Recipient address rejected: User unknown in virtual mailbox table' /var/log/mail.log | wc -l"
  assert_success
  assert_output 1
}

@test "checking smtp: delivers mail to existing alias (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "grep 'to=<john.doe@domain.tld>, orig_to=<hostmaster@domain.tld>' /var/log/mail.log | grep 'status=sent' | wc -l"
  assert_success
  assert_output 1
}

#
# imap
#

@test "checking imap (143): STARTTLS login works with good password (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:143 -starttls imap < /tmp/tests/auth/imap-auth.txt 2>&1 | grep -i 'logged in'"
  assert_success
}

@test "checking imap (143): STARTTLS login fails with bad password" {
  run docker exec mailserver_default /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:143 -starttls imap < /tmp/tests/auth/imap-auth-wrong.txt 2>&1 | grep -i 'authentication failed'"
  assert_success
}

@test "checking imaps (993): SSL/TLS login works with good password (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:993 < /tmp/tests/auth/imap-auth.txt 2>&1 | grep -i 'logged in'"
  assert_success
}

@test "checking imaps (993): SSL/TLS login fails with bad password" {
  run docker exec mailserver_default /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:993 < /tmp/tests/auth/imap-auth-wrong.txt 2>&1 | grep -i 'authentication failed'"
  assert_success
}

# rspamd

@test "checking rspamd: spam filtered (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "grep -i 'Gtube pattern; from=<spam@gmail.com> to=<john.doe@domain.tld> ' /var/log/mail.log | wc -l"
  assert_success
  assert_output 1
}

@test "checking rspamd: existing rrd file" {
  run docker exec mailserver_default [ -f /var/mail/rspamd/rspamd.rrd ]
  assert_success
}

@test "checking rspamd: 7 messages scanned" {
  run docker exec mailserver_default /bin/sh -c "rspamc stat | grep -i 'Messages scanned: 7'"
  assert_success
}

@test "checking rspamd: 5 messages with action no action" {
  run docker exec mailserver_default /bin/sh -c "rspamc stat | grep -i 'Messages with action no action: 5'"
  assert_success
}

@test "checking rspamd: 2 messages with action reject" {
  run docker exec mailserver_default /bin/sh -c "rspamc stat | grep -i 'Messages with action reject: 2'"
  assert_success
}

@test "checking rspamd: 2 messages learned" {
  run docker exec mailserver_default /bin/sh -c "rspamc stat | grep -i 'Messages learned: 2'"
  assert_success
}

@test "checking rspamd: 1 address whitelisted in default configuration" {
  run docker exec mailserver_default /bin/bash -c "grep 'postmaster@domain.tld' /etc/rspamd/local.d/settings.conf | wc -l"
  assert_success
  assert_output 1
}

@test "checking rspamd: debug mode disabled (default configuration)" {
  run docker exec mailserver_default /bin/sh -c 'rspamadm configdump | grep -E "level = \"warning\";"'
  assert_success
}

#
# accounts
#

@test "checking accounts: user accounts (default configuration)" {
  run docker exec mailserver_default doveadm user '*'
  assert_success
  [ "${lines[0]}" = "john.doe@domain.tld" ]
  [ "${lines[1]}" = "sarah.connor@domain.tld" ]
}

@test "checking accounts: user quotas (default configuration)" {
  run docker exec mailserver_default /bin/bash -c "doveadm quota get -A 2>&1 | grep '1000' | wc -l"
  assert_success
  assert_output 2
}

@test "checking accounts: user mail folders for john.doe" {
  run docker exec mailserver_default /bin/bash -c "ls -A /var/mail/vhosts/domain.tld/john.doe/mail/ | grep -E 'cur|new|tmp' | wc -l"
  assert_success
  assert_output 3
}

@test "checking accounts: user mail folders for sarah.connor" {
  run docker exec mailserver_default /bin/bash -c "ls -A /var/mail/vhosts/domain.tld/sarah.connor/mail/ | grep -E '.Spam|cur|new|subscriptions|tmp' | wc -l"
  assert_success
  assert_output 5
}

#
# dkim
#

@test "checking dkim: all key pairs are generated (default configuration)" {
  run docker exec mailserver_default /bin/bash -c "ls -A /var/mail/dkim/*/mail.{private.key,public.key} | wc -l"
  assert_success
  assert_output 6
}

# postfix
#

@test "checking postfix: mynetworks value (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "postconf -h mynetworks"
  assert_success
  assert_output "127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128"
}

@test "checking postfix: main.cf overrides" {
  run docker exec mailserver_default /bin/sh -c "postconf -h max_idle"
  assert_success
  assert_output "600s"

  run docker exec mailserver_default /bin/sh -c "postconf -h readme_directory"
  assert_success
  assert_output "/tmp"
}

@test "checking postfix: headers cleanup" {
  run docker exec mailserver_default /bin/sh -c "grep -i 'replace: header Received' /var/log/mail.log | wc -l"
  assert_success
  assert_output 1
}

@test "checking postfix: myorigin value (docker method)" {
  run docker exec mailserver_default postconf -h myorigin
  assert_success
  assert_output "mail.domain.tld"
}

@test "checking postfix: two milter rejects (GTUBE + EICAR)" {
  run docker exec mailserver_default /bin/sh -c "grep -i 'milter-reject' /var/log/mail.log | wc -l"
  assert_success
  assert_output 2
}

@test "checking postfix: milter-reject - clamav virus found" {
  run docker exec mailserver_default grep -i 'milter-reject.*virus found: ".*EICAR.*"; from=<virus@gmail.com>' /var/log/mail.log
  assert_success
}

@test "checking postfix: check 'etc' files in queue directory" {
  run docker exec mailserver_default [ -f /var/mail/postfix/spool/etc/services ]
  assert_success
  run docker exec mailserver_default [ -f /var/mail/postfix/spool/etc/hosts ]
  assert_success
  run docker exec mailserver_default [ -f /var/mail/postfix/spool/etc/localtime ]
  assert_success
}

@test "checking postfix: check some folders in queue directory" {
  run docker exec mailserver_default [ -d /var/mail/postfix/spool/usr/lib/sasl2 ]
  assert_success
  run docker exec mailserver_default [ -d /var/mail/postfix/spool/usr/lib/zoneinfo ]
  assert_success
}

@test "checking postfix: check dovecot unix sockets in queue directory" {
  run docker exec mailserver_default [ -S /var/mail/postfix/spool/private/dovecot-lmtp ]
  assert_success
  run docker exec mailserver_default [ -S /var/mail/postfix/spool/private/auth ]
  assert_success
}

@test "checking postfix: check group of 'public' and 'maildrop' folders in queue directory" {
  run docker exec mailserver_default /bin/sh -c "stat -c '%G' /var/mail/postfix/spool/public"
  assert_success
  assert_output "postdrop"
  run docker exec mailserver_default /bin/sh -c "stat -c '%G' /var/mail/postfix/spool/maildrop"
  assert_success
  assert_output "postdrop"
}

@test "checking postfix: smtp_tls_security_level value (default configuration)" {
  run docker exec mailserver_default postconf -h smtp_tls_security_level
  assert_success
  assert_output "dane"
}

@test "checking postfix: smtp_dns_support_level value (default configuration)" {
  run docker exec mailserver_default postconf -h smtp_dns_support_level
  assert_success
  assert_output "dnssec"
}

@test "checking postfix: smtpd_sender_login mysql maps (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "postconf -h smtpd_sender_login_maps | grep 'mysql'"
  assert_success
}

@test "checking postfix: verbose mode disabled (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "grep 'smtpd -v' /etc/postfix/master.cf | wc -l"
  assert_success
  assert_output 0
}

@test "checking postfix: master.cf custom service parameter" {
  run docker exec mailserver_default postconf -P submission/inet/syslog_name
  assert_success
  assert_output "submission/inet/syslog_name = postfix/submission-custom"
}

@test "checking postfix: sender access reject john.doe" {
  run docker exec mailserver_default grep -i '<john.doe@domain.tld>: Sender address rejected: Access denied' /var/log/mail.log
  assert_success
}

#
# dovecot
#

@test "checking dovecot: existing instances file" {
  run docker exec mailserver_default [ -f /var/mail/dovecot/instances ]
  assert_success
}

@test "checking dovecot: default lib directory is a symlink" {
  run docker exec mailserver_default [ -L /var/lib/dovecot ]
  assert_success
}

@test "checking dovecot: password scheme is correct" {
  run docker exec mailserver_default /bin/sh -c "grep 'SHA512-CRYPT' /etc/dovecot/dovecot-sql.conf.ext | wc -l"
  assert_success
  assert_output 1
}

@test "checking dovecot: login_greeting value (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "doveconf -h login_greeting 2>/dev/null"
  assert_success
  assert_output "Do. Or do not. There is no try."
}

@test "checking dovecot: mail_max_userip_connections imap value" {
  run docker exec mailserver_default /bin/sh -c "doveconf -h -f protocol=imap mail_max_userip_connections 2>/dev/null"
  assert_success
  assert_output "100"
}

@test "checking dovecot: mail_max_userip_connections pop3 value" {
  run docker exec mailserver_default /bin/sh -c "doveconf -h -f protocol=pop3 mail_max_userip_connections 2>/dev/null"
  assert_success
  assert_output "50"
}

@test "checking dovecot: quota dict mysql (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "doveconf dict sqlquota 2>/dev/null | grep 'mysql'"
  assert_success
}

@test "checking dovecot: debug mode disabled (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "doveconf -h auth_verbose 2>/dev/null"
  assert_success
  assert_output "no"
  run docker exec mailserver_default /bin/sh -c "doveconf -h auth_verbose_passwords 2>/dev/null"
  assert_success
  assert_output "no"
  run docker exec mailserver_default /bin/sh -c "doveconf -h auth_debug 2>/dev/null"
  assert_success
  assert_output "no"
  run docker exec mailserver_default /bin/sh -c "doveconf -h auth_debug_passwords 2>/dev/null"
  assert_success
  assert_output "no"
  run docker exec mailserver_default /bin/sh -c "doveconf -h mail_debug 2>/dev/null"
  assert_success
  assert_output "no"
  run docker exec mailserver_default /bin/sh -c "doveconf -h verbose_ssl 2>/dev/null"
  assert_success
  assert_output "no"
}

#
# clamav
#

@test "checking clamav: TCP Bound to 3310 port" {
  run docker exec mailserver_default grep -i 'TCP: Bound to \[\]:3310' /var/log/mail.log
  assert_success
}

@test "checking clamav: self checking every 3600 seconds" {
  run docker exec mailserver_default grep -i 'clamd\[.*\]: Self checking every 3600 seconds' /var/log/mail.log
  assert_success
}

@test "checking clamav: default lib directory is a symlink" {
  run docker exec mailserver_default [ -L /var/lib/clamav ]
  assert_success
}

@test "checking clamav: Eicar-Test-Signature FOUND" {
  run docker exec mailserver_default grep -i 'EICAR.*FOUND' /var/log/mail.log
  assert_success
}

@test "checking clamav: 6 database mirrors" {
  run docker exec mailserver_default /bin/sh -c "grep 'DatabaseMirror' /etc/clamav/freshclam.conf | wc -l"
  assert_success
  assert_output 6
}

#
# clamav-unofficial-sigs
#

@test "checking clamav-unofficial-sigs: rsync command exist" {
  run docker exec mailserver_default /bin/sh -c "command -v rsync"
  assert_success
  assert_output "/usr/bin/rsync"
}

@test "checking clamav-unofficial-sigs: curl command exist" {
  run docker exec mailserver_default /bin/sh -c "command -v curl"
  assert_success
  assert_output "/usr/bin/curl"
}

@test "checking clamav-unofficial-sigs: clamscan command exist" {
  run docker exec mailserver_default /bin/sh -c "command -v clamscan"
  assert_success
  assert_output "/usr/bin/clamscan"
}

@test "checking clamav-unofficial-sigs: cron task exist" {
  run docker exec mailserver_default [ -f /etc/cron.d/clamav-unofficial-sigs ]
  assert_success
}

@test "checking clamav-unofficial-sigs: logrotate task exist" {
  run docker exec mailserver_default [ -f /etc/logrotate.d/clamav-unofficial-sigs ]
  assert_success
}

# @test "checking clamav-unofficial-sigs: TEST 1 — Html.Sanesecurity.TestSig_Type3_Bdy" {
#   run docker exec mailserver_default /bin/sh -c "clamscan --database=/var/lib/clamav/phish.ndb - < /tmp/tests/clamav/test1.eml"
#   assert_failure
#   assert_output --partial "Sanesecurity.TestSig_Type3_Bdy.4.UNOFFICIAL FOUND"
# }

# @test "checking clamav-unofficial-sigs: TEST 2 — Email.Sanesecurity.TestSig_Type4_Hdr" {
#   run docker exec mailserver_default /bin/sh -c "clamscan --database=/var/lib/clamav/phish.ndb - < /tmp/tests/clamav/test2.eml"
#   assert_failure
#   assert_output --partial "Sanesecurity.TestSig_Type4_Hdr.2.UNOFFICIAL FOUND"
# }

# @test "checking clamav-unofficial-sigs: TEST 3 — Email.Sanesecurity.TestSig_Type4_Bdy" {
#   run docker exec mailserver_default /bin/sh -c "clamscan --database=/var/lib/clamav/phish.ndb - < /tmp/tests/clamav/test3.eml"
#   assert_failure
#   assert_output --partial "Sanesecurity.TestSig_Type4_Bdy.3.UNOFFICIAL FOUND"
# }

#
# zeyple
#

@test "checking zeyple: zeyple.log doesn't exist (default configuration)" {
  run docker exec mailserver_default [ -f /var/log/zeyple.log ]
  assert_failure
}

@test "checking zeyple: pubring.kbx doesn't exist (default configuration)" {
  run docker exec mailserver_default [ -f /var/mail/zeyple/keys/pubring.kbx ]
  assert_failure
}

@test "checking zeyple: trustdb.gpg doesn't exist (default configuration)" {
  run docker exec mailserver_default [ -f /var/mail/zeyple/keys/trustdb.gpg ]
  assert_failure
}

@test "checking zeyple: content_filter value (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "postconf -h content_filter"
  assert_success
  assert_output ""
}

@test "checking zeyple: user zeyple doesn't exist (default configuration)" {
  run docker exec mailserver_default /bin/sh -c "id -u zeyple"
  assert_failure
}

#
# unbound
#

@test "checking unbound: /etc/resolv.conf (default configuration)" {
  run docker exec mailserver_default cat /etc/resolv.conf
  assert_success
  assert_output "nameserver 127.0.0.1"
}

@test "checking unbound: /var/mail/postfix/spool/etc/resolv.conf (default configuration)" {
  run docker exec mailserver_default cat /var/mail/postfix/spool/etc/resolv.conf
  assert_success
  assert_output "nameserver 127.0.0.1"
}

@test "checking unbound: root.hints exist (default configuration)" {
  run docker exec mailserver_default [ -f /etc/unbound/root.hints ]
  assert_success
}

@test "checking unbound: root.key exist (default configuration)" {
  run docker exec mailserver_default [ -f /etc/unbound/root.key ]
  assert_success
}

@test "checking unbound: unbound_control.key exist" {
  run docker exec mailserver_default [ -f /etc/unbound/unbound_control.key ]
  assert_success
}

@test "checking unbound: unbound_control.pem exist" {
  run docker exec mailserver_default [ -f /etc/unbound/unbound_control.pem ]
  assert_success
}

@test "checking unbound: unbound_server.key exist" {
  run docker exec mailserver_default [ -f /etc/unbound/unbound_server.key ]
  assert_success
}

@test "checking unbound: unbound_server.pem exist" {
  run docker exec mailserver_default [ -f /etc/unbound/unbound_server.pem ]
  assert_success
}

@test "checking unbound: server is running and unbound-control works" {
  run docker exec mailserver_default /bin/sh -c "unbound-control status"
  assert_success
  assert_output --partial 'is running'
}

@test "checking unbound: get stats" {
  run docker exec mailserver_default /bin/sh -c "unbound-control stats_noreset"
  assert_success
}

@test "checking unbound: testing DNSSEC validation" {
  run docker exec mailserver_default /bin/sh -c "dig com. SOA +nocmd +noall +dnssec +comments | grep 'flags: qr rd ra ad' | wc -l"
  assert_success
  assert_output 1
}

@test "checking unbound: debug mode disabled" {
  run docker exec mailserver_default /bin/sh -c "unbound-control status | grep 'verbosity: 0'"
  assert_success
}

#
# ssl
#

@test "checking ssl: generated default cert works correctly" {
  run docker exec mailserver_default /bin/sh -c "timeout 1 openssl s_client -ign_eof -connect 0.0.0.0:587 -starttls smtp | grep 'Verify return code: 18 (self-signed certificate)'"
  assert_success
}

@test "checking ssl: default configuration is correct" {
  run docker exec mailserver_default /bin/sh -c "grep '/ssl' /etc/postfix/main.cf | wc -l"
  assert_success
  assert_output 4
  run docker exec mailserver_default /bin/sh -c "grep '/ssl' /etc/dovecot/conf.d/10-ssl.conf | wc -l"
  assert_success
  assert_output 2
}

#
# index files
#

@test "checking hash tables: existing header_checks and virtual index files" {
  run docker exec mailserver_default [ -f /etc/postfix/header_checks.db ]
  assert_success
  run docker exec mailserver_default [ -f /etc/postfix/virtual.db ]
  assert_success
}

#
# logs
#

@test "checking logs: /var/log/mail.log in mailserver_default is error free" {
  run docker exec mailserver_default grep -i ': error:' /var/log/mail.log
  assert_failure
  run docker exec mailserver_default grep -i 'is not writable' /var/log/mail.log
  assert_failure
  run docker exec mailserver_default grep -i 'permission denied' /var/log/mail.log
  assert_failure
  run docker exec mailserver_default grep -i 'address already in use' /var/log/mail.log
  assert_failure
}

@test "checking logs: /var/log/mail.err in mailserver_default does not exist" {
  run docker exec mailserver_default cat /var/log/mail.err
  assert_failure
  assert_output --partial 'No such file or directory'
}
