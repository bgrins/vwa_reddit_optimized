#!/bin/sh
set -e

echo "Starting standalone application (external database required)..."

# Check if DATABASE_URL is set
if [ -z "$DATABASE_URL" ]; then
    echo "ERROR: DATABASE_URL environment variable is required for standalone mode"
    echo "Example: DATABASE_URL=postgresql://user:pass@host:5432/dbname"
    exit 1
fi

# Create .env.local from environment variables
cat > /var/www/html/.env.local << EOF
APP_ENV=prod
APP_SECRET=${APP_SECRET:-$(openssl rand -hex 32)}
DATABASE_URL=${DATABASE_URL}
EOF

# Clear and warm cache
php /var/www/html/bin/console cache:clear --env=prod --no-debug
php /var/www/html/bin/console cache:warmup --env=prod --no-debug

# Set permissions for runtime directories only
if [ -d /var/www/html/var ]; then
    chown -R nginx:nginx /var/www/html/var
fi

echo "Application ready. Connect to external database via DATABASE_URL."
exec "$@"