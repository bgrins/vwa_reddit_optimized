# Slim standalone Dockerfile for reddit-forum
# Requires: bgrins/vwa-reddit-optimized-base-slim:latest

FROM bgrins/vwa-reddit-optimized-base-slim:latest

# Configure Nginx
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/http.d/default.conf

# Configure PHP-FPM
RUN sed -i 's/user = nobody/user = nginx/g' /etc/php81/php-fpm.d/www.conf \
    && sed -i 's/group = nobody/group = nginx/g' /etc/php81/php-fpm.d/www.conf \
    && sed -i 's/;listen.owner = nobody/listen.owner = nginx/g' /etc/php81/php-fpm.d/www.conf \
    && sed -i 's/;listen.group = nobody/listen.group = nginx/g' /etc/php81/php-fpm.d/www.conf \
    && sed -i 's/;listen.mode = 0660/listen.mode = 0660/g' /etc/php81/php-fpm.d/www.conf

# Configure PHP settings
COPY php-overrides.ini /etc/php81/conf.d/99-overrides.ini

# Configure Supervisor for web services only (no PostgreSQL)
COPY supervisord-no-postgres.conf /etc/supervisord.conf

# Copy standalone startup script
COPY docker-entrypoint-standalone.sh /docker-entrypoint-standalone.sh
RUN chmod +x /docker-entrypoint-standalone.sh

# Set working directory
WORKDIR /var/www/html

# Expose only web port
EXPOSE 80

# Start services
ENTRYPOINT ["/docker-entrypoint-standalone.sh"]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisord.conf"]
