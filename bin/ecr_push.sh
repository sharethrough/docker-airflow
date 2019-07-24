#! /usr/bin/env bash

REPO=airflow-base
TARGET_IMAGE="119933218031.dkr.ecr.us-east-1.amazonaws.com/${REPO}"
TARGET_IMAGE_LATEST="${TARGET_IMAGE}:latest"

TIMESTAMP=$(date '+%Y%m%d%H%M%S')
VERSION="${TIMESTAMP}-${TRAVIS_COMMIT}"
TARGET_IMAGE_VERSIONED="${TARGET_IMAGE}:${VERSION}"

echo "Authenticating with ecr"
eval $(aws ecr get-login --no-include-email)

echo "Pushing built image to ecr"

docker tag ${REPO} ${TARGET_IMAGE_LATEST}
docker push ${TARGET_IMAGE_LATEST}

docker tag ${REPO} ${TARGET_IMAGE_VERSIONED}
docker push ${TARGET_IMAGE_VERSIONED}
