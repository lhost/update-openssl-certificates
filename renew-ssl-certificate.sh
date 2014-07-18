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

AWK="gawk"

if [ ! -x "`which $AWK`" ]; then
	echo "gawk not found, please install gawk"
	exit 1
fi

if [ ! -f "$OLD_SSL_CERTIFICATE" ]; then
	echo "OLD SSL certificate '$OLD_SSL_CERTIFICATE' not found"
	exit 1
fi

# check if we are able to extract $subject from $OLD_SSL_CERTIFICATE and extract them
openssl x509 -in "$OLD_SSL_CERTIFICATE" -noout -subject > /dev/null || exit 2
FQDN=`openssl x509 -in "$OLD_SSL_CERTIFICATE" -noout -subject | $AWK -v FS='=' '{ print $NF; }'`

FQDN=`whiptail \
	--backtitle "Configure an SSL Certificate." \
	--title "Configure an SSL Certificate." \
	--inputbox "Please enter the host name to use in the SSL certificate.  It will become the 'commonName' field of the generated SSL certificate.  Host name:" 12 76 "$FQDN" \
3>&1 1>&2 2>&3 `

TMPFILE="$(mktemp)" || exit 1
TMPOUT="$(mktemp)"  || exit 1

trap "rm -f $TMPFILE $TMPOUT" EXIT

echo TMPFILE=$TMPFILE
echo TMPOUT=$TMPOUT

# prepare openssl.cnf config {{{
cat >> $TMPFILE <<EOF
FQDN = $FQDN
EOF

$AWK '/req_extensions/ { print "req_extensions = v3_req\n"; next; }
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
# }}}

eval `$AWK -F'[= \t]+' '! /^\s*#/ && /^\s*[a-zA-Z_]+_default\s*=\s*/ { printf "%s=\"%s\"\n", $1, $2; }' $TMPFILE`

subject="/C=$countryName_default/ST=$stateOrProvinceName_default/L=$localityName_default/O=$organizationName_default/OU=$organizationalUnitName_default/CN=$FQDN" 

echo subject=$subject
if ! openssl req -new -x509 -days 3650 -nodes -sha256 \
	-config $TMPFILE -subj $subject \
	-out ${NEW_SSL_CERTIFICATE}.pem \
	-keyout ${NEW_SSL_CERTIFICATE}.key > $TMPOUT 2>&1
	then
		echo Could not create certificate. Openssl output was: >&2
		cat $TMPOUT >&2
		exit 3
fi

if [ ! -f "${NEW_SSL_CERTIFICATE}.pem" ]; then
	echo "ERROR: SSL certificate was not generated"
	exit 4
fi

# debug:
#openssl x509  -text -noout -in ${NEW_SSL_CERTIFICATE}.pem | less -S 


openssl x509 -in "${NEW_SSL_CERTIFICATE}.pem" -noout -serial > /dev/null || exit 5
serial=`openssl x509 -in "${NEW_SSL_CERTIFICATE}.pem" -noout -serial | $AWK -v FS='=' '{ print $NF; }'`

#
# create directory with serial number and move all stuff there
#
dir="$FQDN-$serial"
mkdir $dir || exit 6
mv $TMPFILE $dir/openssl.cnf
mv ${NEW_SSL_CERTIFICATE}.pem $dir/${FQDN}.pem
mv ${NEW_SSL_CERTIFICATE}.key $dir/${FQDN}.key

#
# Generate CSR
#
cd $dir
openssl req -config ./openssl.cnf -new -subj $subject -key ${FQDN}.key -out ${FQDN}.csr || exit 7
echo "Here is your key: $dir/"
ls -la .
echo "#" ; echo "# Submit this request to your CA" ; echo "#"; echo
cat ${FQDN}.csr

# vim: fdm=marker fdl=0 fdc=3

