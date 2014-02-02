update-openssl-certificates
===========================

http://blog.hostname.sk/2014/02/01/aktualizacia-ssl-certifikatov/

If you are using SSl certificates from https://www.cacert.org , you must renew your certificates every 6 months. This script simplifies this taks.

Update process with this script is done this way:

- save update-cacert-certificate.sh to your disk, where you keep your SSL certificates (/etc/nginx/ssl/ or so)
- log in to your CAcert account https://secure.cacert.org/account.php
- go to Server Certificates --> View ad click 'renew'
- run cd /etc/nginx/ssl/ && ./update-cacert-certificate.sh
- copy&paste output from CAcert to standard input
- DONE - your key is saved as /etc/nginx/ssl/example.com-cacert-B00B5/example.com.pem and symlink is created


