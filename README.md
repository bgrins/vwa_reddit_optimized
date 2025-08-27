# Optimized VWA Reddit

Similar effort https://github.com/bgrins/vwa_classifieds_optimized/, but for the [reddit image](https://github.com/web-arena-x/visualwebarena/tree/89f5af29305c3d1e9f97ce4421462060a70c9a03/environment_docker#social-forum-website-reddit). This is meant as a reproduction of the distributed tar file into a dockerfile, with some improvements.

## Setup

```shell
wget https://archive.org/download/postmill-populated-exposed-withimg/postmill-populated-exposed-withimg.tar
docker load --input postmill-populated-exposed-withimg.tar
docker run --name forum -p 9999:80 -d postmill-populated-exposed-withimg

# Extract data (runs inside the same container)
docker exec forum su - postgres -c "pg_dump -U postgres -d postmill > /tmp/postmill_dump.sql" && docker cp forum:/tmp/postmill_dump.sql ./reddit_docker_rebuild/postmill_dump.sql && ls -lh ./reddit_docker_rebuild/postmill_dump.sql

# Compress images
./optimize_images.sh

# Copy app files
docker cp forum:/var/www/html ./reddit_docker_rebuild/postmill_app && ls -la ./reddit_docker_rebuild/postmill_app

rm -r postmill_app/public/submission_images
rm -r reddit_docker_rebuild/postmill_app/public/media/cache
mkdir reddit_docker_rebuild/postmill_app/public/media/cache

mv postmill_app/public/submission_images_optimized postmill_app/public/submission_images

chmod -R 777 ./reddit_docker_rebuild/postmill_app/

docker build -t reddit-forum-rebuilt:latest .

docker run -d \
  -p 8080:80 \
  -p 5433:5432 \
  --name reddit-forum-rebuilt \
  reddit-forum-rebuilt:latest

npm run test
```
