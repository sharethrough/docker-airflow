#! /usr/bin/env bash

set -o errexit

REPO=airflow-base
LOCAL_NAME=${REPO}
TARGET_IMAGE="119933218031.dkr.ecr.us-east-1.amazonaws.com/${REPO}"

tag_and_push() {
  # Tag images for ECR
  IMAGE_VERSION=$(docker inspect ${LOCAL_NAME} | jq -r .[0].Config.Labels.version)
  TARGET_IMAGE_LATEST="${TARGET_IMAGE}:latest"
  TARGET_IMAGE_VERSION="${TARGET_IMAGE}:${IMAGE_VERSION}"

  docker rmi ${TARGET_IMAGE_LATEST} || true
  docker rmi ${TARGET_IMAGE_VERSION} || true
  
  docker tag ${LOCAL_NAME} ${TARGET_IMAGE_LATEST}
  docker tag ${LOCAL_NAME} ${TARGET_IMAGE_VERSION}

  # ECR credentials  
  echo "Authenticating with ecr"
  aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 119933218031.dkr.ecr.us-east-1.amazonaws.com

  
  echo "Pushing built images to ecr"
  docker push ${TARGET_IMAGE_LATEST}
  docker push ${TARGET_IMAGE_VERSION}
}

build() {
  #Build airflow-base
  docker build -t ${LOCAL_NAME} -f ./Dockerfile .

  docker images --format '{{.Repository}}:{{.Tag}}\t\t Built: {{.CreatedSince}}\t\tSize: {{.Size}}' | \
  grep ${IMAGE_NAME}:${VERSION}
}

usage() {
  echo "Usage: $0 run_option" 1>&2; 
  exit 1; 
}

if [ -z $1 ]; then
    usage
fi

run_option=$1

case $run_option in
    build           ) echo "Running local build"
                    build
                    ;;
    build-and-push  ) echo "Building for ECr"
                    build
                    tag_and_push
                    ;;
    *               ) echo "You did not enter a valid option."
esac
