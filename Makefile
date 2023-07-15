NAME = mailserver2/mailserver:testing

all: build-no-cache default reverse ldap ldap2 sieve ecdsa traefik_acmev1 traefik_acmev2 clean
no-build: default reverse ldap ldap2 sieve ecdsa traefik_acmev1 traefik_acmev2 clean
default: init_default fixtures_default run_default stop_default
reverse: init_reverse fixtures_reverse run_reverse stop_reverse
ldap: init_ldap fixtures_ldap run_ldap stop_ldap
ldap2: init_ldap2 fixtures_ldap2 run_ldap2 stop_ldap2
sieve: init_sieve fixtures_sieve run_sieve stop_sieve
ecdsa: init_ecdsa run_ecdsa stop_ecdsa
traefik_acmev1: init_traefik_acmev1 run_traefik_acmev1 stop_traefik_acmev1
traefik_acmev2: init_traefik_acmev2 run_traefik_acmev2 stop_traefik_acmev2

build-no-cache:
	docker build --no-cache -t $(NAME) .

build:
	docker build -t $(NAME) .

init_openldap:
	-docker rm -f \
		openldap || true
	docker run \
		-d \
		--name openldap \
		-e LDAP_ORGANISATION="Test LDAP" \
		-e LDAP_DOMAIN="domain.tld" \
		-e LDAP_ADMIN_PASSWORD="testpasswd" \
		-e LDAP_TLS=false \
		-v "`pwd`/test/config/ldap/struct.ldif":/container/service/slapd/assets/config/bootstrap/ldif/custom/struct.ldif \
		-t osixia/openldap:1.4.0 --copy-service

init_redis:
	-docker rm -f \
		redis || true
	docker run \
		-d \
		--name redis \
		-t redis:7.0-alpine
	sleep 10

init_mariadb:
	-docker rm -f \
		mariadb || true
	docker run \
		-d \
		--name mariadb \
		-e MYSQL_RANDOM_ROOT_PASSWORD=yes \
		-e MYSQL_DATABASE=postfix \
		-e MYSQL_USER=postfix \
		-e MYSQL_PASSWORD=testpasswd \
		-v "`pwd`/test/config/mariadb/struct.sql":/docker-entrypoint-initdb.d/struct.sql \
		-v "`pwd`/test/config/mariadb/bind.cnf":/etc/mysql/conf.d/bind.cnf \
		-t mysql:8

init_postgres:
	-docker rm -f \
		postgres || true
	docker run \
		-d \
		--name postgres \
		-e POSTGRES_DB=postfix \
		-e POSTGRES_USER=postfix \
		-e POSTGRES_PASSWORD=testpasswd \
		-v "`pwd`/test/config/postgres":/docker-entrypoint-initdb.d \
		-t postgres:14-alpine

init_ldap: init_openldap init_redis
	-docker rm -f \
		mailserver_ldap || true
	docker run \
		-d \
		--name mailserver_ldap \
		--link openldap \
		--link redis:redis \
		-e DBDRIVER=ldap \
		-e DBHOST=openldap \
		-e DBPORT=389 \
		-e LDAP_BIND_DN="cn=admin,dc=domain,dc=tld" \
		-e LDAP_BIND_PW="testpasswd" \
		-e LDAP_DEFAULT_SEARCH_BASE="o=mx,dc=domain,dc=tld" \
		-e LDAP_DOMAIN_FILTER="(&(mail=*@%s)(objectClass=mailAccount))" \
		-e LDAP_DOMAIN_ATTRIBUTE="mail" \
		-e LDAP_DOMAIN_FORMAT="%d" \
		-e LDAP_MAILBOX_FILTER="(&(mail=%s)(objectClass=mailAccount))" \
		-e LDAP_MAILBOX_ATTRIBUTE="mail" \
		-e LDAP_MAILBOX_FORMAT="/var/mail/vhosts/%d/%s/mail/" \
		-e LDAP_ALIAS_FILTER="(&(mailalias=%s)(objectClass=mailAccount))" \
		-e LDAP_ALIAS_ATTRIBUTE="mail" \
		-e LDAP_FORWARD_FILTER="(&(mailalias=%s)(objectClass=mailAlias))" \
		-e LDAP_FORWARD_ATTRIBUTE="mail" \
		-e LDAP_GROUP_FILTER="(&(mail=%s)(objectClass=mailGroup))" \
		-e LDAP_GROUP_ATTRIBUTE="uid" \
		-e LDAP_GROUP_RESULT_ATTRIBUTE="mail" \
		-e LDAP_GROUP_RESULT_MEMBER="member" \
		-e LDAP_SENDER_FILTER="(&(|(mail=%s)(mailalias=%s))(objectClass=mailAccount))" \
		-e LDAP_SENDER_ATTRIBUTE="mail" \
		-e LDAP_DOVECOT_USER_ATTRS="=home=/var/mail/vhosts/%d/%n/,=mail=maildir:/var/mail/vhosts/%d/%n/mail/,mailuserquota=quota_rule=*:bytes=%\$$" \
		-e LDAP_DOVECOT_USER_FILTER="(&(mail=%u)(objectClass=mailAccount))" \
		-e LDAP_DOVECOT_PASS_ATTRS="mail=user,userPassword=password" \
		-e LDAP_DOVECOT_PASS_FILTER="(&(mail=%u)(objectClass=mailAccount))" \
		-e LDAP_DOVECOT_ITERATE_ATTRS="mail=user" \
		-e LDAP_DOVECOT_ITERATE_FILTER="(objectClass=mailAccount)" \
		-e DKIM_SELECTOR="mail20190101" \
		-e VMAILUID=`id -u` \
		-e VMAILGID=`id -g` \
		-e RSPAMD_PASSWORD=testpasswd \
		-e ADD_DOMAINS=domain2.tld,domain3.tld \
		-e RECIPIENT_DELIMITER=: \
		-e TESTING=true \
		-v "`pwd`/test/share/tests":/tmp/tests \
		-v "`pwd`/test/share/ssl/rsa":/var/mail/ssl \
		-v "`pwd`/test/share/postfix/custom.conf":/var/mail/postfix/custom.conf \
		-v "`pwd`/test/share/postfix/sender_access":/var/mail/postfix/sender_access \
		-v "`pwd`/test/share/dovecot/conf.d":/var/mail/dovecot/conf.d \
		-v "`pwd`/test/share/clamav-unofficial-sigs/user.conf":/var/mail/clamav-unofficial-sigs/user.conf \
		-h mail.domain.tld \
		-t $(NAME)

fixtures_ldap:
	# Wait for clamav unofficial sigs database update (ldap)
	docker exec mailserver_ldap /bin/sh -c "while [ -f /var/lib/clamav-unofficial-sigs/pid/clamav-unofficial-sigs.pid ] ; do sleep 1 ; done"
	# Wait for clamav load databases (ldap)
	docker exec mailserver_ldap /bin/sh -c "while ! echo PING | nc -z 0.0.0.0 3310 ; do sleep 1 ; done"
	# Wait for rspamd to start (ldap)
	docker exec mailserver_ldap /bin/sh -c "while ! echo PING | nc -z 0.0.0.0 11332 ; do sleep 1 ; done"

	docker exec mailserver_ldap /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-to-existing-user.txt"
	docker exec mailserver_ldap /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-to-existing-user-spam-learning.txt"
	docker exec mailserver_ldap /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-to-valid-user-subaddress.txt"
	docker exec mailserver_ldap /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-to-non-existing-user.txt"
	docker exec mailserver_ldap /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-to-existing-alias.txt"
	docker exec mailserver_ldap /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-to-existing-alias-forward.txt"
	docker exec mailserver_ldap /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-to-existing-alias-group.txt"
	docker exec mailserver_ldap /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-spam-to-existing-user.txt"
	docker exec mailserver_ldap /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-virus-to-existing-user.txt"
	docker exec mailserver_ldap /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:587 -starttls smtp < /tmp/tests/email-templates/internal-user-to-existing-user.txt"
	docker exec mailserver_ldap /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:587 -starttls smtp < /tmp/tests/email-templates/internal-rejected-user-to-existing-user.txt"
	sleep 2
	docker exec mailserver_ldap /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:993 < /tmp/tests/sieve/trigger-spam-ham-learning.txt"
run_ldap:
	./test/bats/bin/bats test/ldap.bats
stop_ldap:
	-docker rm -f \
		mailserver_ldap || true

init_ldap2: init_openldap init_redis
	-docker rm -f \
		mailserver_ldap2 || true
	docker run \
		-d \
		--name mailserver_ldap2 \
		--link openldap \
		--link redis:redis \
		-e DBDRIVER=ldap \
		-e DBHOST=openldap \
		-e DBPORT=389 \
		-e LDAP_BIND_DN="cn=admin,dc=domain,dc=tld" \
		-e LDAP_BIND_PW="testpasswd" \
		-e LDAP_DEFAULT_SEARCH_BASE="o=mx,dc=domain,dc=tld" \
		-e LDAP_DOMAIN_FILTER="(&(mail=*@%s)(objectClass=mailAccount))" \
		-e LDAP_DOMAIN_ATTRIBUTE="mail" \
		-e LDAP_DOMAIN_FORMAT="%d" \
		-e LDAP_MAILBOX_FILTER="(&(mail=%s)(objectClass=mailAccount))" \
		-e LDAP_MAILBOX_ATTRIBUTE="mail" \
		-e LDAP_MAILBOX_FORMAT="/var/mail/vhosts/%d/%s/mail/" \
		-e LDAP_ALIAS_FILTER="(&(mailalias=%s)(objectClass=mailAccount))" \
		-e LDAP_ALIAS_ATTRIBUTE="mail" \
		-e LDAP_SENDER_FILTER="(&(|(mail=%s)(mailalias=%s))(objectClass=mailAccount))" \
		-e LDAP_SENDER_ATTRIBUTE="mail" \
		-e LDAP_DOVECOT_USER_ATTRS="=home=/var/mail/vhosts/%d/%n/,=mail=maildir:/var/mail/vhosts/%d/%n/mail/,mailuserquota=quota_rule=*:bytes=%\$$" \
		-e LDAP_DOVECOT_USER_FILTER="(&(mail=%u)(objectClass=mailAccount))" \
		-e LDAP_DOVECOT_PASS_ATTRS="mail=user,userPassword=password" \
		-e LDAP_DOVECOT_PASS_FILTER="(&(mail=%u)(objectClass=mailAccount))" \
		-e LDAP_DOVECOT_ITERATE_ATTRS="mail=user" \
		-e LDAP_DOVECOT_ITERATE_FILTER="(objectClass=mailAccount)" \
		-e LDAP_MASTER_USER_ENABLED=true \
		-e LDAP_DOVECOT_MASTER_PASS_ATTRS="mail=user,userPassword=password" \
		-e LDAP_DOVECOT_MASTER_PASS_FILTER="(&(mail=%u)(st=%{login_user})(objectClass=mailAccount))" \
		-e DISABLE_CLAMAV=true \
		-e DISABLE_SIEVE=true \
		-e DISABLE_SIGNING=true \
		-e DISABLE_GREYLISTING=true \
		-e DISABLE_RATELIMITING=true \
		-e DISABLE_DNS_RESOLVER=true \
		-e VMAILUID=`id -u` \
		-e VMAILGID=`id -g` \
		-e RSPAMD_PASSWORD=testpasswd \
		-e ADD_DOMAINS=domain2.tld,domain3.tld \
		-e RECIPIENT_DELIMITER=: \
		-e TESTING=true \
		-v "`pwd`/test/share/tests":/tmp/tests \
		-v "`pwd`/test/share/ssl/rsa":/var/mail/ssl \
		-v "`pwd`/test/share/postfix/custom.conf":/var/mail/postfix/custom.conf \
		-v "`pwd`/test/share/postfix/sender_access":/var/mail/postfix/sender_access \
		-v "`pwd`/test/share/dovecot/conf.d":/var/mail/dovecot/conf.d \
		-v "`pwd`/test/share/clamav-unofficial-sigs/user.conf":/var/mail/clamav-unofficial-sigs/user.conf \
		-h mail.domain.tld \
		-t $(NAME)
fixtures_ldap2:
	docker exec mailserver_ldap2 /bin/sh -c "while ! echo PING | nc -z 0.0.0.0 25 ; do sleep 1 ; done"
	sleep 30
	docker exec mailserver_ldap2 /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-to-existing-user.txt"
	docker exec mailserver_ldap2 /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-to-valid-user-subaddress.txt"
	docker exec mailserver_ldap2 /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-to-non-existing-user.txt"
	docker exec mailserver_ldap2 /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-to-existing-alias.txt"
	docker exec mailserver_ldap2 /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-to-existing-alias-forward.txt"
	docker exec mailserver_ldap2 /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-to-existing-alias-group.txt"
	docker exec mailserver_ldap2 /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:587 -starttls smtp < /tmp/tests/email-templates/internal-user-to-existing-user.txt"
	sleep 10
run_ldap2:
	./test/bats/bin/bats test/ldap2.bats
stop_ldap2:
	-docker rm -f \
		mailserver_ldap2 || true

init_default: init_redis init_mariadb
	-docker rm -f \
		mailserver_default || true

	sleep 60

	docker run \
		-d \
		--name mailserver_default \
		--link mariadb:mariadb \
		--link redis:redis \
		-e DBPASS=testpasswd \
		-e RSPAMD_PASSWORD=testpasswd \
		-e VMAILUID=`id -u` \
		-e VMAILGID=`id -g` \
		-e ADD_DOMAINS=domain2.tld,domain3.tld \
		-e RECIPIENT_DELIMITER=: \
		-e TESTING=true \
		-v "`pwd`/test/share/tests":/tmp/tests \
		-v "`pwd`/test/share/ssl/rsa":/var/mail/ssl \
		-v "`pwd`/test/share/postfix/custom.conf":/var/mail/postfix/custom.conf \
		-v "`pwd`/test/share/postfix/sender_access":/var/mail/postfix/sender_access \
		-v "`pwd`/test/share/dovecot/conf.d":/var/mail/dovecot/conf.d \
		-v "`pwd`/test/share/clamav-unofficial-sigs/user.conf":/var/mail/clamav-unofficial-sigs/user.conf \
		-h mail.domain.tld \
		-t $(NAME)

init_reverse: init_redis init_postgres
	-docker rm -f \
		mailserver_reverse || true
	sleep 10
	docker run \
		-d \
		--name mailserver_reverse \
		--link postgres:postgres \
		--link redis:redis \
		-e FQDN=mail.domain.tld \
		-e DOMAIN=domain.tld \
		-e DBDRIVER=pgsql \
		-e DBHOST=postgres \
		-e DBPORT=5432 \
		-e DBPASS=/tmp/passwd/postgres \
		-e REDIS_HOST=redis \
		-e REDIS_PORT=6379 \
		-e REDIS_PASS=/tmp/passwd/redis \
		-e RSPAMD_PASSWORD=/tmp/passwd/rspamd \
		-e VMAILUID=`id -u` \
		-e VMAILGID=`id -g` \
		-e VMAIL_SUBDIR=subdir \
		-e RELAY_NETWORKS="192.168.0.0/16 172.16.0.0/12 10.0.0.0/8" \
		-e DISABLE_CLAMAV=true \
		-e DISABLE_SIEVE=true \
		-e DISABLE_SIGNING=true \
		-e DISABLE_GREYLISTING=true \
		-e DISABLE_RATELIMITING=true \
		-e DISABLE_DNS_RESOLVER=true \
		-e ENABLE_POP3=true \
		-e ENABLE_ENCRYPTION=true \
		-e ENABLE_FETCHMAIL=true \
		-e DKIM_KEY_LENGTH=4096 \
		-e DKIM_SELECTOR="other" \
		-e TESTING=true \
		-v "`pwd`/test/share/tests":/tmp/tests \
		-v "`pwd`/test/share/passwd":/tmp/passwd \
		-v "`pwd`/test/share/ssl/rsa":/var/mail/ssl \
		-v "`pwd`/test/share/sieve/custom.sieve":/var/mail/sieve/custom.sieve \
		-v "`pwd`/test/share/letsencrypt":/etc/letsencrypt \
		-t $(NAME)
fixtures_reverse:
	docker exec mailserver_reverse /bin/sh -c "while ! echo PING | nc -z 0.0.0.0 25 ; do sleep 1 ; done"
	sleep 30
	docker exec mailserver_reverse /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-to-existing-user.txt"
	docker exec mailserver_reverse /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-to-valid-user-subaddress-with-default-separator.txt"
	docker exec mailserver_reverse /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-to-non-existing-user.txt"
	docker exec mailserver_reverse /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-to-existing-alias.txt"
	docker exec mailserver_reverse /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-spam-to-existing-user.txt"
	docker exec mailserver_reverse /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:587 -starttls smtp < /tmp/tests/email-templates/internal-user-to-existing-user.txt"
	# Wait until all mails have been processed
	sleep 10
run_reverse:
	./test/bats/bin/bats test/reverse.bats
stop_reverse:
	-docker rm -f \
		mailserver_reverse || true

init_ecdsa: init_redis init_mariadb
	-docker rm -f \
		mailserver_ecdsa || true
	sleep 10
	docker run \
		-d \
		--name mailserver_ecdsa \
		--link mariadb:mariadb \
		--link redis:redis \
		-e DBPASS=testpasswd \
		-e RSPAMD_PASSWORD=testpasswd \
		-e VMAILUID=`id -u` \
		-e VMAILGID=`id -g` \
		-e DISABLE_CLAMAV=true \
		-e DISABLE_RSPAMD_MODULE=rbl,mx_check,url_redirector \
		-e WHITELIST_SPAM_ADDRESSES=test@example.com,another@domain.tld \
		-e TESTING=true \
		-v "`pwd`/test/share/ssl/ecdsa":/var/mail/ssl \
		-v "`pwd`/test/share/postfix/custom.ecdsa.conf":/var/mail/postfix/custom.conf \
		-h mail.domain.tld \
		-t $(NAME)
run_ecdsa:
	docker exec mailserver_ecdsa /bin/sh -c "while ! echo PING | nc -z 0.0.0.0 587 ; do sleep 1 ; done"
	./test/bats/bin/bats test/ecdsa.bats
stop_ecdsa:
	-docker rm -f \
		mailserver_ecdsa || true

init_traefik_acmev1: init_redis init_mariadb
	-docker rm -f \
		mailserver_traefik_acmev1 || true
	docker run \
		-d \
		--name mailserver_traefik_acmev1 \
		--link mariadb:mariadb \
		--link redis:redis \
		-e DEBUG_MODE=dovecot,postfix \
		-e DBPASS=testpasswd \
		-e RSPAMD_PASSWORD=testpasswd \
		-e VMAILUID=`id -u` \
		-e VMAILGID=`id -g` \
		-e DISABLE_CLAMAV=true \
		-e TESTING=true \
		-v "`pwd`/test/share/traefik/acme.v1.json":/etc/letsencrypt/acme/acme.json \
		-h mail.domain.tld \
		-t $(NAME)
run_traefik_acmev1:
	docker exec mailserver_traefik_acmev1 /bin/sh -c "while ! echo PING | nc -z 0.0.0.0 587 ; do sleep 1 ; done"
	./test/bats/bin/bats test/traefik_acmev1.bats
stop_traefik_acmev1:
	-docker rm -f \
		mailserver_traefik_acmev1 || true

init_traefik_acmev2: init_redis init_mariadb
	-docker rm -f \
		mailserver_traefik_acmev2 || true
	docker run \
		-d \
		--name mailserver_traefik_acmev2 \
		--link mariadb:mariadb \
		--link redis:redis \
		-e DEBUG_MODE=true \
		-e DBPASS=testpasswd \
		-e RSPAMD_PASSWORD=testpasswd \
		-e VMAILUID=`id -u` \
		-e VMAILGID=`id -g` \
		-e DISABLE_CLAMAV=true \
		-e TESTING=true \
		-v "`pwd`/test/share/traefik/acme.v2.json":/etc/letsencrypt/acme/acme.json \
		-h mail.domain.tld \
		-t $(NAME)
run_traefik_acmev2:
	docker exec mailserver_traefik_acmev2 /bin/sh -c "while ! echo PING | nc -z 0.0.0.0 587 ; do sleep 1 ; done"
	./test/bats/bin/bats test/traefik_acmev2.bats
stop_traefik_acmev2:
	-docker rm -f \
		mailserver_traefik_acmev2 || true

fixtures_default:

	# Wait for clamav unofficial sigs database update (default)
	docker exec mailserver_default /bin/sh -c "while [ -f /var/lib/clamav-unofficial-sigs/pid/clamav-unofficial-sigs.pid ] ; do sleep 1 ; done"
	# Wait for clamav load databases (default)
	docker exec mailserver_default /bin/sh -c "while ! echo PING | nc -z 0.0.0.0 3310 ; do sleep 1 ; done"
	# Wait for rspamd to start (default)
	docker exec mailserver_default /bin/sh -c "while ! echo PING | nc -z 0.0.0.0 11332 ; do sleep 1 ; done"

	docker exec mailserver_default /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-to-existing-user.txt"
	docker exec mailserver_default /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-to-existing-user-spam-learning.txt"
	docker exec mailserver_default /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-to-valid-user-subaddress.txt"
	docker exec mailserver_default /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-to-non-existing-user.txt"
	docker exec mailserver_default /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-to-existing-alias.txt"
	docker exec mailserver_default /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-spam-to-existing-user.txt"
	docker exec mailserver_default /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-virus-to-existing-user.txt"
	docker exec mailserver_default /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:587 -starttls smtp < /tmp/tests/email-templates/internal-user-to-existing-user.txt"
	docker exec mailserver_default /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:587 -starttls smtp < /tmp/tests/email-templates/internal-rejected-user-to-existing-user.txt"
	sleep 2
	docker exec mailserver_default /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:993 < /tmp/tests/sieve/trigger-spam-ham-learning.txt"
	# Wait until all mails have been processed
	sleep 10
run_default:
	./test/bats/bin/bats test/default.bats
stop_default:
	-docker rm -f \
		mailserver_default || true

init_sieve: init_redis init_mariadb
	-docker rm -f \
		mailserver_sieve || true
	docker run \
		-d \
		--name mailserver_sieve \
		--link mariadb:mariadb \
		--link redis:redis \
		-e DBHOST=mariadb \
		-e DBPASS=testpasswd \
		-e RSPAMD_PASSWORD=testpasswd \
		-e VMAILUID=`id -u` \
		-e VMAILGID=`id -g` \
		-e ADD_DOMAINS=domain2.tld,domain3.tld \
		-e RECIPIENT_DELIMITER=: \
		-e TESTING=true \
		-e DEBUG_MODE=true \
		-v "`pwd`/test/share/tests":/tmp/tests \
		-v "`pwd`/test/share/ssl/rsa":/var/mail/ssl \
		-v "`pwd`/test/share/postfix/custom.conf":/var/mail/postfix/custom.conf \
		-v "`pwd`/test/share/postfix/sender_access":/var/mail/postfix/sender_access \
		-v "`pwd`/test/share/dovecot/conf.d":/var/mail/dovecot/conf.d \
		-v "`pwd`/test/share/clamav-unofficial-sigs/user.conf":/var/mail/clamav-unofficial-sigs/user.conf \
		-h mail.domain.tld \
		-t $(NAME)

fixtures_sieve:
	# Wait for clamav unofficial sigs database update (sieve)
	docker exec mailserver_sieve /bin/sh -c "while [ -f /var/lib/clamav-unofficial-sigs/pid/clamav-unofficial-sigs.pid ] ; do sleep 1 ; done"
	# Wait for clamav load databases (sieve)
	docker exec mailserver_sieve /bin/sh -c "while ! echo PING | nc -z 0.0.0.0 3310 ; do sleep 1 ; done"
	# Wait for rspamd to start (sieve)
	docker exec mailserver_sieve /bin/sh -c "while ! echo PING | nc -z 0.0.0.0 11332 ; do sleep 1 ; done"

	docker exec mailserver_sieve /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-to-existing-user.txt"
	docker exec mailserver_sieve /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-to-existing-user-spam-learning.txt"
	docker exec mailserver_sieve /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-to-valid-user-subaddress.txt"
	docker exec mailserver_sieve /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-to-non-existing-user.txt"
	docker exec mailserver_sieve /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-to-existing-alias.txt"
	docker exec mailserver_sieve /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-spam-to-existing-user.txt"
	docker exec mailserver_sieve /bin/sh -c "nc 0.0.0.0 25 < /tmp/tests/email-templates/external-virus-to-existing-user.txt"
	docker exec mailserver_sieve /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:587 -starttls smtp < /tmp/tests/email-templates/internal-user-to-existing-user.txt"
	docker exec mailserver_sieve /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:587 -starttls smtp < /tmp/tests/email-templates/internal-rejected-user-to-existing-user.txt"

	sleep 2
	docker exec mailserver_sieve /bin/sh -c "openssl s_client -ign_eof -connect 0.0.0.0:993 < /tmp/tests/sieve/trigger-spam-ham-learning.txt"

	# Wait until all mails have been processed
	sleep 10

run_sieve:
	./test/bats/bin/bats test/sieve.bats

stop_sieve:
	-docker rm -f \
		mailserver_sieve || true

clean:
	docker images --quiet --filter=dangling=true | xargs --no-run-if-empty docker rmi
	docker volume ls -qf dangling=true | xargs -r docker volume rm
