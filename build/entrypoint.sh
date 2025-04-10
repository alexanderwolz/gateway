#!/bin/bash
# Copyright (C) 2025 Alexander Wolz <mail@alexanderwolz.de>

ME=$(basename "$0")

function log(){
    echo "$ME: $1"
}

log "Started custom entrypoint.."

FAKE_CERT="/etc/nginx/ssl/nginx.crt"
FAKE_KEY="/etc/nginx/ssl/nginx.key"
DH_PARAM="/etc/nginx/ssl/dhparam.pem"
GEOIP_DIR="/etc/geoip"
GEOIP_COUNTRY_FILE="$GEOIP_DIR/GeoLite2-Country.mmdb"
GEOIP_CITY_FILE="$GEOIP_DIR/GeoLite2-City.mmdb"
GEOIP_SAMPLE="/etc/geoip_sample/sample.mmdb"

COUNTRY_MATCH=1
CITY_MATCH=1
if [ -f $GEOIP_COUNTRY_FILE ]; then
    cmp -s $GEOIP_SAMPLE $GEOIP_COUNTRY_FILE
    COUNTRY_MATCH=$?
fi
if [ -f $GEOIP_CITY_FILE ]; then
    cmp -s $GEOIP_SAMPLE $GEOIP_CITY_FILE
    CITY_MATCH=$?
fi
if [ "$COUNTRY_MATCH" -eq 0 ] && [ "$CITY_MATCH" -eq 0 ]; then
    log "Using sample geoip database for now, please mount valid MaxMind DB files to $GEOIP_DIR"
fi

if [ ! -f $FAKE_KEY ] || [ ! -f $FAKE_CERT ]; then
    log "Fake certificate do not exist, creating .."
    rm -rf $FAKE_CERT $FAKE_KEY
    openssl req -newkey rsa:2048 -new -nodes -x509 -days 3650 -subj "/C=DE/CN=gateway" -keyout $FAKE_KEY -out $FAKE_CERT 2>/dev/null \
        || (log "Error while creating fake certificate" && exit 1)
    log "Fake certificate successfully created ($FAKE_CERT, $FAKE_KEY)"
fi

if [ ! -f $DH_PARAM ]; then
    log "DH param does not exist, creating .."
    openssl dhparam -dsaparam -out $DH_PARAM 4096 2>/dev/null \
        || (log "Error while creating DH param" && exit 1)
    log "DH param successfully created ($DH_PARAM)"
fi

log "Finished custom entrypoint"
