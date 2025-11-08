# Reddit Container Management Commands

Quick reference for common container operations.

---

## Starting the Container

```bash

docker rm -f forum

# Start fresh container from bundled image
docker run -d -p 9999:80 --name forum ghcr.io/bgrins/vwa-reddit-optimized-bundled:latest

# Start existing stopped container
docker start forum

# Check container status
docker ps -a --filter name=forum
```

---

## Cleaning Up Subreddits

```bash
# Preview what will be deleted (safe - no changes)
./cleanup_subreddits.sh --dry-run

# Execute deletion (requires typing "DELETE" to confirm)
./cleanup_subreddits.sh --execute

# Custom container name
./cleanup_subreddits.sh --execute --container mycontainer
```

---

## Optimizing Images

```bash
# Standard optimization (80-85% JPEG quality, lossless PNG/GIF)
./optimize_images.sh

# Aggressive optimization (30% JPEG quality, lossy GIF, max PNG compression)
./optimize_images.sh --aggressive

# Custom container
./optimize_images.sh --aggressive --container forum

# Or with environment variable
CONTAINER_NAME=forum ./optimize_images.sh --aggressive
```

**Output directories:**
- Standard: `/var/www/html/public/submission_images_optimized`
- Aggressive: `/var/www/html/public/submission_images_optimized_aggressive`

---

## Measuring Disk Size

### Total submission images size
```bash
docker exec forum du -sh /var/www/html/public/submission_images
```

### Optimized images size
```bash
# Standard optimized
docker exec forum du -sh /var/www/html/public/submission_images_optimized

# Aggressive optimized
docker exec forum du -sh /var/www/html/public/submission_images_optimized_aggressive
```

### Individual subreddit sizes
```bash
# All subreddits sorted by size
docker exec forum sh -c "du -sh /var/www/html/public/submission_images/* | sort -rh | head -20"

# Specific subreddit
docker exec forum du -sh /var/www/html/public/submission_images/dataisbeautiful
```

### Count files per subreddit
```bash
# Count images in all subreddits
docker exec forum sh -c "for dir in /var/www/html/public/submission_images/*; do echo \"\$(ls -1 \$dir 2>/dev/null | wc -l) \$(basename \$dir)\"; done | sort -rn | head -20"

# Specific subreddit
docker exec forum sh -c "ls -1 /var/www/html/public/submission_images/dataisbeautiful | wc -l"
```

### Database size
```bash
# Total database size
docker exec forum su - postgres -c "psql -U db_user -d postmill -c \"SELECT pg_size_pretty(pg_database_size('postmill')) as db_size;\""

# Table sizes
docker exec forum su - postgres -c "psql -U db_user -d postmill -c \"
SELECT
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;
\""
```

---

## Copying Images Out to Host

### Copy original images
```bash
# Copy entire submission_images directory
docker cp forum:/var/www/html/public/submission_images ./submission_images_backup

# Copy specific subreddit
docker cp forum:/var/www/html/public/submission_images/dataisbeautiful ./dataisbeautiful_backup

# Create tar archive (faster for large directories)
docker exec forum tar czf /tmp/submission_images.tar.gz -C /var/www/html/public submission_images
docker cp forum:/tmp/submission_images.tar.gz ./submission_images.tar.gz
```

### Copy optimized images
```bash
# Copy standard optimized
docker cp forum:/var/www/html/public/submission_images_optimized ./submission_images_optimized

# Copy aggressive optimized
docker cp forum:/var/www/html/public/submission_images_optimized_aggressive ./submission_images_optimized_aggressive

# Create tar archive of optimized (standard)
docker exec forum tar czf /tmp/submission_images_optimized.tar.gz -C /var/www/html/public submission_images_optimized
docker cp forum:/tmp/submission_images_optimized.tar.gz ./

# Create tar archive of optimized (aggressive)
docker exec forum tar czf /tmp/submission_images_optimized_aggressive.tar.gz -C /var/www/html/public submission_images_optimized_aggressive
docker cp forum:/tmp/submission_images_optimized_aggressive.tar.gz ./
```

### Copy only specific subreddits
```bash
# Create tar with only VWA-essential subreddits
docker exec forum sh -c "cd /var/www/html/public && tar czf /tmp/vwa_essential.tar.gz \
  submission_images/dataisbeautiful \
  submission_images/food \
  submission_images/pics \
  submission_images/memes \
  submission_images/MechanicalKeyboards \
  submission_images/wallstreetbets"
docker cp forum:/tmp/vwa_essential.tar.gz ./
```

---

## Dumping Database

### Full database dump
```bash
# Standard pg_dump (no ownership)
docker exec forum su - postgres -c "pg_dump -U db_user -d postmill --no-owner --no-acl > /tmp/postmill_dump.sql"
docker cp forum:/tmp/postmill_dump.sql ./postmill_dump.sql

# Compressed dump
docker exec forum su - postgres -c "pg_dump -U db_user -d postmill --no-owner --no-acl | gzip > /tmp/postmill_dump.sql.gz"
docker cp forum:/tmp/postmill_dump.sql.gz ./postmill_dump.sql.gz

# Custom format (smaller, faster restore)
docker exec forum su - postgres -c "pg_dump -U db_user -d postmill --no-owner --no-acl -Fc -f /tmp/postmill_dump.custom"
docker cp forum:/tmp/postmill_dump.custom ./postmill_dump.custom
```

### Dump specific tables
```bash
# Only forums table
docker exec forum su - postgres -c "pg_dump -U db_user -d postmill --no-owner --no-acl -t forums > /tmp/forums_only.sql"
docker cp forum:/tmp/forums_only.sql ./

# Multiple tables
docker exec forum su - postgres -c "pg_dump -U db_user -d postmill --no-owner --no-acl -t forums -t submissions -t comments > /tmp/core_tables.sql"
docker cp forum:/tmp/core_tables.sql ./
```

### Dump with statistics
```bash
# Get forum statistics before dump
docker exec forum su - postgres -c "psql -U db_user -d postmill -c \"
SELECT
    f.name as subreddit,
    COUNT(DISTINCT s.id) as submissions,
    COUNT(DISTINCT c.id) as comments,
    COUNT(DISTINCT u.id) as users
FROM forums f
LEFT JOIN submissions s ON s.forum_id = f.id
LEFT JOIN comments c ON c.submission_id = s.id
LEFT JOIN users u ON u.id = s.user_id OR u.id = c.user_id
GROUP BY f.name
ORDER BY submissions DESC;
\" > /tmp/forum_stats.txt"
docker cp forum:/tmp/forum_stats.txt ./

# Create dump with stats
docker exec forum sh -c "
    su - postgres -c 'psql -U db_user -d postmill -c \"SELECT * FROM forums;\" > /tmp/stats.txt' &&
    su - postgres -c 'pg_dump -U db_user -d postmill --no-owner --no-acl | gzip > /tmp/postmill_with_stats.sql.gz'
"
docker cp forum:/tmp/postmill_with_stats.sql.gz ./
docker cp forum:/tmp/stats.txt ./forum_stats.txt
```

---

## Swapping Image Directories

### Swap to optimized images
```bash
# Standard optimization
docker exec forum sh -c 'mv /var/www/html/public/submission_images /var/www/html/public/submission_images_original && mv /var/www/html/public/submission_images_optimized /var/www/html/public/submission_images'

# Aggressive optimization
docker exec forum sh -c 'mv /var/www/html/public/submission_images /var/www/html/public/submission_images_original && mv /var/www/html/public/submission_images_optimized_aggressive /var/www/html/public/submission_images'
```

### Restore original images
```bash
docker exec forum sh -c 'mv /var/www/html/public/submission_images /var/www/html/public/submission_images_optimized && mv /var/www/html/public/submission_images_original /var/www/html/public/submission_images'
```

---

## Container Lifecycle

### Stop and remove
```bash
# Stop container
docker stop forum

# Remove container
docker rm forum

# Stop and remove in one command
docker stop forum && docker rm forum
```

### Commit container to new image
```bash
# After cleanup/optimization, save as new image
docker commit forum bgrins/vwa-reddit-optimized-slim:latest

# With message
docker commit -m "Cleaned up unused subreddits, saved 9GB" forum bgrins/vwa-reddit-optimized-slim:latest

# Export as tar
docker save bgrins/vwa-reddit-optimized-slim:latest | gzip > vwa-reddit-slim.tar.gz
```

### Restart services inside container
```bash
# Restart all services
docker exec forum supervisorctl restart all

# Restart specific service
docker exec forum supervisorctl restart nginx
docker exec forum supervisorctl restart php-fpm
docker exec forum supervisorctl restart postgres

# Check service status
docker exec forum supervisorctl status
```

---

## Logs and Debugging

### View logs
```bash
# Container logs
docker logs forum

# Follow logs (real-time)
docker logs -f forum

# Last 50 lines
docker logs --tail 50 forum

# Nginx logs
docker exec forum tail -f /var/log/nginx/access.log
docker exec forum tail -f /var/log/nginx/error.log

# PHP-FPM logs
docker exec forum tail -f /var/log/php81/error.log

# PostgreSQL logs
docker exec forum su - postgres -c "tail -f /usr/local/pgsql/data/log/*.log"
```

### Interactive shell
```bash
# Shell as root
docker exec -it forum sh

# Shell as postgres user
docker exec -it forum su - postgres

# PostgreSQL interactive
docker exec -it forum su - postgres -c "psql -U db_user -d postmill"
```

---

## Database Queries

### Useful statistics queries
```bash
# Total counts
docker exec forum su - postgres -c "psql -U db_user -d postmill -c \"
SELECT
    (SELECT COUNT(*) FROM forums) as forums,
    (SELECT COUNT(*) FROM submissions) as submissions,
    (SELECT COUNT(*) FROM comments) as comments,
    (SELECT COUNT(*) FROM users) as users;
\""

# Top 10 subreddits by submissions
docker exec forum su - postgres -c "psql -U db_user -d postmill -c \"
SELECT
    f.name,
    COUNT(s.id) as submission_count
FROM forums f
LEFT JOIN submissions s ON s.forum_id = f.id
GROUP BY f.name
ORDER BY submission_count DESC
LIMIT 10;
\""

# Subreddits with images
docker exec forum su - postgres -c "psql -U db_user -d postmill -c \"
SELECT
    f.name,
    COUNT(s.id) FILTER (WHERE s.image_id IS NOT NULL) as images,
    COUNT(s.id) as total_submissions
FROM forums f
LEFT JOIN submissions s ON s.forum_id = f.id
GROUP BY f.name
HAVING COUNT(s.id) FILTER (WHERE s.image_id IS NOT NULL) > 0
ORDER BY images DESC;
\""
```

---

## Complete Workflow Examples

### 1. Create slim image with cleanup
```bash
# Start container
docker run -d -p 9999:80 --name forum ghcr.io/bgrins/vwa-reddit-optimized-bundled:latest

# Preview cleanup
./cleanup_subreddits.sh --dry-run

# Execute cleanup
./cleanup_subreddits.sh --execute

# Verify size reduction
docker exec forum du -sh /var/www/html/public/submission_images

# Commit to new image
docker commit -m "Removed unused subreddits, saved ~9GB" forum bgrins/vwa-reddit-slim:latest
```

### 2. Create optimized image
```bash
# Start container
docker run -d -p 9999:80 --name forum ghcr.io/bgrins/vwa-reddit-optimized-bundled:latest

# Run aggressive optimization
./optimize_images.sh --aggressive

# Check results
docker exec forum sh -c "du -sh /var/www/html/public/submission_images*"

# Swap to optimized
docker exec forum sh -c 'mv /var/www/html/public/submission_images /var/www/html/public/submission_images_original && mv /var/www/html/public/submission_images_optimized_aggressive /var/www/html/public/submission_images'

# Commit to new image
docker commit -m "Aggressive image optimization" forum bgrins/vwa-reddit-optimized-aggressive:latest
```

### 3. Backup everything
```bash
# Dump database
docker exec forum su - postgres -c "pg_dump -U db_user -d postmill --no-owner --no-acl | gzip > /tmp/postmill_dump.sql.gz"
docker cp forum:/tmp/postmill_dump.sql.gz ./backup/

# Archive images
docker exec forum tar czf /tmp/submission_images.tar.gz -C /var/www/html/public submission_images
docker cp forum:/tmp/submission_images.tar.gz ./backup/

# Copy application code
docker cp forum:/var/www/html ./backup/postmill_app
```

---

## Environment Variables

```bash
# Default database credentials (from Postmill)
DB_NAME=postmill
DB_USER=db_user
DB_PASSWORD=db_password

# Container name
CONTAINER_NAME=forum

# Image directories
SUBMISSION_IMAGES=/var/www/html/public/submission_images
OPTIMIZED_IMAGES=/var/www/html/public/submission_images_optimized
AGGRESSIVE_IMAGES=/var/www/html/public/submission_images_optimized_aggressive
```

---

## Quick Reference

```bash
# Size check
docker exec forum du -sh /var/www/html/public/submission_images

# Cleanup preview
./cleanup_subreddits.sh --dry-run

# Optimize standard
./optimize_images.sh

# Optimize aggressive
./optimize_images.sh --aggressive

# Dump database
docker exec forum su - postgres -c "pg_dump -U db_user -d postmill --no-owner --no-acl > /tmp/dump.sql"
docker cp forum:/tmp/dump.sql ./

# Copy images out
docker cp forum:/var/www/html/public/submission_images ./

# Commit changes
docker commit forum my-custom-reddit:latest
```
