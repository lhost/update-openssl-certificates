#!/bin/bash

#
# renew-ssl-certificate.sh
#
# Developed by Lubomir Host <lubomir.host@gmail.com>
# Licensed under terms of GNU General Public License.
# All rights reserved.
#
# Changelog:
# 2014-06-16 - created
#

OLD_SSL_CERTIFICATE="$1"
NEW_SSL_CERTIFICATE="${OLD_SSL_CERTIFICATE%.pem}-$RANDOM"

if [ ! -f "$OLD_SSL_CERTIFICATE" ]; then
	echo "OLD SSL certificate '$OLD_SSL_CERTIFICATE' not found"
	exit 1
fi

openssl x509 -in "$OLD_SSL_CERTIFICATE" -noout -subject > /dev/null || exit 2
FQDN=`openssl x509 -in "$OLD_SSL_CERTIFICATE" -noout -subject | awk -v FS='=' '{ print $NF; }'`

FQDN=`whiptail \
	--backtitle "Configure an SSL Certificate." \
	--title "Configure an SSL Certificate." \
	--inputbox "Please enter the host name to use in the SSL certificate.  It will become the 'commonName' field of the generated SSL certificate.  Host name:" 12 76 "$FQDN" \
3>&1 1>&2 2>&3 `

TMPFILE="$(mktemp)" || exit 1
TMPOUT="$(mktemp)"  || exit 1

#trap "rm -f $TMPFILE $TMPOUT" EXIT

cat >> $TMPFILE <<EOF
FQDN = $FQDN
EOF

awk '/req_extensions/ { print "req_extensions = v3_req\n"; next; }
	/_min\s*=/ { next; }
	/_max\s*=/ { next; }
	{ print; } ' \
	/etc/ssl/openssl.cnf >> $TMPFILE
	#/^\[\s*req\s*\]$/ { print ; print "prompt = no\n"; next; }

cat >> $TMPFILE <<EOF

[ req_distinguished_name ]
#O = \$ORGNAME
CN = \$FQDN

[ v3_req ]
subjectAltName = @alt_names

[alt_names]
DNS.1	= *.$FQDN
DNS.2	= $FQDN
EOF

ls -la $TMPFILE $TMPOUT

if ! openssl req -config $TMPFILE -new -x509 -days 3650 -nodes -sha256 \
	-out ${NEW_SSL_CERTIFICATE}.pem \
	-keyout ${NEW_SSL_CERTIFICATE}.key > $TMPOUT 2>&1
	then
		echo Could not create certificate. Openssl output was: >&2
		cat $TMPOUT >&2
		exit 1
fi

openssl req -config $TMPFILE -new -key ${NEW_SSL_CERTIFICATE}.key -out ${NEW_SSL_CERTIFICATE}.csr

# make-ssl-cert /usr/share/ssl-cert/ssleay.cnf /dev/null

