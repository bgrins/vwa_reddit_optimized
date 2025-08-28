# Single stage build - using everything from the extracted container
FROM alpine:3.17

# Create necessary directories
RUN mkdir -p /var/www/html \
    && mkdir -p /run/nginx \
    && mkdir -p /run/php \
    && mkdir -p /var/log/supervisor \
    && mkdir -p /usr/local/pgsql/data

# Copy large submission_images first
COPY --chown=nginx:nginx postmill_app/public/submission_images /var/www/html/public/submission_images

# Copy rest of application (excluding submission_images to avoid duplication)
COPY postmill_app/assets /var/www/html/assets
COPY postmill_app/bin /var/www/html/bin
COPY postmill_app/config /var/www/html/config
COPY postmill_app/migrations /var/www/html/migrations
COPY postmill_app/src /var/www/html/src
COPY postmill_app/templates /var/www/html/templates
COPY postmill_app/translations /var/www/html/translations
COPY postmill_app/vendor /var/www/html/vendor
COPY --chown=nginx:nginx postmill_app/public/build /var/www/html/public/build
COPY --chown=nginx:nginx postmill_app/public/bundles /var/www/html/public/bundles
COPY --chown=nginx:nginx postmill_app/public/js /var/www/html/public/js
COPY --chown=nginx:nginx postmill_app/public/*.* /var/www/html/public/
COPY postmill_app/*.* /var/www/html/

# Copy database dump
COPY postmill_dump.sql /tmp/

# Install runtime packages only
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
    postgresql14 \
    postgresql14-client \
    postgresql14-contrib \
    supervisor \
    bash \
    openssl

# Create media cache directory with proper ownership
RUN mkdir -p /var/www/html/public/media/cache && \
    chown -R nginx:nginx /var/www/html/public/media

# Configure PHP (use -f to force overwrite if exists)
RUN ln -sf /usr/bin/php81 /usr/bin/php || true

# Configure PostgreSQL
RUN chown -R postgres:postgres /usr/local/pgsql \
    && su - postgres -c "initdb -D /usr/local/pgsql/data" \
    && echo "host all all 0.0.0.0/0 md5" >> /usr/local/pgsql/data/pg_hba.conf \
    && echo "listen_addresses='*'" >> /usr/local/pgsql/data/postgresql.conf

# Configure Nginx
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/http.d/default.conf

# Configure PHP-FPM
RUN sed -i 's/user = nobody/user = nginx/g' /etc/php81/php-fpm.d/www.conf \
    && sed -i 's/group = nobody/group = nginx/g' /etc/php81/php-fpm.d/www.conf \
    && sed -i 's/;listen.owner = nobody/listen.owner = nginx/g' /etc/php81/php-fpm.d/www.conf \
    && sed -i 's/;listen.group = nobody/listen.group = nginx/g' /etc/php81/php-fpm.d/www.conf \
    && sed -i 's/;listen.mode = 0660/listen.mode = 0660/g' /etc/php81/php-fpm.d/www.conf

# Configure PHP settings (memory limit, upload size, etc.)
COPY php-overrides.ini /etc/php81/conf.d/99-overrides.ini

# Configure Supervisor
COPY supervisord.conf /etc/supervisord.conf

# Create startup script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Set working directory
WORKDIR /var/www/html

# Expose ports
EXPOSE 80 5432

# Start services
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisord.conf"]