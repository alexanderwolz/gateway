ARG NGINX_VERSION="1.27.4"

# Stage 1 - build modules
FROM nginx:${NGINX_VERSION}-alpine AS build
LABEL maintainer="mail@alexanderwolz.de"

ARG NGINX_VERSION

# download build tools and dependenciess
RUN apk update && apk add --no-cache gcc libc-dev make perl openssl-dev pcre-dev pcre2-dev zlib-dev libmaxminddb-dev

WORKDIR /build

# download nginx sources
RUN wget -O nginx.tar.gz http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz \
    && mkdir nginx && tar zxvf nginx.tar.gz -C nginx --strip-components 1 \
    && rm nginx.tar.gz

# download geoip2 module
RUN wget -O ngx_http_geoip2_module.tar.gz https://github.com/leev/ngx_http_geoip2_module/archive/refs/tags/3.4.tar.gz \
    && mkdir ngx_http_geoip2_module && tar zxvf ngx_http_geoip2_module.tar.gz -C ngx_http_geoip2_module --strip-components 1 \
    && rm ngx_http_geoip2_module.tar.gz

# download jwt auth module
# RUN apk add --no-cache jansson-dev libjwt-dev
# RUN wget -O ngx_http_auth_jwt_module.tar.gz https://github.com/TeslaGov/ngx-http-auth-jwt-module/archive/refs/tags/2.1.0.tar.gz \
#     && mkdir ngx_http_auth_jwt_module && tar zxvf ngx_http_auth_jwt_module.tar.gz -C ngx_http_auth_jwt_module --strip-components 1 \
#     && rm ngx_http_auth_jwt_module.tar.gz

# compile nginx modules
WORKDIR /build/nginx
RUN CONFARGS=$(nginx -V 2>&1 | sed -n -e 's/^.*arguments: //p') \
    ./configure \
    --with-compat $CONFARGS \
    --add-dynamic-module=../ngx_http_geoip2_module \
    --with-stream \
    #--add-dynamic-module=../ngx_http_auth_jwt_module \
    #--with-cc-opt='-DNGX_LINKED_LIST_COOKIES=1' \
    && make && make install




# Stage 2 - run container
FROM nginx:${NGINX_VERSION}-alpine AS run
LABEL maintainer="mail@alexanderwolz.de"

RUN apk update && apk add --no-cache bash nano libmaxminddb openssl \
    && mkdir /var/run/nginx \
    && mkdir /etc/nginx/ssl \
    && mkdir /etc/nginx/conf.d/http \
    && mkdir /etc/nginx/conf.d/stream \
    && mkdir -p /var/www/certbot

COPY --from=build /build/nginx/objs/ngx_http_geoip2_module.so /usr/lib/nginx/modules/ngx_http_geoip2_module.so
COPY --from=build /build/nginx/objs/ngx_stream_geoip2_module.so /usr/lib/nginx/modules/ngx_stream_geoip2_module.so
#COPY --from=build /build/nginx/objs/ngx_http_auth_jwt_module.so /usr/lib/nginx/modules/ngx_http_auth_jwt_module.so
# use "load_module  modules/ngx_http_auth_jwt_module.so;" in nginx.conf

#COPY empty.sh /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
ADD conf/includes /etc/nginx/includes
COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/default.conf /etc/nginx/conf.d/default.conf
COPY conf/localhost.conf /etc/nginx/conf.d/localhost.conf
COPY entrypoint.sh /docker-entrypoint.d/00-custom-entrypoint.sh
RUN chmod +x /docker-entrypoint.d/00-custom-entrypoint.sh

COPY geoip /etc/geoip_sample

WORKDIR /var/www/html

#INFO: must run as root (binds to system ports 443/80)
#USER nginx
