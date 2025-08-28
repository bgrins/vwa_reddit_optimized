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

## Building the Docker Images

The build is split into three images:
1. **Base image** - Contains the application code and submission images (~37GB)
2. **Bundled variant** - Includes PostgreSQL database (~40GB)
3. **Standalone variant** - External database required (~37GB)

### Build Process

```shell
# Step 1: Build the base image (contains app + images)
docker build -t bgrins/vwa-reddit-optimized-base:latest reddit_base_image/

# Step 2: Build the variants (uses the base image)
# Build locally for testing
docker build --target with-postgres -t bgrins/vwa-reddit-optimized-bundled:latest reddit_docker_rebuild/
docker build --target without-postgres -t bgrins/vwa-reddit-optimized-standalone:latest reddit_docker_rebuild/

# Build and push multi-platform images to Docker Hub
./build-multiplatform.sh
```

## Running the Containers

```shell

docker run -d -p 8080:80 --name reddit-forum bgrins/vwa-reddit-optimized-bundled:latest

docker run -d -p 8080:80 --name reddit-forum -e DATABASE_URL=postgresql://user:pass@host:5432/dbname bgrins/vwa-reddit-optimized-standalone:latest

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
docker rmi bgrins/vwa-reddit-optimized-bundled:latest
docker rmi bgrins/vwa-reddit-optimized-standalone:latest
docker rmi bgrins/vwa-reddit-optimized-base:latest

# Clean build cache
docker builder prune
```
