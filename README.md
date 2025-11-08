# Optimized VWA Reddit

Similar effort https://github.com/bgrins/vwa_classifieds_optimized/, but for the [reddit image](https://github.com/web-arena-x/visualwebarena/tree/89f5af29305c3d1e9f97ce4421462060a70c9a03/environment_docker#social-forum-website-reddit). This is meant as a reproduction of the distributed tar file into a published Docker iamge, with some improvements.

## Initial Data Extraction (One-time setup)

```shell
# Download and run original image
wget https://archive.org/download/postmill-populated-exposed-withimg/postmill-populated-exposed-withimg.tar
docker load --input postmill-populated-exposed-withimg.tar
docker run --name forum -p 9999:80 -d postmill-populated-exposed-withimg

# Extract database dump (without ownership to avoid role errors)
docker exec forum su - postgres -c "pg_dump -U postgres -d postmill --no-owner --no-acl > /tmp/postmill_dump.sql"
docker cp forum:/tmp/postmill_dump.sql ./reddit_docker_rebuild/postmill_dump.sql

./optimize_images.sh
# Copy application files
docker cp forum:/var/www/html ./reddit_base_image/postmill_app

rm -r ./reddit_base_image/postmill_app/public/submission_images
mv ./reddit_base_image/postmill_app/public/submission_images_optimized ./reddit_base_image/postmill_app/public/submission_images
chmod -R 777 ./reddit_base_image/postmill_app/

rm -r ./reddit_base_image/postmill_app/public/media/cache && mkdir ./reddit_base_image/postmill_app/public/media/cache

# Clean up the original container
docker stop forum && docker rm forum
```

## Slim Container

The slim container variant removes some large and less-used subreddits & more aggressively optimizes images, reducing the size.


```bash
docker rm -f forum
docker run -d -p 9999:80 --name forum ghcr.io/bgrins/vwa-reddit-optimized-bundled:latest

./cleanup_subreddits.sh --dry-run
./cleanup_subreddits.sh --execute

./optimize_images.sh --aggressive --container forum

# Move original images to backup, use optimized as main
docker exec forum sh -c 'rm -rf /var/www/html/public/submission_images_original && \
  mv /var/www/html/public/submission_images /var/www/html/public/submission_images_original && \
  mv /var/www/html/public/submission_images_optimized_aggressive /var/www/html/public/submission_images'

docker exec forum du -sh /var/www/html/public/submission_images

# Create slim rebuild directory
mkdir -p reddit_docker_rebuild_slim

# Dump database to plain SQL (xz not available in container)
docker exec forum su - postgres -c "pg_dump -U db_user -d postmill --no-owner --no-acl > /tmp/postmill_dump_slim.sql"

# Copy dump to host and compress with xz
docker cp forum:/tmp/postmill_dump_slim.sql ./reddit_docker_rebuild_slim/
xz ./reddit_docker_rebuild_slim/postmill_dump_slim.sql
rclone copy reddit_docker_rebuild_slim/postmill_dump_slim.sql.xz r2:the-zoo/reddit/ -v --progress

# Clean up container before copying (remove backup and cache)
docker exec forum rm -rf /var/www/html/public/submission_images_original
docker exec forum sh -c 'rm -rf /var/www/html/public/media/cache && mkdir -p /var/www/html/public/media/cache'

# Copy entire app with optimized images
docker cp forum:/var/www/html ./reddit_base_image_slim/postmill_app

# Set permissions
chmod -R 777 ./reddit_base_image_slim/postmill_app/

./build-and-push.sh --slim
```

## Running the Containers

```shell

docker run -d -p 8080:80 --name reddit-forum ghcr.io/bgrins/vwa-reddit-optimized-bundled:latest

docker run -d -p 8080:80 --name reddit-forum -e DATABASE_URL=postgresql://user:pass@host:5432/dbname ghcr.io/bgrins/vwa-reddit-optimized-standalone:latest

```

## Testing

```shell
npm run test
# Or visit http://localhost:8080
```

## Cleanup

```shell
# Stop and remove containers
docker stop reddit-forum && docker rm reddit-forum

# Remove images
docker rmi ghcr.io/bgrins/vwa-reddit-optimized-bundled:latest
docker rmi ghcr.io/bgrins/vwa-reddit-optimized-standalone:latest

# Clean build cache
docker builder prune
```
