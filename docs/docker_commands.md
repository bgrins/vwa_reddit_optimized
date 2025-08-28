Checking size of image

```
docker save bgrins/vwa-reddit-optimized-standalone:latest | gzip > test.tar.gz && ls -lh test.tar.gz
docker run -d --name test bgrins/vwa-reddit-optimized-standalone:latest && docker ps -s
docker history bgrins/vwa-reddit-optimized-standalone:latest --no-trunc --format "table {{.Size}}\t{{.CreatedBy}}" | grep -E "GB|MB"
```