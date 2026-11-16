#!/bin/sh
set -e
# Credentials come from the environment (see infra/.env.example).
: "${MINIO_ACCESS_KEY:?MINIO_ACCESS_KEY is required}"
: "${MINIO_SECRET_KEY:?MINIO_SECRET_KEY is required}"
: "${MINIO_BUCKET:=dishtoday}"

until mc alias set local "http://minio:9000" "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY"; do
  sleep 1
done
mc mb --ignore-existing "local/${MINIO_BUCKET}"
mc anonymous set download "local/${MINIO_BUCKET}"
echo "MinIO bucket ready"
