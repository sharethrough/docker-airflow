#! /usr/bin/env bash

#REPO_NAME = "119933218031.dkr.ecr.us-east-1.amazonaws.com/airflow"

echo "Building image"
docker build -t 119933218031.dkr.ecr.us-east-1.amazonaws.com/airflow --no-cache=true .

if [ $? -ne 0 ]; then
  echo "Building image has failed, exiting"
  exit
fi

echo "Authenticating with ecr"
eval $(aws ecr get-login --no-include-email --region us-east-1)

echo "Pushing built image to ecr"
docker push 119933218031.dkr.ecr.us-east-1.amazonaws.com/airflow 
