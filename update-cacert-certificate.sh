#!/bin/sh

#
# update-cacert-certificate.sh
#
# Developed by Lubomir Host <lubomir.host@gmail.com>
# Licensed under terms of GNU General Public License.
# All rights reserved.
#
# Changelog:
# 2013-08-19 - created
#

for cakey in class3.crt root.crt; do
	echo "Checking 'cacert.org-$cakey'"
	if [ ! -f "cacert.org-$cakey" ] || [ ! -s "cacert.org-$cakey" ]; then
		echo "\t'cacert.org-$cakey' is missing, downloading"
		wget -O "cacert.org-$cakey" "https://www.cacert.org/certs/$cakey" && \
			openssl x509 -in "cacert.org-$cakey" -fingerprint -text -out -  | head -n 9

	fi
done

echo "Go to https://www.cacert.org/account.php?id=12 (MyAccount --> Server Certificates --> View) and click 'Renew' for your certificates"
echo "Then wait for the output from web and copy&paste output here:"

TEMP=`mktemp`
#@echo tmp=$TEMP
trap "rm -f '$TEMP'" 1 2 3 15

cat > $TEMP

echo -----------------------------
echo "Your NEW certificate is"
openssl x509 -in "$TEMP" -noout -subject -serial -fingerprint || exit 3
echo -----------------------------

fingerprint=`openssl x509 -in "$TEMP" -noout -fingerprint | awk -v FS='=' '{ print $2 }'`
serial=`openssl x509 -in "$TEMP" -noout -serial | awk -v FS='=' '{ print $2 }'`
subject=`openssl x509 -in "$TEMP" -noout -subject | awk -v FS='=' '{ sub("*.", "", $3); print $3; }'`

pem_file="$subject.pem"
key_file="$subject.key"

if [ ! -f "$pem_file" ] || [ ! -f "$key_file" ]; then
	echo "Files '$pem_file' and '$key_file' doesn't exists ==> nothing to update";
	exit 2
fi

echo -----------------------------
echo "Your PREVIUS certificate is:"
openssl x509 -in "$pem_file" -noout -subject -serial -fingerprint || exit 4
echo -----------------------------

echo -n "Update this certificate? [y/N] "
read answer

case $answer in
	[yY])
		echo "OK, updating key for '$subject'"
		;;
	*)
		echo "Nothing to do, exiting..."
		exit 5;
esac

outdir="$subject-cacert-$serial"
mkdir "$outdir" || exit 6
openssl x509 -in "$TEMP" -out "$outdir/$subject.pem" || exit 7
#cat cacert.org-root.crt cacert.org-class3.crt >> "$outdir/$subject.pem" || exit 8
cat cacert.org-root.crt >> "$outdir/$subject.pem" || exit 8

# keep and duplicate keyfile
cp -p  `readlink "$subject.key"` "$outdir/$subject.key" || exit 11

for certfile in "$subject.pem" "$subject.key"; do
	if [ -L "$certfile" ]; then
		echo "Creating symlink to '$outdir/$certfile'"
		ln -s -f "$outdir/$certfile" || exit 10
	fi
done

rm -f "$TEMP"

