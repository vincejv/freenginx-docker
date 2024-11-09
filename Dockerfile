# https://hg.nginx.org/nginx/file/tip/src/core/nginx.h
ARG NGINX_VERSION=1.27.4

# https://hg.nginx.org/nginx-quic/
ARG NGINX_COMMIT=dbf76fdd109f

# https://github.com/google/ngx_brotli
ARG NGX_BROTLI_COMMIT=a71f9312c2deb28875acc7bacfdd5695a111aa53

# https://github.com/google/boringssl
#ARG BORINGSSL_COMMIT=fae0964b3d44e94ca2a2d21f86e61dabe683d130

# https://github.com/nginx/njs/releases/tag/0.8.7
ARG NJS_COMMIT=ba6b9e157ef472dbcac17e32c55f3227daa3103c

# https://github.com/bellard/quickjs/commits/master/
ARG QUICKJS_COMMIT=6e2e68fd0896957f92eb6c242a2e048c1ef3cae0

# https://github.com/openresty/headers-more-nginx-module#installation
# we want to have https://github.com/openresty/headers-more-nginx-module/commit/e536bc595d8b490dbc9cf5999ec48fca3f488632
ARG HEADERS_MORE_VERSION=0.37

# https://github.com/leev/ngx_http_geoip2_module/releases
ARG GEOIP2_VERSION=3.4

# https://github.com/aperezdc/ngx-fancyindex
ARG FANCYINDEX_COMMIT=cbc0d3fca4f06414612de441399393d4b3bbb315

# https://github.com/tokers/zstd-nginx-module
ARG ZSTDNGINX_COMMIT=f4ba115e0b0eaecde545e5f37db6aa18917d8f4b

# https://www.openssl.org/source/
ARG VERSION_OPENSSL=openssl-3.4.0

# NGINX UID / GID
ARG NGINX_USER_UID=100
ARG NGINX_GROUP_GID=101

# Generic CFLAGS across build
ARG CFLAGS_OPT="-O3 -pipe -fomit-frame-pointer -Wno-cast-function-type-mismatch -march=sandybridge"
ARG LDFLAGS_OPT="-O3 -Wl,--strip-all -Wl,--as-needed"

# NGINX Native CC Opt
ARG CC_OPT="-O3 -flto -ffat-lto-objects -fomit-frame-pointer -march=sandybridge -I /usr/src/quickjs"
ARG LD_OPT="-Wl,-Bsymbolic-functions -flto -ffat-lto-objects -flto -Wl,-z,relro -Wl,-z,now -L /usr/src/quickjs"

# https://nginx.org/en/docs/http/ngx_http_v3_module.html
ARG CONFIG="\
		--build=quic-$NGINX_COMMIT \
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
		--with-mail \
		--with-mail_ssl_module \
		--with-compat \
		--with-pcre-jit \
		--with-ipv6 \
		--with-file-aio \
		--with-http_v2_module \
		--with-http_v3_module \
		--with-openssl=/usr/src/$VERSION_OPENSSL \
		--with-openssl-opt=enable-ktls \
		--add-module=/usr/src/ngx_brotli \
		--add-module=/usr/src/headers-more-nginx-module-$HEADERS_MORE_VERSION \
		--add-module=/usr/src/njs/nginx \
		--add-module=/usr/src/ngx_http_fancyindex_module \
		--add-module=/usr/src/zstd-nginx-module \
		--add-dynamic-module=/usr/src/ngx_http_geoip2_module \
		--with-cc=clang-19 \
	"

FROM debian:bookworm AS base

ARG NGINX_VERSION
ARG NGINX_COMMIT
ARG NGX_BROTLI_COMMIT
ARG HEADERS_MORE_VERSION
ARG NJS_COMMIT
ARG GEOIP2_VERSION
ARG NGINX_USER_UID
ARG NGINX_GROUP_GID
ARG CONFIG
ARG CFLAGS_OPT
ARG LDFLAGS_OPT
ARG CC_OPT
ARG LD_OPT

ENV VERSION_OPENSSL=openssl-3.4.0 \
	SHA256_OPENSSL=e15dda82fe2fe8139dc2ac21a36d4ca01d5313c75f99f46c4e8a27709b7294bf \
	SOURCE_OPENSSL=https://github.com/openssl/openssl/releases/download/ \
	CFLAGS="$CFLAGS_OPT" \
    CXXFLAGS="$CFLAGS_OPT" \
    CPPFLAGS="$CFLAGS_OPT" \
    LDFLAGS="$LDFLAGS_OPT" \
    CC=clang-19 \
    CXX=clang++-19

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
		libpcre3-dev \
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
		software-properties-common \
		libmaxminddb-dev \
		libreadline-dev && \
	# download install clang and llvm
	wget https://apt.llvm.org/llvm.sh && \
		chmod +x llvm.sh && ./llvm.sh 19

WORKDIR /usr/src/

RUN \
	echo "Downloading OpenSSL source code ..." && \
	curl -L $SOURCE_OPENSSL/$VERSION_OPENSSL/$VERSION_OPENSSL.tar.gz -o openssl.tar.gz && \
	echo "${SHA256_OPENSSL} ./openssl.tar.gz" | sha256sum -c - && \
	curl -L $SOURCE_OPENSSL/$VERSION_OPENSSL/$VERSION_OPENSSL.tar.gz.asc -o openssl.tar.gz.asc && \
	tar xzf openssl.tar.gz

RUN \
	echo "Cloning nginx $NGINX_VERSION (rev $NGINX_COMMIT from 'default' branch) ..." \
	&& hg clone -b default --rev $NGINX_COMMIT https://freenginx.org/hg/nginx/ /usr/src/nginx-$NGINX_VERSION

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
#RUN \
#  echo "Cloning boringssl ..." \
#  && cd /usr/src \
#  && git clone https://github.com/google/boringssl \
#  && cd boringssl \
#  && git checkout $BORINGSSL_COMMIT

#RUN \
#  echo "Building boringssl ..." \
#  && cd /usr/src/boringssl \
#  && mkdir build \
#  && cd build \
#  && cmake -GNinja .. \
#  && ninja

RUN \
  echo "Downloading headers-more-nginx-module ..." \
  && cd /usr/src \
  && wget -q https://github.com/openresty/headers-more-nginx-module/archive/refs/tags/v${HEADERS_MORE_VERSION}.tar.gz -O headers-more-nginx-module.tar.gz \
  && tar -xf headers-more-nginx-module.tar.gz

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
  echo "Cloning and configuring QuickJS ..." \
  && mkdir /usr/src/quickjs \
  && cd /usr/src/quickjs \
  && git init \
  && git remote add origin https://github.com/bellard/quickjs.git \
  && git fetch --depth 1 origin ${QUICKJS_COMMIT} \
  && git checkout -q FETCH_HEAD \
  && CFLAGS='-fPIC' make libquickjs.a

RUN \
  echo "Cloning and configuring njs ..." \
  && mkdir /usr/src/njs \
  && cd /usr/src/njs \
  && git init \
  && git remote add origin https://github.com/nginx/njs.git \
  && git fetch --depth 1 origin ${NJS_COMMIT} \
  && git checkout -q FETCH_HEAD \
  && ./configure \
  && make njs \
  && mv /usr/src/njs/build/njs /usr/sbin/njs \
  && echo "njs v$(njs -v)"

RUN \
  echo "Building nginx ..." \
  && mkdir -p /var/run/nginx/ \
	&& cd /usr/src/nginx-$NGINX_VERSION \
	&& ./auto/configure \
	  --with-cc-opt="$CC_OPT" \
	  --with-ld-opt="$LD_OPT" \
	  $CONFIG \
	&& make -j"$(getconf _NPROCESSORS_ONLN)"

RUN \
	cd /usr/src/nginx-$NGINX_VERSION \
	&& make install \
	&& rm -rf /etc/nginx/html/ \
	&& mkdir /etc/nginx/conf.d/ \
	&& strip /usr/sbin/nginx* \
	&& strip /usr/lib/nginx/modules/*.so \
	\
	# https://tools.ietf.org/html/rfc7919
	# https://github.com/mozilla/ssl-config-generator/blob/master/docs/ffdhe2048.txt
	&& wget -q https://ssl-config.mozilla.org/ffdhe2048.txt -O /etc/ssl/dhparam.pem

FROM debian:bookworm-slim
ARG NGINX_VERSION
ARG NGINX_COMMIT
ARG NGINX_USER_UID
ARG NGINX_GROUP_GID

ENV NGINX_VERSION=$NGINX_VERSION \
    NGINX_COMMIT=$NGINX_COMMIT

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

# Runtime environment
# hadolint ignore=SC2046
RUN \
groupadd --gid $NGINX_GROUP_GID nginx \
&& useradd --uid $NGINX_USER_UID --system --create-home --home-dir /var/cache/nginx --shell /usr/sbin/nologin --gid nginx nginx \
	&& apt-get update \
	&& apt-get install -y \
		libpcre3 \
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
CMD ["nginx", "-g", "daemon off;"]
