ARG DEBIAN_VERSION="13.3"
ARG OPENRESTY_VERSION="1.31.1.1"
ARG GEOIP2_VERSION="3.4"


# Stage 1 - build OpenResty and additional modules
FROM debian:${DEBIAN_VERSION}-slim AS build
LABEL maintainer="mail@alexanderwolz.de"

ARG OPENRESTY_VERSION
ARG GEOIP2_VERSION

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    wget \
    build-essential \
    perl \
    libmaxminddb-dev \
    libpcre2-dev \
    zlib1g-dev \
    libssl-dev \
    make \
    luarocks \
    lua-sec \
    lua-socket \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Fetch OpenResty source
RUN wget -O openresty.tar.gz "https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz" \
  && mkdir -p openresty \
  && tar xzf openresty.tar.gz -C openresty --strip-components 1 \
  && rm openresty.tar.gz

# Fetch GeoIP2 module source
RUN wget -O geoip2.tar.gz "https://github.com/leev/ngx_http_geoip2_module/archive/refs/tags/${GEOIP2_VERSION}.tar.gz" \
  && mkdir -p geoip2 \
  && tar xzf geoip2.tar.gz -C geoip2 --strip-components 1 \
  && rm geoip2.tar.gz

WORKDIR /build/openresty

# Build OpenResty + dynamic modules
RUN ./configure \
    --prefix=/opt/openresty \
    --with-compat \
    --with-pcre-jit \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_realip_module \
    --with-http_stub_status_module \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_mp4_module \
    --with-http_random_index_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_sub_module \
    --with-stream \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --add-dynamic-module=/build/geoip2 \
    --with-cc-opt="-O2 -fstack-protector-strong -D_FORTIFY_SOURCE=2" \
    --with-ld-opt="-Wl,-z,relro -Wl,-z,now" \
  && make -j"$(nproc)" \
  && make install

ENV LUAJIT_BIN=/opt/openresty/luajit/bin/luajit
ENV LUAJIT_LIB=/opt/openresty/luajit/lib
ENV LUAJIT_INC=/opt/openresty/luajit/include/luajit-2.1

RUN luarocks install lua-resty-worker-events 0.3.3-1 --lua-dir=/opt/openresty/luajit --tree=/opt/openresty
RUN luarocks install lua-resty-openidc --lua-dir=/opt/openresty/luajit --tree=/opt/openresty
RUN luarocks install lua-resty-healthcheck 3.1.1-1 --lua-dir=/opt/openresty/luajit --tree=/opt/openresty --force




# Stage 2 - run hardened OpenResty Debian container
FROM debian:${DEBIAN_VERSION}-slim AS run
LABEL maintainer="mail@alexanderwolz.de"

ARG DEBIAN_VERSION
ENV DEBIAN_VERSION=${DEBIAN_VERSION}

ARG OPENRESTY_VERSION
ENV OPENRESTY_VERSION=${OPENRESTY_VERSION}

ARG GEOIP2_VERSION
ENV GEOIP2_VERSION=${GEOIP2_VERSION}

ENV PATH="/opt/openresty/luajit/bin:/opt/openresty/nginx/sbin:/opt/openresty/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV LUA_PATH="/opt/openresty/share/lua/5.1/?.lua;/opt/openresty/share/lua/5.1/?/init.lua;;"
ENV LUA_CPATH="/opt/openresty/lib/lua/5.1/?.so;;"

# Runtime dependencies only (no compiler/toolchain)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libmaxminddb0 \
    libpcre2-8-0 \
    zlib1g \
    libssl3 \
  && rm -rf /var/lib/apt/lists/*

# Sophisticated Docker entrypoint for checking fake certs and geoip database 
COPY docker-entrypoint.sh /
COPY entrypoint.sh /docker-entrypoint.d/00-custom-entrypoint.sh

# Copy OpenResty install from builder
COPY --from=build /opt/openresty /opt/openresty

# Copy dynamic modules (explicit, so you see what gets added)
COPY --from=build /opt/openresty/nginx/modules/ngx_http_geoip2_module.so /opt/openresty/nginx/modules/
COPY --from=build /opt/openresty/nginx/modules/ngx_stream_geoip2_module.so /opt/openresty/nginx/modules/

# Copy sample geo database
COPY geoip/sample.mmdb /etc/geoip_sample/sample.mmdb
COPY geoip/sample.mmdb /etc/geoip/GeoLite2-Country.mmdb
COPY geoip/sample.mmdb /etc/geoip/GeoLite2-City.mmdb

# Default gateway configs
COPY config/nginx.conf /opt/openresty/nginx/conf/nginx.conf
COPY config/includes /opt/openresty/nginx/conf/includes/
COPY config/defaults /opt/openresty/nginx/conf/defaults/

# Common LUA scripts
COPY config/lua /opt/openresty/lualib/

# Prepare writable dirs for non-root operation
# NOTE: for readOnlyRootFilesystem=true -> mount tmpfs/emptyDir for these paths.
RUN mkdir -p \
    /var/run/nginx \
    /opt/openresty/nginx/logs \
    /opt/openresty/nginx/client_body_temp \
    /opt/openresty/nginx/proxy_temp \
    /opt/openresty/nginx/fastcgi_temp \
    /opt/openresty/nginx/uwsgi_temp \
    /opt/openresty/nginx/scgi_temp \
    /opt/openresty/lualib/custom \
    /opt/openresty/nginx/conf/vhosts/http \
    /opt/openresty/nginx/conf/vhosts/stream \
    /etc/ssl/gateway \
    /var/www/certbot \
    /var/www/html \
  && rm -rf /opt/openresty/nginx/logs/access.log \
  && rm -rf /opt/openresty/nginx/logs/error.log \
  && ln -sf /dev/stdout /opt/openresty/nginx/logs/access.log \
  && ln -sf /dev/stderr /opt/openresty/nginx/logs/error.log \
  && chmod +x /docker-entrypoint.sh \
  && chmod +x /docker-entrypoint.d/00-custom-entrypoint.sh \
  && chown -R "nobody:nogroup" \
    /docker-entrypoint.sh \
    /docker-entrypoint.d \
    /var/run/nginx \
    /opt/openresty/nginx/conf \
    /opt/openresty/nginx/logs \
    /opt/openresty/nginx/client_body_temp \
    /opt/openresty/nginx/proxy_temp \
    /opt/openresty/nginx/fastcgi_temp \
    /opt/openresty/nginx/uwsgi_temp \
    /opt/openresty/nginx/scgi_temp \
    /opt/openresty/nginx/modules \
    /opt/openresty/lualib/custom \
    /etc/ssl/gateway \
    /etc/geoip \
    /etc/geoip_sample \
    /var/www \
  && chmod -R u=rwX,g=rX,o=rX /opt/openresty \
  && chmod -R u=rwX,g=rwX,o=rX /opt/openresty/nginx/logs /var/run/nginx /etc/geoip /var/www/certbot

USER nobody

HEALTHCHECK CMD ["/opt/openresty/bin/resty", "/opt/openresty/lualib/healthcheck.lua"]

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/opt/openresty/bin/openresty", "-g", "daemon off;"]
