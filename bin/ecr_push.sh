#! /usr/bin/env bash

REPO=airflow-base
TARGET_IMAGE="119933218031.dkr.ecr.us-east-1.amazonaws.com/${REPO}"
TARGET_IMAGE_LATEST="${TARGET_IMAGE}:latest"

aws configure set default.region us-east-1
aws configure set aws_access_key_id ${AWS_ACCESS_KEY_ID}
aws configure set aws_secret_access_key ${AWS_SECRET_ACCESS_KEY}

echo "Authenticating with ecr"
eval $(aws ecr get-login --no-include-email --region us-east-1)

echo "Pushing built image to ecr"

docker tag ${REPO} ${TARGET_IMAGE_LATEST}
docker push ${TARGET_IMAGE_LATEST}
