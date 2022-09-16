FROM --platform=linux/amd64 alpine:3.16.2

ARG NGINX_VERSION=1.22.0
ARG OPENSSL_VERSION=1.1.1q

ENV NGINX_VERSION=${NGINX_VERSION}
ENV OPENSSL_VERSION=${OPENSSL_VERSION}

LABEL Maintainer="Kirill Abramov <i@abramovk.ru>" \
      "GitHub Link"="https://github.com/abramovk/nginx" \
      "Nginx Version"="${NGINX_VERSION}" \
      "OpenSSL Version"="${OPENSSL_VERSION}" \
      "Alpine Linux Version"="3.16.2"
LABEL Description="Nginx ${NGINX_VERSION} with extensions on Alpine Linux."

RUN apk upgrade --no-cache --update && \
    apk add --no-cache --update \
        bash \
        ca-certificates \
        geoip \
        libxml2 \
        libxslt \
        openssl \
        pcre \
        tzdata \
        wget \
        zlib

RUN set -x && \
    apk --no-cache add -t .build-deps \
        build-base \
        curl \
        geoip-dev \
        git \
        geoip-dev \
        libxml2-dev \
        libxslt-dev \
        linux-headers \
        openssl-dev \
        pcre-dev \
        perl-dev \
        zlib-dev

RUN cd /tmp && \
    git clone https://github.com/openresty/headers-more-nginx-module.git && \
    git clone https://github.com/vozlt/nginx-module-vts.git && \
    git clone https://github.com/nginx/njs.git && \
    git clone https://github.com/wandenberg/nginx-push-stream-module.git && \
    git clone https://github.com/arut/nginx-dav-ext-module.git && \
    git clone https://github.com/openresty/echo-nginx-module.git && \
    curl -L https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz | tar -zx

RUN cd /tmp && \
    curl -L http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz | tar -zx && \
    cd /tmp/nginx-${NGINX_VERSION} && \
    ./configure \
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=/var/run/nginx.pid \
        --lock-path=/var/run/nginx.lock \
        --http-client-body-temp-path=/var/cache/nginx/client_temp \
        --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
        --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
        --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
        --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
        --user=nginx \
        --group=nginx \
        --with-compat \
        --with-pcre-jit \
        --with-http_addition_module \
        --with-http_auth_request_module \
        --with-http_dav_module \
        --with-http_random_index_module \
        --with-http_slice_module \
        --with-stream_realip_module \
        --with-stream_ssl_preread_module \
        --with-file-aio \
        --with-http_ssl_module \
        --with-http_v2_module \
        --with-http_realip_module \
        --with-http_stub_status_module \
        --with-http_sub_module \
        --with-http_gunzip_module \
        --with-http_secure_link_module \
        --with-http_gzip_static_module \
        --with-threads \
        --with-stream \
        --with-stream_ssl_module \
        --with-http_geoip_module \
        --conf-path=/etc/nginx/nginx.conf \
        --http-log-path=/var/log/nginx/access.log \
        --error-log-path=/var/log/nginx/error.log \
        --pid-path=/var/run/nginx.pid \
        --lock-path=/var/run/nginx.lock \
        --add-module=/tmp/headers-more-nginx-module \
        --add-module=/tmp/nginx-module-vts \
        --add-module=/tmp/njs/nginx \
        --add-module=/tmp/nginx-push-stream-module \
        --add-module=/tmp/nginx-dav-ext-module \
        --add-module=/tmp/echo-nginx-module \
        --with-openssl=/tmp/openssl-${OPENSSL_VERSION} \
        --with-openssl-opt="enable-tls1_3" && \
        make && \
        make -j$(nproc) install --silent && \
        addgroup -S nginx && \
        adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx

RUN cd && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

RUN mkdir -p /usr/share/GeoIP && \
    wget https://cdn.gpn-card.com/geoip_update.sh -P /tmp && \
    sh /tmp/geoip_update.sh

ENV LANG ru_RU.UTF-8
ENV LC_CTYPE ru_RU.UTF-8
RUN ln -snf /usr/share/zoneinfo/Europe/Moscow /etc/localtime && echo Europe/Moscow > /etc/timezone

COPY ./files/nginx.conf /etc/nginx/nginx.conf
COPY ./files/fastcgi_params /etc/nginx/fastcgi_params
COPY ./files/proxy_params /etc/nginx/proxy_params
COPY ./files/default.conf /etc/nginx/conf.d/default.conf

RUN set -eux \
    && apk del .build-deps \
    && rm -rf /var/cache/apk/* /var/tmp/* /tmp/* /usr/share/GeoIP/*.gz /etc/nginx/*.default /etc/nginx/fastcgi.conf \
    && true
    
RUN set -eux \
    && (find /usr/local/bin -type f -print0 | xargs -n1 -0 strip --strip-all -p 2>/dev/null || true) \
    && (find /usr/local/lib -type f -print0 | xargs -n1 -0 strip --strip-all -p 2>/dev/null || true) \
    && (find /usr/local/sbin -type f -print0 | xargs -n1 -0 strip --strip-all -p 2>/dev/null || true) \
    && true

EXPOSE 80 443

STOPSIGNAL SIGQUIT

CMD ["nginx", "-g", "daemon off;"]