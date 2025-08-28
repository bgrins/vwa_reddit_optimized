# Base image containing the Postmill application, submission images, and PHP runtime
# This is built once and used by both with-postgres and standalone variants

FROM alpine:3.17

# Create necessary directories
RUN mkdir -p /var/www/html \
    && mkdir -p /run/nginx \
    && mkdir -p /run/php \
    && mkdir -p /var/log/supervisor

# Install PHP and web server packages
RUN apk add --no-cache \
    nginx \
    php81 \
    php81-fpm \
    php81-pdo \
    php81-pdo_pgsql \
    php81-mbstring \
    php81-xml \
    php81-ctype \
    php81-gd \
    php81-intl \
    php81-dom \
    php81-session \
    php81-iconv \
    php81-json \
    php81-opcache \
    php81-zip \
    php81-curl \
    php81-tokenizer \
    php81-fileinfo \
    php81-simplexml \
    php81-xmlwriter \
    php81-sodium \
    php81-openssl \
    php81-bcmath \
    supervisor \
    bash \
    openssl

# Configure PHP
RUN ln -sf /usr/bin/php81 /usr/bin/php || true

# Copy entire application with proper ownership
COPY --chown=nginx:nginx postmill_app /var/www/html

# This image is just for storage - no CMD or ENTRYPOINT