#!/bin/bash
set -e

echo "Starting container (database pre-initialized)..."

# Create PostgreSQL run directory
mkdir -p /run/postgresql
chown postgres:postgres /run/postgresql

# Create .env.local if it doesn't exist
if [ ! -f /var/www/html/.env.local ]; then
    echo "Creating .env.local..."
    cat > /var/www/html/.env.local <<EOF
DATABASE_URL=pgsql://db_user:db_password@localhost:5432/postmill?serverVersion=14
APP_ENV=prod
APP_SECRET="$(openssl rand -hex 32)"
EOF
fi

# Clear and warm up Symfony cache
echo "Preparing Symfony cache..."
cd /var/www/html
php bin/console cache:clear --env=prod --no-warmup
php bin/console cache:warmup --env=prod

# Ensure proper permissions for runtime directories only
# The var directory is created by Symfony at runtime, so we need to fix its permissions
if [ -d /var/www/html/var ]; then
    chown -R nginx:nginx /var/www/html/var
fi

echo "Container ready! Starting services..."

# Execute the main command (supervisord)
exec "$@"