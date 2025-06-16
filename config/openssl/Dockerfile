FROM alpine

# default variables
ENV COUNTRY "DE"
ENV STATE "Baden Württemberg"
ENV LOCATION "Stuttgart"
ENV ORGANISATION "TOLERANT Software GmbH & Co. KG"
ENV ORGANISATION_UNIT "TOLERANT Post"
ENV DOMAIN "*.tolerant.intern"
ENV RSA_KEY_NUMBITS "2048"
ENV DAYS "365"
ENV FILE_NAME "ssl"
ENV CERT_DIR "/etc/ssl/certs"
ENV KEY_DIR "/etc/ssl/private"

# install openssl
RUN apk add --update openssl && \
    rm -rf /var/cache/apk/*

COPY --chmod=654 docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]
