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
GEOIP_SAMPLE="/etc/geoip_sample/sample.mmdb"

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

if [ -z "$( ls -A $GEOIP_DIR )" ]; then
    log "geoip does not exist, using dummy sample file for now.."
    ln -sf $GEOIP_SAMPLE $GEOIP_DIR/GeoLite2-Country.mmdb
    ln -sf $GEOIP_SAMPLE $GEOIP_DIR/GeoLite2-City.mmdb
    log "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    log "!!! Please mount valid MaxMind DB files to $GEOIP_DIR !!!"
    log "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
fi


log "Finished custom entrypoint"
