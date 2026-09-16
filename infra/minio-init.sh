#!/bin/sh
set -e
until mc alias set local http://minio:9000 minio REDACTED; do
  sleep 1
done
mc mb --ignore-existing local/dishtoday
mc anonymous set download local/dishtoday
echo "MinIO bucket ready"
