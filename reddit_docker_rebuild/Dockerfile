# Multi-stage Dockerfile for reddit-forum
# Build with: docker build --target=<stage> -t <tag> .
# Stages: with-postgres (default), without-postgres
# Requires: bgrins/vwa-reddit-optimized-base:latest image to be built first

# ============================================================================
# WITH-POSTGRES STAGE - Includes bundled PostgreSQL database
# ============================================================================
FROM bgrins/vwa-reddit-optimized-base:latest AS with-postgres

# Create PostgreSQL data directory
RUN mkdir -p /usr/local/pgsql/data

# Install PostgreSQL
RUN apk add --no-cache \
    postgresql14 \
    postgresql14-client \
    postgresql14-contrib

# Copy database dump
COPY postmill_dump.sql /tmp/

# Initialize PostgreSQL and import data during build
RUN mkdir -p /run/postgresql \
    && chown -R postgres:postgres /usr/local/pgsql /run/postgresql \
    && su - postgres -c "initdb -D /usr/local/pgsql/data" \
    && echo "host all all 0.0.0.0/0 md5" >> /usr/local/pgsql/data/pg_hba.conf \
    && echo "listen_addresses='*'" >> /usr/local/pgsql/data/postgresql.conf \
    && { su - postgres -c "postgres -D /usr/local/pgsql/data" & } \
    && sleep 10 \
    && su - postgres -c "createuser -s db_user" \
    && su - postgres -c "createdb -O db_user postmill" \
    && su - postgres -c "psql -U db_user -d postmill < /tmp/postmill_dump.sql" \
    && su - postgres -c "psql -U db_user -d postmill -c \"ALTER USER db_user WITH PASSWORD 'db_password';\"" \
    && su - postgres -c "pg_ctl -D /usr/local/pgsql/data stop -m fast" \
    && sleep 5 \
    && rm /tmp/postmill_dump.sql

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

# Configure Supervisor for PostgreSQL + web services
COPY supervisord.conf /etc/supervisord.conf

# Create startup script for bundled version
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Set working directory
WORKDIR /var/www/html

# Expose ports
EXPOSE 80 5432

# Start services
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisord.conf"]

# ============================================================================
# WITHOUT-POSTGRES STAGE - Standalone application (external database)
# ============================================================================
FROM bgrins/vwa-reddit-optimized-base:latest AS without-postgres

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

# ============================================================================
# DEFAULT TARGET - with-postgres for backward compatibility
# ============================================================================
FROM with-postgres AS final