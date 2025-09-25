# https://hg.nginx.org/nginx/file/tip/src/core/nginx.h
ARG NGINX_VERSION=1.29.2

# https://github.com/freenginx/nginx
ARG NGINX_COMMIT=d34d3c877e177c9f2cf6e13da1bddfaf3f00adb7
ARG NGINX_REV=56d817adaa1d

# https://github.com/google/ngx_brotli
ARG NGX_BROTLI_COMMIT=a71f9312c2deb28875acc7bacfdd5695a111aa53

# https://github.com/google/boringssl
ARG BORINGSSL_COMMIT=a34ea4da91402cb24e635da0b5d755fb0086fd97

# https://github.com/nginx/njs/releases/tag/0.9.1
ARG NJS_VERSION=0.9.1

# https://github.com/bellard/quickjs/commits/fa628f8c523ecac8ce560c081411e91fcaba2d20/
ARG QUICKJS_COMMIT=fa628f8c523ecac8ce560c081411e91fcaba2d20

# https://github.com/openresty/headers-more-nginx-module#installation
# we want to have https://github.com/openresty/headers-more-nginx-module/commit/e536bc595d8b490dbc9cf5999ec48fca3f488632
ARG HEADERS_MORE_VERSION=0.39

# https://github.com/leev/ngx_http_geoip2_module/releases
ARG GEOIP2_VERSION=3.4

# https://github.com/aperezdc/ngx-fancyindex
ARG FANCYINDEX_COMMIT=cbc0d3fca4f06414612de441399393d4b3bbb315

# https://github.com/tokers/zstd-nginx-module
ARG ZSTDNGINX_COMMIT=f4ba115e0b0eaecde545e5f37db6aa18917d8f4b

# https://github.com/PCRE2Project/pcre2
ARG PCRE_VERSION=10.46

# https://github.com/zlib-ng/zlib-ng.git
ARG ZLIB_VERSION=2.2.5

# NGINX UID / GID
ARG NGINX_USER_UID=100
ARG NGINX_GROUP_GID=101

# Generic CFLAGS across build
ARG CFLAGS_OPT="-O3 -pipe -falign-functions=32 -fdata-sections -ffunction-sections -fomit-frame-pointer -Wno-cast-function-type-mismatch -march=sandybridge"
ARG LDFLAGS_OPT="-O3 -Wl,--strip-all -Wl,--as-needed"

# NGINX Native CC Opt
ARG CC_OPT="-O3 -flto -ffat-lto-objects -fomit-frame-pointer -march=sandybridge -I../boringssl/include -I /usr/src/quickjs -DTCP_FASTOPEN=23"
ARG LD_OPT="-s -Wl,-Bsymbolic-functions -Wl,-z,relro -Wl,-z,now -Wl,--gc-sections -L../boringssl/build -lstdc++ -L /usr/src/quickjs -ljemalloc"

# https://nginx.org/en/docs/http/ngx_http_v3_module.html
ARG CONFIG="\
  --build=boringssl-quic-ech-$NGINX_REV \
  --prefix=/etc/nginx \
  --sbin-path=/usr/sbin/nginx \
  --modules-path=/usr/lib/nginx/modules \
  --conf-path=/etc/nginx/nginx.conf \
  --error-log-path=/var/log/nginx/error.log \
  --http-log-path=/var/log/nginx/access.log \
  --pid-path=/var/run/nginx/nginx.pid \
  --lock-path=/var/run/nginx/nginx.lock \
  --http-client-body-temp-path=/var/cache/nginx/client_temp \
  --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
  --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
  --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
  --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
  --user=nginx \
  --group=nginx \
  --with-http_ssl_module \
  --with-http_realip_module \
  --with-http_addition_module \
  --with-http_sub_module \
  --with-http_dav_module \
  --with-http_flv_module \
  --with-http_mp4_module \
  --with-http_gunzip_module \
  --with-http_gzip_static_module \
  --with-http_random_index_module \
  --with-http_secure_link_module \
  --with-http_stub_status_module \
  --with-http_auth_request_module \
  --with-http_xslt_module=dynamic \
  --with-http_image_filter_module=dynamic \
  --with-http_geoip_module=dynamic \
  --with-http_perl_module=dynamic \
  --with-threads \
  --with-stream \
  --with-stream_ssl_module \
  --with-stream_ssl_preread_module \
  --with-stream_realip_module \
  --with-stream_geoip_module=dynamic \
  --with-http_slice_module \
  --with-compat \
  --with-pcre-jit \
  --with-ipv6 \
  --with-file-aio \
  --with-http_v2_module \
  --with-http_v3_module \
  --without-http_browser_module \
  --without-http_empty_gif_module \
  --without-mail_pop3_module \
  --without-mail_imap_module \
  --without-mail_smtp_module \
  --with-pcre=/usr/src/pcre2 \
  --with-zlib=/usr/src/zlib-ng \
  --add-module=/usr/src/ngx_brotli \
  --add-module=/usr/src/headers-more-nginx-module \
  --add-module=/usr/src/njs/nginx \
  --add-module=/usr/src/ngx_http_fancyindex_module \
  --add-module=/usr/src/zstd-nginx-module \
  --add-dynamic-module=/usr/src/ngx_http_geoip2_module \
  --with-cc=clang \
"

FROM debian:trixie AS base

ARG NGINX_VERSION
ARG NGINX_COMMIT
ARG NGX_BROTLI_COMMIT
ARG HEADERS_MORE_VERSION
ARG NJS_VERSION
ARG QUICKJS_COMMIT
ARG PCRE_VERSION
ARG ZLIB_VERSION
ARG GEOIP2_VERSION
ARG NGINX_USER_UID
ARG NGINX_GROUP_GID
ARG CONFIG
ARG CFLAGS_OPT
ARG LDFLAGS_OPT
ARG CC_OPT
ARG LD_OPT

ENV CFLAGS="$CFLAGS_OPT" \
  CXXFLAGS="$CFLAGS_OPT" \
  CPPFLAGS="$CFLAGS_OPT" \
  LDFLAGS="$LDFLAGS_OPT" \
  CC=clang \
  CXX=clang++

# Development environment
RUN \
  apt-get update && apt-get install -y --no-install-recommends \
    curl \
    libc6-dev \
    make \
    golang \
    ninja-build \
    mercurial \
    libssl-dev \
    libpcre2-dev \
    zlib1g-dev \
    gnupg \
    libxslt-dev \
    libgd-dev \
    libgeoip-dev \
    libperl-dev \
    autoconf \
    libtool \
    libzstd-dev \
    automake \
    git \
    g++ \
    cmake \
    wget \
    ca-certificates \
    lsb-release \
    llvm \
    clang \
    libmaxminddb-dev \
    libjemalloc-dev \
    libreadline-dev

WORKDIR /usr/src/

RUN \
  echo "Cloning nginx $NGINX_VERSION (commit $NGINX_COMMIT from 'default' branch) ..." \
  # && hg clone -b default --rev $NGINX_COMMIT https://freenginx.org/hg/nginx/ /usr/src/nginx-$NGINX_VERSION
  && mkdir /usr/src/nginx \
  && cd /usr/src/nginx \
  && git init \
  && git remote add origin https://github.com/freenginx/nginx.git \
  && git fetch --depth 1 origin ${NGINX_COMMIT} \
  && git checkout -q FETCH_HEAD

RUN \
  echo "Cloning brotli $NGX_BROTLI_COMMIT ..." \
  && mkdir /usr/src/ngx_brotli \
  && cd /usr/src/ngx_brotli \
  && git init \
  && git remote add origin https://github.com/google/ngx_brotli.git \
  && git fetch --depth 1 origin $NGX_BROTLI_COMMIT \
  && git checkout --recurse-submodules -q FETCH_HEAD \
  && git submodule update --init --depth 1

# hadolint ignore=SC2086
RUN \
 echo "Cloning boringssl ..." \
 && cd /usr/src \
 && git clone --depth 1 https://boringssl.googlesource.com/boringssl \
 && cd boringssl \
 && git checkout $BORINGSSL_COMMIT

RUN \
 echo "Building boringssl ..." \
 && cd /usr/src/boringssl \
 && mkdir build \
 && cd build \
 && cmake -GNinja .. \
 && ninja

RUN \
  echo "Downloading headers-more-nginx-module ..." \
  && mkdir /usr/src/headers-more-nginx-module \
  && wget -qO- https://github.com/openresty/headers-more-nginx-module/archive/refs/tags/v${HEADERS_MORE_VERSION}.tar.gz \
    | tar xz --strip-components=1 -C /usr/src/headers-more-nginx-module

RUN \
  echo "Downloading ngx_http_geoip2_module ..." \
  && git clone --depth 1 --branch ${GEOIP2_VERSION} https://github.com/leev/ngx_http_geoip2_module /usr/src/ngx_http_geoip2_module

RUN \
  echo "Downloading ngx_http_fancyindex_module ..." \
  && git clone https://github.com/aperezdc/ngx-fancyindex /usr/src/ngx_http_fancyindex_module && cd /usr/src/ngx_http_fancyindex_module && git checkout ${FANCYINDEX_COMMIT}

RUN \
  echo "Downloading zstd-nginx-module ..." \
  && git clone https://github.com/tokers/zstd-nginx-module /usr/src/zstd-nginx-module && cd /usr/src/zstd-nginx-module && git checkout ${ZSTDNGINX_COMMIT}

# QuickJS (njs dependency)
RUN \
    echo "Cloning and configuring quickjs ..." \
    && mkdir /usr/src/quickjs \
    && cd /usr/src/quickjs \
    && git init \
    && git remote add origin https://github.com/bellard/quickjs \
    && git fetch --depth 1 origin ${QUICKJS_COMMIT} \
    && git checkout -q ${QUICKJS_COMMIT} \
    && make libquickjs.a \
    && echo "quickjs $(cat VERSION)"

RUN \
  echo "Cloning and configuring njs ..." \
  && git clone --depth 1 -b ${NJS_VERSION} https://github.com/nginx/njs.git /usr/src/njs \
  && cd /usr/src/njs \
  && ./configure --cc-opt='-I /usr/src/quickjs' --ld-opt="-L /usr/src/quickjs" \
  && make njs \
  && mv build/njs /usr/sbin/njs \
  && echo "njs v$(njs -v)"

RUN \
  echo "Cloning pcre2 ..." \
  && git clone --depth 1 --recurse-submodules -b pcre2-${PCRE_VERSION} https://github.com/PCRE2Project/pcre2.git /usr/src/pcre2

RUN \
  echo "Cloning and configuring zlib-ng ..." \
  && git clone --depth 1 -b ${ZLIB_VERSION} https://github.com/zlib-ng/zlib-ng.git /usr/src/zlib-ng \
  && sed -i "s/compat=0/compat=1/" /usr/src/zlib-ng/configure \
  && cd /usr/src/zlib-ng \
  && ./configure --zlib-compat

RUN \
  echo "Building nginx ..." \
  && mkdir -p /var/run/nginx/ \
  && cd /usr/src/nginx \
  && ./auto/configure \
    --with-cc-opt="$CC_OPT" \
    --with-ld-opt="$LD_OPT" \
    $CONFIG \
      || (echo "==== CONFIGURE FAILED ====" && cat objs/autoconf.err && exit 1) \
  && make -j"$(getconf _NPROCESSORS_ONLN)"

RUN \
  cd /usr/src/nginx \
  && make install \
  && rm -rf /etc/nginx/html/ \
  && mkdir /etc/nginx/conf.d/ \
  && strip /usr/sbin/nginx* \
  && strip /usr/lib/nginx/modules/*.so \
  && strip /usr/src/boringssl/build/bssl \
  \
  # https://tools.ietf.org/html/rfc7919
  # https://github.com/mozilla/ssl-config-generator/blob/master/docs/ffdhe2048.txt
  && wget -q https://ssl-config.mozilla.org/ffdhe2048.txt -O /etc/ssl/dhparam.pem

FROM debian:trixie-slim
ARG NGINX_USER_UID
ARG NGINX_GROUP_GID

COPY --from=base /var/run/nginx/ /var/run/nginx/
# COPY --from=base /tmp/runDeps.txt /tmp/runDeps.txt
COPY --from=base /etc/nginx /etc/nginx
COPY --from=base /usr/lib/nginx/modules/*.so /usr/lib/nginx/modules/
COPY --from=base /usr/sbin/nginx /usr/sbin/
# COPY --from=base /usr/local/lib/perl5/site_perl /usr/local/lib/perl5/site_perl
# COPY --from=base /usr/bin/envsubst /usr/local/bin/envsubst
COPY --from=base /etc/ssl/dhparam.pem /etc/ssl/dhparam.pem
# COPY --from=base /usr/lib/libcrypto.so* /usr/lib/
COPY --from=base /usr/sbin/njs /usr/sbin/njs

# OpenSSL ECH binaries
COPY --from=base /usr/src/boringssl/build/bssl /usr/bin/bssl

# Runtime environment
# hadolint ignore=SC2046
RUN \
groupadd --gid $NGINX_GROUP_GID nginx \
&& useradd --uid $NGINX_USER_UID --system --create-home --home-dir /var/cache/nginx --shell /usr/sbin/nologin --gid nginx nginx \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    jq \
    libjemalloc2 \
    tzdata \
    libssl3 \
    libxml2 \
    libbrotli1 \
    libxslt1.1 \
    libzstd1 \
    wget \
  # Clean image
  && apt-get clean autoclean \
  && apt-get autoremove --yes \
  && rm -rf /var/lib/{apt,dpkg,cache,log}/ \
  && ln -s /usr/lib/nginx/modules /etc/nginx/modules \
  # forward request and error logs to docker log collector
  && mkdir /var/log/nginx \
  && touch /var/log/nginx/access.log /var/log/nginx/error.log \
  && ln -sf /dev/stdout /var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log

COPY nginx.conf /etc/nginx/nginx.conf
COPY ssl_common.conf /etc/nginx/conf.d/ssl_common.conf
COPY ech-rotate.sh init-ech.sh update-https-records.sh generate-ech-key.sh /usr/local/bin
COPY start-nginx.sh /start-nginx.sh

# Make scripts executable
RUN chmod +x /start-nginx.sh /usr/local/bin/ech-rotate.sh /usr/local/bin/init-ech.sh

# show env
RUN env | sort

# njs version
RUN njs -v

# test the configuration
RUN nginx -V; nginx -t

EXPOSE 8080 8443

STOPSIGNAL SIGTERM

# prepare to switching to non-root - update file permissions of directory containing
# nginx.lock and nginx.pid file
RUN \
  chown -R --verbose nginx:nginx \
    /var/run/nginx/

USER nginx
CMD ["/start-nginx.sh"]
