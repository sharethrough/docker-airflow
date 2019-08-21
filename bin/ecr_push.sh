#! /usr/bin/env bash

REPO=airflow-base
TARGET_IMAGE="119933218031.dkr.ecr.us-east-1.amazonaws.com/${REPO}"
IMAGE_VERSION=$(docker inspect ${TARGET_IMAGE} | jq -r .[0].Config.Labels.version)

TARGET_IMAGE_LATEST="${TARGET_IMAGE}:latest"
TARGET_IMAGE_VERSION="${TARGET_IMAGE}:${IMAGE_VERSION}"

docker tag ${TARGET_IMAGE} ${TARGET_IMAGE_LATEST}
docker tag ${TARGET_IMAGE} ${TARGET_IMAGE_VERSION}

echo "Setting region"
aws configure set default.region us-east-1

echo "Setting access key"
aws configure set aws_access_key_id ${AWS_ACCESS_KEY_ID}

echo "Setting secret key"
aws configure set aws_secret_access_key ${AWS_SECRET_ACCESS_KEY}

echo "Authenticating with ecr"
eval $(aws ecr get-login --no-include-email --region us-east-1)

echo "Pushing built images to ecr"
docker push ${TARGET_IMAGE_LATEST}
docker push ${TARGET_IMAGE_VERSION}
