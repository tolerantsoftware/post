#!/bin/sh
# docker entrypoint script

SUBJ="/C=$COUNTRY/ST=$STATE/L=$LOCATION/O=$ORGANISATION/OU=$ORGANISATION_UNIT/CN=$DOMAIN"

if [ ! -f "$CERT_DIR/$FILE_NAME.crt" ]; then
  echo "Generating self singed certificate..."
  openssl req \
     -x509 \
     -nodes \
     -days $DAYS \
     -newkey rsa:$RSA_KEY_NUMBITS \
     -keyout $KEY_DIR/$FILE_NAME.key \
     -out $CERT_DIR/$FILE_NAME.crt \
     -subj "$SUBJ"
else
  echo "$CERT_DIR/$FILE_NAME.crt already exits"
fi
