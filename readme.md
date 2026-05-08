## What is this?
[![Build and push to Docker Hub](https://github.com/vincejv/angie-docker/actions/workflows/build.yml/badge.svg?branch=master)](https://github.com/vincejv/angie-docker/actions/workflows/build.yml)

Stable and up-to-date [Angie](https://angie.software/en/) (NGINX-based web server) container image with:

* [QUIC + HTTP/3 support](https://nginx.org/en/docs/http/ngx_http_v3_module.html)
* [Google `brotli` compression](https://github.com/google/ngx_brotli)
* [`njs` module](https://nginx.org/en/docs/njs/)
* built in [ech-key-rotate](https://github.com/vincejv/angie-docker/blob/master/ech-rotate.sh)
* Modern TLS configuration based on [Mozilla SSL recommendations](https://ssl-config.mozilla.org/) powered by OpenSSL 4.x
* Compiled with LLVM against glibc for maximum performance in `x86_64`

This project is currently migrating from FreeNGINX to Angie.
Docker image name is now:

```bash
docker pull vincejv/angie:latest
```

Images are also available on [GitHub Container Registry](https://github.com/vincejv/angie-docker/pkgs/container/angie):

```bash
docker pull ghcr.io/vincejv/angie:latest
```

---

## How to use this image
As this project is based on the official [nginx image](https://hub.docker.com/_/nginx/) look for instructions there. In addition to the standard configuration directives, you'll be able to use the brotli module specific ones, see [here for official documentation](https://github.com/google/ngx_brotli#configuration-directives)

```
docker pull vincejv/angie:latest
```

You can fetch an image from [Github Containers Registry](https://github.com/vincejv/angie-docker/pkgs/container/angie) as well:

```
docker pull ghcr.io/vincejv/angie:latest
```

## What's inside

* [built-in Angie modules](https://nginx.org/en/docs/)
* [ech-key-rotate](https://github.com/vincejv/angie-docker/blob/master/ech-rotate.sh) - Encrypted Client Hello (ECH) DNS records need to be rotated regularly - often hourly, to maintain security, prevent unauthorized access to private keys, and adapt to changing network conditions.Refer to [`docker-compose.yml`](https://github.com/vincejv/angie-docker/blob/master/docker-compose.yml) on how to use it for cloudflare (only CF is supported for now)
* [`headers-more-nginx-module`](https://github.com/openresty/headers-more-nginx-module#readme) - sets and clears HTTP request and response headers
* [`ngx_brotli`](https://github.com/google/ngx_brotli#configuration-directives) - adds [brotli response compression](https://datatracker.ietf.org/doc/html/rfc7932)
* [`ngx_http_geoip2_module`](https://github.com/leev/ngx_http_geoip2_module#download-maxmind-geolite2-database-optional) - creates variables with values from the maxmind geoip2 databases based on the client IP
* [`njs` module](https://nginx.org/en/docs/njs/) - a subset of the JavaScript language that allows extending nginx functionality
* [`ngx-fancyindex` module](https://github.com/aperezdc/ngx-fancyindex) - makes possible the generation of file listings, like the built-in autoindex module does, but adding a touch of style
* [`zstd-nginx` module](https://nginx.org/en/docs/njs/) - Zstandard compression over HTTP on the fly

```
$ docker run -it vincejv/angie nginx -V
Angie version: Angie/1.11.4 (quic-ech-32b19e0)
nginx version: nginx/1.29.3
built on Fri, 08 May 2026 15:08:55 GMT
built with OpenSSL 4.0.0 14 Apr 2026
TLS SNI support enabled
configure arguments: 
  --with-cc-opt='-O2 -fomit-frame-pointer -march=sandybridge -I /usr/src/quickjs -DTCP_FASTOPEN=23 -I/opt/openssl/include' \
  --with-ld-opt='-flto -s -Wl,-Bsymbolic-functions -Wl,-z,relro -Wl,-z,now -Wl,--gc-sections -L/usr/src/quickjs -lquickjs -ljemalloc -lstdc++ -L/opt/openssl/lib64 -Wl,-rpath,/opt/openssl/lib64' \
  --build=quic-ech-32b19e0 \
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
  --with-cc=clang

$ docker run -it vincejv/angie njs -v
0.8.4
```

## SSL Grade A+ handling

Please refer to [Mozilla's SSL Configuration Generator](https://ssl-config.mozilla.org/). This image has `https://ssl-config.mozilla.org/ffdhe2048.txt` DH parameters for DHE ciphers fetched and stored in `/etc/ssl/dhparam.pem`:

```
    ssl_dhparam /etc/ssl/dhparam.pem;
```

See [ssllabs.com test results for matrix.vincejv.com](https://www.ssllabs.com/ssltest/analyze.html?d=matrix.vincejv.com).

## nginx config files includes

* `.conf` files mounted in `/etc/nginx/main.d` will be included in the `main` nginx context (e.g. you can call [`env` directive](http://nginx.org/en/docs/ngx_core_module.html#env) there)
* `.conf` files mounted in `/etc/nginx/conf.d` will be included in the `http` nginx context

## QUIC + HTTP/3 support

<img width="577" alt="Screenshot 2021-05-19 at 16 31 10" src="https://user-images.githubusercontent.com/1929317/118840921-baf7d300-b8bf-11eb-8c0f-e57d573a28ce.png">

Please refer to `tests/https.conf` config file for an example config used by the tests. And to Cloudflare docs on [how to enable http/3 support in your browser](https://developers.cloudflare.com/http3/firefox).

```
server {
    # http/3
    listen 443 quic reuseport;

    # http/2 and http/1.1
    listen 443 ssl;
    http2 on;

    server_name localhost;  # customize to match your domain

    # you need to mount these files when running this container
    ssl_certificate     /etc/nginx/ssl/localhost.crt;
    ssl_certificate_key /etc/nginx/ssl/localhost.key;

    # TLSv1.3 is required for QUIC.
    ssl_protocols TLSv1.2 TLSv1.3;

    # 0-RTT QUIC connection resumption
    ssl_early_data on;

    # Add Alt-Svc header to negotiate HTTP/3.
    add_header alt-svc 'h3=":443"; ma=86400';

    # Sent when QUIC was used
    add_header QUIC-Status $http3;

    location / {
        # your config
    }
}
```

Refer to [`docker-compose.yml`](https://github.com/vincejv/angie-docker/blob/master/docker-compose.yml) file on how to run this container and properly mount required config files and assets.

## Development

Building an image:

```
docker pull ghcr.io/vincejv/angie:latest
DOCKER_BUILDKIT=1 docker build . -t vincejv/angie --cache-from=ghcr.io/vincejv/angie:latest --progress=plain
```

### Docker Compose example

It is necessary to expose both UDP and TCP ports to be able to HTTP/3

```yaml
  nginx:
    image: vincejv/angie
    ports:
      - '443:443/tcp'
      - '443:443/udp' # use UDP for usage of HTTP/3
```

Note: both TCP and UDP HTTP/3 ports needs to be the same


# Notes

* Project is transitioning from FreeNGINX branding to Angie
* Existing nginx-compatible configurations should continue and will to work so may switch containers back and forth from nginx, freenginx and Angie
* HTTP/3 support depends on client/browser support and UDP reachability