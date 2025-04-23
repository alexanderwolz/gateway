ARG NGINX_VERSION="1.27.5"


# Stage 1 - build nginx modules
FROM nginx:${NGINX_VERSION}-alpine AS build
LABEL maintainer="mail@alexanderwolz.de"

ARG NGINX_VERSION
ARG GEOIP2_VERSION="3.4"

# download build tools and dependenciess
RUN apk update && apk add --no-cache gcc libc-dev make perl openssl-dev \
    pcre-dev pcre2-dev zlib-dev libmaxminddb-dev

WORKDIR /build

# download nginx sources
RUN wget -O nginx.tar.gz http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz \
    && mkdir nginx && tar zxvf nginx.tar.gz -C nginx --strip-components 1 \
    && rm nginx.tar.gz

# download geoip2 module
RUN wget -O ngx_http_geoip2_module.tar.gz https://github.com/leev/ngx_http_geoip2_module/archive/refs/tags/${GEOIP2_VERSION}.tar.gz \
    && mkdir ngx_http_geoip2_module && tar zxvf ngx_http_geoip2_module.tar.gz -C ngx_http_geoip2_module --strip-components 1 \
    && rm ngx_http_geoip2_module.tar.gz

# compile nginx modules
WORKDIR /build/nginx
RUN CONFARGS=$(nginx -V 2>&1 | sed -n -e 's/^.*arguments: //p') \
    ./configure \
    --with-compat $CONFARGS \
    --add-dynamic-module=../ngx_http_geoip2_module \
    --with-stream \
    && make && make install


# Stage 2 - run container
FROM nginx:${NGINX_VERSION}-alpine AS run
LABEL maintainer="mail@alexanderwolz.de"

ENV NGINX_VERSION=${NGINX_VERSION}

RUN apk update && apk add --no-cache bash nano libmaxminddb openssl \
    && rm /etc/nginx/conf.d/default.conf \
    && mkdir /var/run/nginx \
    && mkdir /etc/nginx/ssl \
    && mkdir /etc/nginx/conf.d/http \
    && mkdir /etc/nginx/conf.d/stream \
    && mkdir -p /var/www/certbot

COPY --from=build /build/nginx/objs/ngx_http_geoip2_module.so /usr/lib/nginx/modules/ngx_http_geoip2_module.so
COPY --from=build /build/nginx/objs/ngx_stream_geoip2_module.so /usr/lib/nginx/modules/ngx_stream_geoip2_module.so

COPY geoip/sample.mmdb /etc/geoip_sample/sample.mmdb
COPY geoip/sample.mmdb /etc/geoip/GeoLite2-Country.mmdb
COPY geoip/sample.mmdb /etc/geoip/GeoLite2-City.mmdb

COPY empty.sh /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
ADD conf/includes /etc/nginx/includes
COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/default.conf /etc/nginx/defaults/default.conf
COPY conf/localhost.conf /etc/nginx/defaults/localhost.conf
COPY entrypoint.sh /docker-entrypoint.d/00-custom-entrypoint.sh
RUN chmod +x /docker-entrypoint.d/00-custom-entrypoint.sh

WORKDIR /var/www/html
