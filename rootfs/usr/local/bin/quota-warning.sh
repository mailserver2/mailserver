#!/bin/bash

PERCENT=$1
USER=$2

# The mailbox is at or over its limit by definition, so quota is not enforced
# for this delivery.
cat << EOF | /usr/lib/dovecot/dovecot-lda -d $USER -o "quota_enforce=no"
From: postmaster@{{ .DOMAIN }}
Subject: Mailbox quota warning

Your mailbox is now $PERCENT% full.
EOF
