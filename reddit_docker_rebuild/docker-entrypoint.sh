#!/bin/bash
set -e

echo "Starting container initialization..."

# Create PostgreSQL run directory
mkdir -p /run/postgresql
chown postgres:postgres /run/postgresql

# Start PostgreSQL temporarily to import data
echo "Starting PostgreSQL for data import..."
su - postgres -c "postgres -D /usr/local/pgsql/data" &
PG_PID=$!

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
for i in {1..30}; do
    if su - postgres -c "pg_isready -q"; then
        echo "PostgreSQL is ready"
        break
    fi
    echo "Waiting for PostgreSQL... ($i/30)"
    sleep 1
done

# Create database and user if they don't exist
echo "Setting up database..."
su - postgres -c "psql -tc \"SELECT 1 FROM pg_user WHERE usename = 'db_user'\" | grep -q 1 || psql -c \"CREATE USER db_user WITH PASSWORD 'db_password';\""
su - postgres -c "psql -tc \"SELECT 1 FROM pg_database WHERE datname = 'postmill'\" | grep -q 1 || psql -c \"CREATE DATABASE postmill OWNER db_user;\""
su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE postmill TO db_user;\""

# Import the database dump if it exists and database is empty
if [ -f /tmp/postmill_dump.sql ]; then
    TABLE_COUNT=$(su - postgres -c "psql -U postgres -d postmill -tc \"SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';\"" | tr -d ' ')
    if [ "$TABLE_COUNT" -eq "0" ]; then
        echo "Importing database dump..."
        su - postgres -c "psql -U postgres postmill < /tmp/postmill_dump.sql"
        echo "Database import complete"
        
        # Grant all permissions to db_user on imported tables
        echo "Granting permissions to db_user..."
        su - postgres -c "psql -d postmill -c 'GRANT ALL ON ALL TABLES IN SCHEMA public TO db_user;'"
        su - postgres -c "psql -d postmill -c 'GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO db_user;'"
        su - postgres -c "psql -d postmill -c 'GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO db_user;'"
        su - postgres -c "psql -d postmill -c 'ALTER SCHEMA public OWNER TO db_user;'"
        echo "Permissions granted"
    else
        echo "Database already has tables, skipping import"
    fi
fi

# Stop temporary PostgreSQL
echo "Stopping temporary PostgreSQL..."
kill $PG_PID
wait $PG_PID 2>/dev/null || true
sleep 2

# Update database connection in .env if needed
if [ -f /var/www/html/.env ]; then
    if ! grep -q "DATABASE_URL=pgsql://db_user:db_password@localhost:5432/postmill" /var/www/html/.env; then
        sed -i 's|DATABASE_URL=.*|DATABASE_URL=pgsql://db_user:db_password@localhost:5432/postmill?serverVersion=14|g' /var/www/html/.env
    fi
fi

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

# Ensure proper permissions
echo "Setting permissions..."
chown -R nginx:nginx /var/www/html/var
chown -R nginx:nginx /var/www/html/public/media
chown -R nginx:nginx /var/www/html/public/submission_images
chmod -R 777 /var/www/html/var/cache
chmod -R 777 /var/www/html/var/log
chmod -R 755 /var/www/html/public/media

echo "Container initialization complete!"

# Execute the main command
exec "$@"